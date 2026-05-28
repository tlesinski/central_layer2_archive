CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_DISCOVERY
AS
  /*
    Package      : PKG_ARCHIVE_DISCOVERY
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Discover source partitions - add missing target partitions,
                   insert partition metadata into TW_ARCHIVE_PARTITIONS

    Prerequisite : PKG_SQL, PKG_ARCHIVE_LOG, TW_ARCHIVE_DISCOVERY_PARTITIONS_VW

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
    1.1        2026-05-28   Tomasz Lesinski    Add process summary logging
  */
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_qualified_table(p_owner IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN PKG_SQL.fn_assert_simple_name(p_owner) || '.' || PKG_SQL.fn_assert_simple_name(p_table);
  END;

  FUNCTION fn_normalize_name(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_name IS NULL OR TRIM(p_name) IS NULL THEN
      RETURN NULL;
    END IF;

    RETURN PKG_SQL.fn_assert_simple_name(p_name);
  END;

  FUNCTION fn_target_subpartition_name
  (
    p_target_owner             IN VARCHAR2,
    p_target_table_name        IN VARCHAR2,
    p_partition_name           IN VARCHAR2,
    p_subpartition_high_value  IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_subpartition_name VARCHAR2(128);
  BEGIN
    SELECT x.subpartition_name
      INTO l_subpartition_name
      FROM XMLTABLE
           (
             '/ROWSET/ROW'
             PASSING DBMS_XMLGEN.GETXMLTYPE
             (
               'SELECT subpartition_name, high_value ' ||
               'FROM all_tab_subpartitions ' ||
               'WHERE table_owner = ''' || REPLACE(PKG_SQL.fn_assert_simple_name(p_target_owner), '''', '''''') || ''' ' ||
               'AND table_name = ''' || REPLACE(PKG_SQL.fn_assert_simple_name(p_target_table_name), '''', '''''') || ''' ' ||
               'AND partition_name = ''' || REPLACE(PKG_SQL.fn_assert_simple_name(p_partition_name), '''', '''''') || ''''
             )
             COLUMNS
               subpartition_name       VARCHAR2(128)  PATH 'SUBPARTITION_NAME',
               subpartition_high_value VARCHAR2(4000) PATH 'HIGH_VALUE'
           ) x
     WHERE x.subpartition_high_value = p_subpartition_high_value;

    RETURN l_subpartition_name;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error
      (
        -20061,
        'Target subpartition not found by high value for ' ||
        p_target_owner || '.' || p_target_table_name || '.' || p_partition_name ||
        ', subpartition_high_value=' || p_subpartition_high_value
      );
  END fn_target_subpartition_name;

  PROCEDURE prc_discover
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_run_id          NUMBER;
    l_log_id          NUMBER;
    l_execute_flag    VARCHAR2(1);
    l_target_owner    VARCHAR2(128);
    l_target_table    VARCHAR2(128);
    l_sql             CLOB;
    l_add_sql         CLOB;
    l_insert_sql      CLOB;
    l_target_subpart   VARCHAR2(128);
    l_rows            NUMBER;
    l_rows_discovered NUMBER := 0;
    l_rows_inserted   NUMBER := 0;
    l_tables          NUMBER := 0;
    l_partitions      NUMBER := 0;
    l_summary         CLOB := NULL;
    l_partition_summary CLOB;
    l_summary_columns VARCHAR2(1000) :=
      'SOURCE_DB_LINK|TABLE_OWNER|TABLE_NAME|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|ARCHIVE_STATUS|QUALITY_STATUS|TRUNCATE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT|NOTE';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('DISCOVER', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVE_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started DISCOVER with parameters:' || CHR(10) ||
                   '  p_execute           => ' || l_execute_flag || CHR(10) ||
                   '  p_target_owner      => ' || NVL(l_target_owner, '<ALL>') || CHR(10) ||
                   '  p_target_table_name => ' || NVL(l_target_table, '<ALL>')
    );

    l_sql :=
      'SELECT COUNT(*) ' ||
      '  FROM TW_ARCHIVE_DISCOVERY_PARTITIONS_VW ' ||
      ' WHERE (:1 IS NULL OR target_owner = :1) ' ||
      '   AND (:2 IS NULL OR target_table_name = :2)';

    l_rows_discovered := PKG_SQL.fn_run_into_sql_in_bind
    (
      p_log_id     => l_log_id,
      p_sql        => l_sql,
      p_array_bind => SYS.ODCIVARCHAR2LIST(l_target_owner, l_target_table),
      p_execute    => 'Y'
    );

    FOR t IN (
      SELECT DISTINCT source_db_link,
             source_owner,
             source_table_name,
             target_owner,
             target_table_name
        FROM tw_archive_discovery_partitions_vw
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_tables := l_tables + 1;

      FOR p IN (
        SELECT DISTINCT partition_name,
               partition_high_value,
               partition_position
          FROM tw_archive_discovery_partitions_vw
         WHERE source_db_link = t.source_db_link
           AND source_owner = t.source_owner
           AND source_table_name = t.source_table_name
           AND target_owner = t.target_owner
           AND target_table_name = t.target_table_name
         ORDER BY partition_position
      ) LOOP
        l_partitions := l_partitions + 1;
        l_partition_summary := NULL;

        l_add_sql :=
          'ALTER TABLE ' || fn_qualified_table(t.target_owner, t.target_table_name) ||
          ' ADD PARTITION ' || PKG_SQL.fn_assert_simple_name(p.partition_name) ||
          ' VALUES LESS THAN (' || p.partition_high_value || ')';

        l_rows := PKG_SQL.fn_run_sql(l_log_id, l_add_sql, l_execute_flag);

        l_insert_sql :=
          'INSERT INTO TW_ARCHIVE_PARTITIONS ' || CHR(10) ||
          '  (source_db_link, source_owner, source_table_name, target_owner, target_table_name, ' || CHR(10) ||
          '   archive_unit_type, source_partition_name, source_subpartition_name, partition_name, subpartition_name, ' || CHR(10) ||
          '   partition_high_value, subpartition_high_value, ' || CHR(10) ||
          '   partition_position, subpartition_position, archive_status, quality_status, truncate_status, last_run_id) ' || CHR(10) ||
          'VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, TO_NUMBER(:13), TO_NUMBER(:14), ''N'', ''N'', ''N'', TO_NUMBER(:15))';

        IF l_execute_flag = 'Y' THEN
          FOR s IN (
            SELECT target_owner,
                   target_table_name,
                   source_db_link,
                   source_owner,
                   source_table_name,
                   source_partition_name,
                   source_subpartition_name,
                   partition_name,
                   subpartition_name,
                   partition_high_value,
                   subpartition_high_value,
                   partition_position,
                   subpartition_position,
                   archive_unit_type
              FROM tw_archive_discovery_partitions_vw
             WHERE source_db_link = t.source_db_link
               AND source_owner = t.source_owner
               AND source_table_name = t.source_table_name
               AND target_owner = t.target_owner
               AND target_table_name = t.target_table_name
               AND partition_high_value = p.partition_high_value
             ORDER BY partition_position, subpartition_position
          ) LOOP
            IF s.archive_unit_type = 'SUBPARTITION' THEN
              l_target_subpart := fn_target_subpartition_name
                                  (
                                    s.target_owner,
                                    s.target_table_name,
                                    s.partition_name,
                                    s.subpartition_high_value
                                  );
            ELSE
              l_target_subpart := '#';
            END IF;

            l_rows := PKG_SQL.fn_run_sql_in_bind
            (
              p_log_id     => l_log_id,
              p_sql        => l_insert_sql,
              p_array_bind => SYS.ODCIVARCHAR2LIST
                              (
                                s.source_db_link,
                                s.source_owner,
                                s.source_table_name,
                                s.target_owner,
                                s.target_table_name,
                                s.archive_unit_type,
                                s.source_partition_name,
                                s.source_subpartition_name,
                                s.partition_name,
                                l_target_subpart,
                                s.partition_high_value,
                                s.subpartition_high_value,
                                TO_CHAR(s.partition_position),
                                TO_CHAR(s.subpartition_position),
                                TO_CHAR(l_run_id)
                              ),
              p_execute    => l_execute_flag
            );

            l_rows_inserted := l_rows_inserted + NVL(l_rows, 0);

            l_partition_summary := l_partition_summary ||
              PKG_ARCHIVE_LOG.fn_summary_row
              (
                p_source_db_link          => s.source_db_link,
                p_table_owner             => s.source_owner,
                p_table_name              => s.source_table_name,
                p_partition_name          => s.source_partition_name,
                p_subpartition_name       => s.source_subpartition_name,
                p_partition_high_value    => s.partition_high_value,
                p_subpartition_high_value => s.subpartition_high_value,
                p_archive_status          => 'N',
                p_quality_status          => 'N',
                p_truncate_status         => 'N',
                p_source_row_count        => NULL,
                p_target_row_count        => NULL,
                p_note                    => 'target=' || s.target_owner || '.' || s.target_table_name ||
                                             ' ' || s.partition_name ||
                                             CASE WHEN s.archive_unit_type = 'SUBPARTITION' THEN '.' || l_target_subpart END ||
                                             ', execute=' || l_execute_flag
              );
          END LOOP;
        ELSE
          l_rows_inserted := l_rows_inserted + NVL(l_rows, 0);
        END IF;

        IF l_execute_flag = 'Y' THEN
          COMMIT;
          l_summary := l_summary || l_partition_summary;
        END IF;
      END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(
      'DISCOVER tables=' || l_tables ||
      ' partitions=' || l_partitions ||
      ' found=' || l_rows_discovered ||
      ' inserted=' || l_rows_inserted ||
      ' target_owner=' || NVL(l_target_owner, '<ALL>') ||
      ' target_table=' || NVL(l_target_table, '<ALL>') ||
      ' execute=' || l_execute_flag
    );

    IF l_summary IS NOT NULL THEN
      PKG_ARCHIVE_LOG.prc_log_summary
      (
        p_run_id       => l_run_id,
        p_process_name => 'DISCOVER',
        p_columns      => l_summary_columns,
        p_rows         => l_summary
      );
    END IF;

    PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVE_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_discover;
END PKG_ARCHIVE_DISCOVERY;
/
