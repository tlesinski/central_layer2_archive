CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVER_DISCOVERY
AS
  /*
    Package      : PKG_ARCHIVER_DISCOVERY
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Discover source partitions - add missing target partitions,
                   insert partition metadata into TBL_ARCHIVER_PARTITIONS

    Prerequisite : PKG_ARCHIVER_SQL, PKG_ARCHIVER_LOG, VW_ARCHIVER_DISCOVERY_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-28   Tomasz Lesinski    Add process summary logging
     1.2        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
  */
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_qualified_table(p_owner IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN PKG_ARCHIVER_SQL.fn_assert_simple_name(p_owner) || '.' || PKG_ARCHIVER_SQL.fn_assert_simple_name(p_table);
  END;

  FUNCTION fn_normalize_name(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_name IS NULL OR TRIM(p_name) IS NULL THEN
      RETURN NULL;
    END IF;

    RETURN PKG_ARCHIVER_SQL.fn_assert_simple_name(p_name);
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
               'WHERE table_owner = ''' || REPLACE(PKG_ARCHIVER_SQL.fn_assert_simple_name(p_target_owner), '''', '''''') || ''' ' ||
               'AND table_name = ''' || REPLACE(PKG_ARCHIVER_SQL.fn_assert_simple_name(p_target_table_name), '''', '''''') || ''' ' ||
               'AND partition_name = ''' || REPLACE(PKG_ARCHIVER_SQL.fn_assert_simple_name(p_partition_name), '''', '''''') || ''''
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

  PROCEDURE prc_validate_table_setup
  (
    p_source_db_link      IN VARCHAR2,
    p_source_owner        IN VARCHAR2,
    p_source_table_name   IN VARCHAR2,
    p_target_owner        IN VARCHAR2,
    p_target_table_name   IN VARCHAR2,
    p_partition_method    IN VARCHAR2,
    p_subpartition_method IN VARCHAR2
  )
  IS
    l_source_part_method  VARCHAR2(20);
    l_source_sub_method   VARCHAR2(20);
    l_source_part_column  VARCHAR2(128);
    l_source_part_type    VARCHAR2(128);
    l_source_sub_column   VARCHAR2(128);
    l_source_sub_type     VARCHAR2(128);
    l_source_part_count   NUMBER;
    l_source_sub_count    NUMBER;
    l_target_part_method  VARCHAR2(20);
    l_target_sub_method   VARCHAR2(20);
    l_target_part_column  VARCHAR2(128);
    l_target_part_type    VARCHAR2(128);
    l_target_sub_column   VARCHAR2(128);
    l_target_sub_type     VARCHAR2(128);
    l_target_part_count   NUMBER;
    l_target_sub_count    NUMBER;
  BEGIN
    SELECT source_partition_method,
           source_subpartition_method,
           partition_key_column,
           partition_key_data_type,
           subpartition_key_column,
           subpartition_key_data_type,
           partition_key_count,
           subpartition_key_count
      INTO l_source_part_method,
           l_source_sub_method,
           l_source_part_column,
           l_source_part_type,
           l_source_sub_column,
           l_source_sub_type,
           l_source_part_count,
           l_source_sub_count
      FROM VW_ARCHIVER_SOURCE_PARTITIONS
     WHERE source_db_link = p_source_db_link
       AND source_owner = p_source_owner
       AND source_table_name = p_source_table_name
       AND ROWNUM = 1;

    SELECT pt.partitioning_type,
           NULLIF(pt.subpartitioning_type, 'NONE'),
           pk.column_name,
           pc.data_type,
           spk.column_name,
           spc.data_type,
           (SELECT COUNT(*)
              FROM all_part_key_columns x
             WHERE x.owner = pt.owner
               AND x.name = pt.table_name
               AND x.object_type = 'TABLE'),
           (SELECT COUNT(*)
              FROM all_subpart_key_columns x
             WHERE x.owner = pt.owner
               AND x.name = pt.table_name
               AND x.object_type = 'TABLE')
      INTO l_target_part_method,
           l_target_sub_method,
           l_target_part_column,
           l_target_part_type,
           l_target_sub_column,
           l_target_sub_type,
           l_target_part_count,
           l_target_sub_count
      FROM all_part_tables pt
      JOIN all_part_key_columns pk
        ON pk.owner = pt.owner
       AND pk.name = pt.table_name
       AND pk.object_type = 'TABLE'
       AND pk.column_position = 1
      JOIN all_tab_columns pc
        ON pc.owner = pk.owner
       AND pc.table_name = pk.name
       AND pc.column_name = pk.column_name
      LEFT JOIN all_subpart_key_columns spk
        ON spk.owner = pt.owner
       AND spk.name = pt.table_name
       AND spk.object_type = 'TABLE'
       AND spk.column_position = 1
      LEFT JOIN all_tab_columns spc
        ON spc.owner = spk.owner
       AND spc.table_name = spk.name
       AND spc.column_name = spk.column_name
     WHERE pt.owner = p_target_owner
       AND pt.table_name = p_target_table_name;

    IF l_source_part_count <> 1 OR l_target_part_count <> 1 THEN
      RAISE_APPLICATION_ERROR(-20062, 'Exactly one partition key column is required');
    END IF;

    IF NVL(l_source_sub_count, 0) > 1 OR NVL(l_target_sub_count, 0) > 1 THEN
      RAISE_APPLICATION_ERROR(-20063, 'At most one subpartition key column is supported');
    END IF;

    IF l_source_part_method <> p_partition_method
       OR l_target_part_method <> p_partition_method THEN
      RAISE_APPLICATION_ERROR
      (
        -20064,
        'Partition method mismatch for ' || p_source_owner || '.' || p_source_table_name
      );
    END IF;

    IF NVL(l_source_sub_method, '#') <> NVL(p_subpartition_method, '#')
       OR NVL(l_target_sub_method, '#') <> NVL(p_subpartition_method, '#') THEN
      RAISE_APPLICATION_ERROR
      (
        -20065,
        'Subpartition method mismatch for ' || p_source_owner || '.' || p_source_table_name
      );
    END IF;

    IF l_source_part_column <> l_target_part_column
       OR l_source_part_type <> l_target_part_type THEN
      RAISE_APPLICATION_ERROR(-20066, 'Partition key column or type mismatch');
    END IF;

    IF p_subpartition_method IS NOT NULL
       AND (l_source_sub_column <> l_target_sub_column OR l_source_sub_type <> l_target_sub_type) THEN
      RAISE_APPLICATION_ERROR(-20067, 'Subpartition key column or type mismatch');
    END IF;

  END prc_validate_table_setup;

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
    l_table_summary   CLOB;
    l_msg             CLOB;
    l_summary         CLOB := NULL;
    l_partition_columns VARCHAR2(1000) :=
      'NOTE|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_NAME|SUBPARTITION_NAME|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|ARCHIVE_STATUS|QUALITY_STATUS|TRUNCATE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVER_LOG.fn_create_run('DISCOVER', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVER_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started DISCOVER with parameters:' || CHR(10) ||
                   '  p_execute           => ' || l_execute_flag || CHR(10) ||
                   '  p_target_owner      => ' || NVL(l_target_owner, '<ALL>') || CHR(10) ||
                   '  p_target_table_name => ' || NVL(l_target_table, '<ALL>')
    );

    FOR v IN
    (
      SELECT DISTINCT source_db_link,
             source_owner,
             source_table_name,
             target_owner,
             target_table_name,
             partition_method,
             subpartition_method
        FROM VW_ARCHIVER_SOURCE_PARTITIONS
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
    ) LOOP
      prc_validate_table_setup
      (
        v.source_db_link,
        v.source_owner,
        v.source_table_name,
        v.target_owner,
        v.target_table_name,
        v.partition_method,
        v.subpartition_method
      );
    END LOOP;

    l_sql :=
      'SELECT COUNT(*) ' ||
      '  FROM VW_ARCHIVER_DISCOVERY_PARTITIONS ' ||
      ' WHERE (:1 IS NULL OR target_owner = :1) ' ||
      '   AND (:2 IS NULL OR target_table_name = :2)';

    l_rows_discovered := PKG_ARCHIVER_SQL.fn_run_into_sql_in_bind
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
             target_table_name,
             partition_method,
             subpartition_method
        FROM VW_ARCHIVER_DISCOVERY_PARTITIONS
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_tables := l_tables + 1;
      PKG_ARCHIVER_LOG.prc_log_table_context
      (
        l_run_id, 'DISCOVER', t.source_db_link, t.source_owner, t.source_table_name,
        t.target_owner, t.target_table_name
      );
      l_table_summary := NULL;

      FOR p IN (
        SELECT DISTINCT partition_name,
               partition_high_value,
               partition_position
          FROM VW_ARCHIVER_DISCOVERY_PARTITIONS
         WHERE source_db_link = t.source_db_link
           AND source_owner = t.source_owner
           AND source_table_name = t.source_table_name
           AND target_owner = t.target_owner
           AND target_table_name = t.target_table_name
         ORDER BY partition_position
      ) LOOP
        l_partitions := l_partitions + 1;

        l_add_sql :=
          'ALTER TABLE ' || fn_qualified_table(t.target_owner, t.target_table_name) ||
          ' ADD PARTITION ' || PKG_ARCHIVER_SQL.fn_assert_simple_name(p.partition_name) ||
          CASE t.partition_method
            WHEN 'RANGE' THEN ' VALUES LESS THAN (' || p.partition_high_value || ')'
            WHEN 'LIST' THEN ' VALUES (' || p.partition_high_value || ')'
          END;

        l_rows := PKG_ARCHIVER_SQL.fn_run_sql(l_log_id, l_add_sql, l_execute_flag);

        l_insert_sql :=
          'INSERT INTO TBL_ARCHIVER_PARTITIONS ' || CHR(10) ||
          '  (source_db_link, source_owner, source_table_name, target_owner, target_table_name, ' || CHR(10) ||
          '   archive_unit_type, source_partition_name, source_subpartition_name, partition_name, subpartition_name, ' || CHR(10) ||
          '   partition_high_value, subpartition_high_value, prev_partition_high_value, ' || CHR(10) ||
          '   archive_status, quality_status, truncate_status, last_run_id) ' || CHR(10) ||
          'VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, ''N'', ''N'', ''N'', TO_NUMBER(:14))';

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
                    prev_partition_high_value,
                    archive_unit_type
              FROM VW_ARCHIVER_DISCOVERY_PARTITIONS
             WHERE source_db_link = t.source_db_link
               AND source_owner = t.source_owner
               AND source_table_name = t.source_table_name
               AND target_owner = t.target_owner
               AND target_table_name = t.target_table_name
               AND partition_high_value = p.partition_high_value
              ORDER BY partition_high_value, subpartition_high_value
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

            l_rows := PKG_ARCHIVER_SQL.fn_run_sql_in_bind
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
                                s.prev_partition_high_value,
                                TO_CHAR(l_run_id)
                              ),
              p_execute    => l_execute_flag
            );

            l_rows_inserted := l_rows_inserted + NVL(l_rows, 0);

            l_table_summary := l_table_summary ||
              TO_CLOB(PKG_ARCHIVER_LOG.fn_summary_cell(s.archive_unit_type)) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(s.source_partition_name) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(s.source_subpartition_name) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(s.partition_name) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(l_target_subpart) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(s.partition_high_value) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(s.subpartition_high_value) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell('N') || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell('N') || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell('N') || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(NULL) || '|' ||
              PKG_ARCHIVER_LOG.fn_summary_cell(NULL) || CHR(10);
          END LOOP;
        ELSE
          l_rows_inserted := l_rows_inserted + NVL(l_rows, 0);
        END IF;

        IF l_execute_flag = 'Y' THEN
          COMMIT;
        END IF;
      END LOOP;

      IF l_execute_flag = 'Y' AND l_table_summary IS NOT NULL THEN
        l_summary := l_summary ||
          '=== TABLE: ' || t.source_db_link || '.' || t.source_owner || '.' || t.source_table_name || ' ===' || CHR(10) || CHR(10) ||
          PKG_ARCHIVER_SQL.fn_format_table(
            p_columns => 'SOURCE_DB_LINK|TABLE_OWNER|TABLE_NAME|EXECUTE',
            p_rows    => PKG_ARCHIVER_LOG.fn_summary_cell(t.source_db_link) || '|' ||
                         PKG_ARCHIVER_LOG.fn_summary_cell(t.source_owner) || '|' ||
                         PKG_ARCHIVER_LOG.fn_summary_cell(t.source_table_name) || '|' ||
                         PKG_ARCHIVER_LOG.fn_summary_cell(l_execute_flag) || CHR(10)
          ) || CHR(10) ||
          PKG_ARCHIVER_SQL.fn_format_table(
            p_columns    => l_partition_columns,
            p_rows       => l_table_summary
          ) || CHR(10);
      END IF;
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
      PKG_ARCHIVER_LOG.prc_log_message(l_run_id, l_summary, 'SUMMARY');
    END IF;

    PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVER_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_discover;
END PKG_ARCHIVER_DISCOVERY;
/
