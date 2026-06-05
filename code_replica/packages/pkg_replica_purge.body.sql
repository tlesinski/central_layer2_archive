CREATE OR REPLACE PACKAGE BODY PKG_REPLICA_PURGE
AS
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_normalize_name(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_name IS NULL OR TRIM(p_name) IS NULL THEN
      RETURN NULL;
    END IF;
    RETURN PKG_REPLICA_SQL.fn_assert_simple_name(p_name);
  END;

  FUNCTION fn_qualified_table(p_owner IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN PKG_REPLICA_SQL.fn_assert_simple_name(p_owner) || '.' || PKG_REPLICA_SQL.fn_assert_simple_name(p_table);
  END;

  PROCEDURE prc_purge
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_run_id            NUMBER;
    l_log_id            NUMBER;
    l_execute_flag      VARCHAR2(1);
    l_target_owner      VARCHAR2(128);
    l_target_table      VARCHAR2(128);
    l_sql               CLOB;
    l_rows_available    NUMBER := 0;
    l_units             NUMBER := 0;
    l_purged            NUMBER := 0;
    l_summary           CLOB := NULL;
    l_table_summary     CLOB;
    l_partition_columns VARCHAR2(1000) :=
      'NOTE|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_NAME|SUBPARTITION_NAME|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|REPLICA_STATUS|QUALITY_STATUS|PURGE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_REPLICA_LOG.fn_create_run('PURGE', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_REPLICA_LOG.fn_get_log_id(l_run_id);

    PKG_REPLICA_LOG.prc_log_message(l_run_id, 'Started REPLICA PURGE execute=' || l_execute_flag);

    l_sql :=
      'SELECT COUNT(*) FROM VW_REPLICA_PURGE_PARTITIONS ' ||
      'WHERE (:1 IS NULL OR target_owner = :1) AND (:2 IS NULL OR target_table_name = :2)';

    l_rows_available := PKG_REPLICA_SQL.fn_run_into_sql_in_bind
    (
      p_log_id     => l_log_id,
      p_sql        => l_sql,
      p_array_bind => SYS.ODCIVARCHAR2LIST(l_target_owner, l_target_table),
      p_execute    => 'Y'
    );

    FOR t IN (
      SELECT DISTINCT source_db_link, source_owner, source_table_name, target_owner, target_table_name
        FROM vw_replica_purge_partitions
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_table_summary := NULL;

      FOR r IN (
        SELECT *
          FROM vw_replica_purge_partitions
         WHERE source_db_link = t.source_db_link
           AND source_owner = t.source_owner
           AND source_table_name = t.source_table_name
           AND target_owner = t.target_owner
           AND target_table_name = t.target_table_name
         ORDER BY partition_high_value, subpartition_high_value
      ) LOOP
        l_units := l_units + 1;

        IF r.archive_unit_type = 'SUBPARTITION' THEN
          l_sql := 'ALTER TABLE ' || fn_qualified_table(r.target_owner, r.target_table_name) ||
                   ' TRUNCATE SUBPARTITION ' || PKG_REPLICA_SQL.fn_assert_simple_name(r.subpartition_name);
        ELSE
          l_sql := 'ALTER TABLE ' || fn_qualified_table(r.target_owner, r.target_table_name) ||
                   ' TRUNCATE PARTITION ' || PKG_REPLICA_SQL.fn_assert_simple_name(r.partition_name);
        END IF;

        DBMS_OUTPUT.PUT_LINE('REPLICA_PURGE target=' || r.target_owner || '.' || r.target_table_name ||
                             ' ' || r.partition_name ||
                             CASE WHEN r.subpartition_name <> '#' THEN '.' || r.subpartition_name END ||
                             ' cutoff=' || TO_CHAR(r.cutoff_date, 'YYYY-MM-DD') ||
                             ' execute=' || l_execute_flag);

        l_purged := l_purged + PKG_REPLICA_SQL.fn_run_sql(l_log_id, l_sql, l_execute_flag);

        IF l_execute_flag = 'Y' THEN
          UPDATE tbl_replica_partitions
             SET purge_status = 'Y',
                 last_run_id = l_run_id,
                 error_message = NULL,
                 updated_at = SYSTIMESTAMP
           WHERE source_db_link = r.source_db_link
             AND source_owner = r.source_owner
             AND source_table_name = r.source_table_name
             AND partition_high_value = r.partition_high_value
             AND subpartition_high_value = r.subpartition_high_value;

          l_purged := l_purged + SQL%ROWCOUNT;
          COMMIT;
        END IF;

        l_table_summary := l_table_summary ||
          TO_CLOB(PKG_REPLICA_LOG.fn_summary_cell(CASE WHEN l_execute_flag = 'Y' THEN 'PURGED' ELSE 'PREVIEW' END)) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.source_partition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.source_subpartition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.partition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.subpartition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.partition_high_value) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.subpartition_high_value) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.replica_status) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.quality_status) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(CASE WHEN l_execute_flag = 'Y' THEN 'Y' ELSE r.purge_status END) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(TO_CHAR(r.source_row_count)) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(TO_CHAR(r.target_row_count)) || CHR(10);
      END LOOP;

      IF l_table_summary IS NOT NULL THEN
        l_summary := l_summary ||
          '=== TABLE: ' || t.source_db_link || '.' || t.source_owner || '.' || t.source_table_name || ' ===' || CHR(10) || CHR(10) ||
          PKG_REPLICA_SQL.fn_format_table
          (
            p_columns => 'SOURCE_DB_LINK|TABLE_OWNER|TABLE_NAME|EXECUTE',
            p_rows    => PKG_REPLICA_LOG.fn_summary_cell(t.source_db_link) || '|' ||
                         PKG_REPLICA_LOG.fn_summary_cell(t.source_owner) || '|' ||
                         PKG_REPLICA_LOG.fn_summary_cell(t.source_table_name) || '|' ||
                         PKG_REPLICA_LOG.fn_summary_cell(l_execute_flag) || CHR(10)
          ) || CHR(10) ||
          PKG_REPLICA_SQL.fn_format_table(l_partition_columns, l_table_summary) || CHR(10);
      END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('REPLICA_PURGE units=' || l_units || ' found=' || l_rows_available ||
                         ' purged=' || l_purged || ' execute=' || l_execute_flag);

    IF l_summary IS NOT NULL THEN
      PKG_REPLICA_LOG.prc_log_message(l_run_id, l_summary, 'SUMMARY');
    END IF;

    PKG_REPLICA_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_REPLICA_LOG.prc_log_error_stack(l_run_id);
        PKG_REPLICA_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_purge;
END PKG_REPLICA_PURGE;
/
