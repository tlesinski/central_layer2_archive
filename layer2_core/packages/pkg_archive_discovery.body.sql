CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_DISCOVERY
AS
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
    l_rows            NUMBER;
    l_rows_discovered NUMBER := 0;
    l_rows_inserted   NUMBER := 0;
    l_tables          NUMBER := 0;
    l_partitions      NUMBER := 0;
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('DISCOVER', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVE_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Discovery filter: target_owner=' || NVL(l_target_owner, '<ALL>') ||
                   ', target_table_name=' || NVL(l_target_table, '<ALL>')
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

        l_add_sql :=
          'ALTER TABLE ' || fn_qualified_table(t.target_owner, t.target_table_name) ||
          ' ADD PARTITION ' || PKG_SQL.fn_assert_simple_name(p.partition_name) ||
          ' VALUES LESS THAN (' || p.partition_high_value || ')';

        l_rows := PKG_SQL.fn_run_sql(l_log_id, l_add_sql, l_execute_flag);

        l_insert_sql :=
          'INSERT INTO TW_ARCHIVE_PARTITIONS ' ||
          '  (source_db_link, source_owner, source_table_name, target_owner, target_table_name, ' ||
          '   archive_unit_type, source_partition_name, source_subpartition_name, partition_name, subpartition_name, ' ||
          '   partition_high_value, subpartition_high_value, ' ||
          '   partition_position, subpartition_position, archive_status, quality_status, truncate_status, last_run_id) ' ||
          'SELECT source_db_link, source_owner, source_table_name, target_owner, target_table_name, ' ||
          '       archive_unit_type, source_partition_name, source_subpartition_name, partition_name, subpartition_name, ' ||
          '       partition_high_value, subpartition_high_value, ' ||
          '       partition_position, subpartition_position, ''N'', ''N'', ''N'', :7 ' ||
          '  FROM TW_ARCHIVE_DISCOVERY_PARTITIONS_VW ' ||
          ' WHERE source_db_link = :1 ' ||
          '   AND source_owner = :2 ' ||
          '   AND source_table_name = :3 ' ||
          '   AND partition_high_value = :4 ' ||
          '   AND target_owner = :5 ' ||
          '   AND target_table_name = :6';

        l_rows := PKG_SQL.fn_run_sql_in_bind
        (
          p_log_id     => l_log_id,
          p_sql        => l_insert_sql,
          p_array_bind => SYS.ODCIVARCHAR2LIST
                          (
                            t.source_db_link,
                            t.source_owner,
                            t.source_table_name,
                            p.partition_high_value,
                            t.target_owner,
                            t.target_table_name,
                            TO_CHAR(l_run_id)
                          ),
          p_execute    => l_execute_flag
        );

        l_rows_inserted := l_rows_inserted + NVL(l_rows, 0);

        IF l_execute_flag = 'Y' THEN
          COMMIT;
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
