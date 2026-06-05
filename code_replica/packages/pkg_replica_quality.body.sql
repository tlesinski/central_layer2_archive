CREATE OR REPLACE PACKAGE BODY PKG_REPLICA_QUALITY
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

  FUNCTION fn_source_table
  (
    p_source_db_link    IN VARCHAR2,
    p_source_owner      IN VARCHAR2,
    p_source_table_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_table VARCHAR2(4000);
  BEGIN
    IF p_source_db_link IS NULL OR TRIM(p_source_db_link) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20047, 'SOURCE_DB_LINK is required for layer 3 source row counts');
    END IF;

    l_table := fn_qualified_table(p_source_owner, p_source_table_name);

    l_table := l_table || '@' || PKG_REPLICA_SQL.fn_assert_simple_name(p_source_db_link);

    RETURN l_table;
  END;

  FUNCTION fn_high_value_to_date(p_high_value IN VARCHAR2) RETURN DATE IS
    l_date DATE;
  BEGIN
    IF p_high_value IS NULL OR UPPER(TRIM(p_high_value)) = 'MAXVALUE' THEN
      RETURN NULL;
    END IF;

    EXECUTE IMMEDIATE 'SELECT ' || p_high_value || ' FROM dual' INTO l_date;
    RETURN l_date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END fn_high_value_to_date;

  FUNCTION fn_first_partition_key_column
  (
    p_owner IN VARCHAR2,
    p_table IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_column_name VARCHAR2(128);
  BEGIN
    SELECT column_name
      INTO l_column_name
      FROM all_part_key_columns
     WHERE owner = UPPER(p_owner)
       AND name = UPPER(p_table)
       AND object_type = 'TABLE'
       AND column_position = 1;

    RETURN PKG_REPLICA_SQL.fn_assert_simple_name(l_column_name);
  END fn_first_partition_key_column;

  FUNCTION fn_first_subpartition_key_column
  (
    p_owner IN VARCHAR2,
    p_table IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_column_name VARCHAR2(128);
  BEGIN
    SELECT column_name
      INTO l_column_name
      FROM all_subpart_key_columns
     WHERE owner = UPPER(p_owner)
       AND name = UPPER(p_table)
       AND object_type = 'TABLE'
       AND column_position = 1;

    RETURN PKG_REPLICA_SQL.fn_assert_simple_name(l_column_name);
  END fn_first_subpartition_key_column;

  PROCEDURE prc_quality
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
    l_source_rows       NUMBER;
    l_target_rows       NUMBER;
    l_units             NUMBER := 0;
    l_ok                NUMBER := 0;
    l_failed            NUMBER := 0;
    l_quality_status    VARCHAR2(1);
    l_part_key_column   VARCHAR2(128);
    l_sub_key_column    VARCHAR2(128);
    l_high_date         DATE;
    l_low_date          DATE;
    l_summary           CLOB := NULL;
    l_table_summary     CLOB;
    l_partition_columns VARCHAR2(1000) :=
      'NOTE|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_NAME|SUBPARTITION_NAME|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|REPLICA_STATUS|QUALITY_STATUS|PURGE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_REPLICA_LOG.fn_create_run('QUALITY', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_REPLICA_LOG.fn_get_log_id(l_run_id);

    PKG_REPLICA_LOG.prc_log_message(l_run_id, 'Started REPLICA QUALITY execute=' || l_execute_flag);

    l_sql :=
      'SELECT COUNT(*) FROM VW_REPLICA_QUALITY_PARTITIONS ' ||
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
        FROM vw_replica_quality_partitions
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_table_summary := NULL;

      FOR r IN (
        SELECT *
          FROM vw_replica_quality_partitions
         WHERE source_db_link = t.source_db_link
           AND source_owner = t.source_owner
           AND source_table_name = t.source_table_name
           AND target_owner = t.target_owner
           AND target_table_name = t.target_table_name
         ORDER BY partition_high_value, subpartition_high_value
      ) LOOP
        l_units := l_units + 1;

        l_part_key_column := fn_first_partition_key_column(r.target_owner, r.target_table_name);
        l_high_date := fn_high_value_to_date(r.partition_high_value);
        l_low_date := fn_high_value_to_date(r.prev_partition_high_value);

        IF l_high_date IS NULL THEN
          RAISE_APPLICATION_ERROR(-20051, 'REPLICA QUALITY requires a DATE partition high value');
        END IF;

        l_sql := 'SELECT COUNT(*) FROM ' ||
                 fn_source_table(r.source_db_link, r.source_owner, r.source_table_name) ||
                 ' WHERE ' || l_part_key_column || ' < DATE ''' || TO_CHAR(l_high_date, 'YYYY-MM-DD') || '''';

        IF l_low_date IS NOT NULL THEN
          l_sql := l_sql || ' AND ' || l_part_key_column || ' >= DATE ''' || TO_CHAR(l_low_date, 'YYYY-MM-DD') || '''';
        END IF;

        IF r.archive_unit_type = 'SUBPARTITION' THEN
          l_sub_key_column := fn_first_subpartition_key_column(r.target_owner, r.target_table_name);
          IF r.subpartition_high_value IS NULL OR TRIM(r.subpartition_high_value) = '#' THEN
            RAISE_APPLICATION_ERROR(-20052, 'REPLICA QUALITY requires a list subpartition high value');
          END IF;
          l_sql := l_sql || ' AND ' || l_sub_key_column || ' IN (' || r.subpartition_high_value || ')';
        END IF;

        l_source_rows := PKG_REPLICA_SQL.fn_run_into_sql(l_log_id, l_sql, 'Y');

        IF r.archive_unit_type = 'SUBPARTITION' THEN
          l_sql := 'SELECT COUNT(*) FROM ' || fn_qualified_table(r.target_owner, r.target_table_name) ||
                   ' SUBPARTITION (' || PKG_REPLICA_SQL.fn_assert_simple_name(r.subpartition_name) || ')';
        ELSE
          l_sql := 'SELECT COUNT(*) FROM ' || fn_qualified_table(r.target_owner, r.target_table_name) ||
                   ' PARTITION (' || PKG_REPLICA_SQL.fn_assert_simple_name(r.partition_name) || ')';
        END IF;

        l_target_rows := PKG_REPLICA_SQL.fn_run_into_sql(l_log_id, l_sql, 'Y');
        l_quality_status := CASE WHEN l_source_rows = l_target_rows THEN 'Y' ELSE 'N' END;

        IF l_quality_status = 'Y' THEN
          l_ok := l_ok + 1;
        ELSE
          l_failed := l_failed + 1;
        END IF;

        DBMS_OUTPUT.PUT_LINE('REPLICA_QUALITY ' || r.source_db_link || '.' || r.source_owner || '.' ||
                             r.source_table_name || ' source=' || r.source_partition_name ||
                             CASE WHEN r.source_subpartition_name <> '#' THEN '.' || r.source_subpartition_name END ||
                             ' target=' || r.partition_name ||
                             CASE WHEN r.subpartition_name <> '#' THEN '.' || r.subpartition_name END ||
                             ' source_rows=' || l_source_rows ||
                             ' target_rows=' || l_target_rows ||
                             ' status=' || l_quality_status ||
                             ' execute=' || l_execute_flag);

        IF l_execute_flag = 'Y' THEN
          UPDATE tbl_replica_partitions
             SET source_row_count = l_source_rows,
                 target_row_count = l_target_rows,
                 quality_status = l_quality_status,
                 last_run_id = l_run_id,
                 error_message = CASE WHEN l_quality_status = 'Y' THEN NULL ELSE 'Source row count does not match target row count' END,
                 updated_at = SYSTIMESTAMP
           WHERE source_db_link = r.source_db_link
             AND source_owner = r.source_owner
             AND source_table_name = r.source_table_name
             AND partition_high_value = r.partition_high_value
             AND subpartition_high_value = r.subpartition_high_value;

          COMMIT;
        END IF;

        l_table_summary := l_table_summary ||
          TO_CLOB(PKG_REPLICA_LOG.fn_summary_cell(CASE WHEN l_quality_status = 'Y' THEN 'OK' ELSE 'MISMATCH' END)) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.source_partition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.source_subpartition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.partition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.subpartition_name) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.partition_high_value) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.subpartition_high_value) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.replica_status) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(l_quality_status) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(r.purge_status) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(TO_CHAR(l_source_rows)) || '|' ||
          PKG_REPLICA_LOG.fn_summary_cell(TO_CHAR(l_target_rows)) || CHR(10);
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

    DBMS_OUTPUT.PUT_LINE('REPLICA_QUALITY units=' || l_units || ' found=' || l_rows_available ||
                         ' ok=' || l_ok || ' failed=' || l_failed || ' execute=' || l_execute_flag);

    IF l_summary IS NOT NULL THEN
      PKG_REPLICA_LOG.prc_log_message(l_run_id, l_summary, 'SUMMARY');
    END IF;

    PKG_REPLICA_LOG.prc_finish_run(l_run_id, CASE WHEN l_failed > 0 THEN 'WARNING' ELSE 'SUCCESS' END);
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_REPLICA_LOG.prc_log_error_stack(l_run_id);
        PKG_REPLICA_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_quality;
END PKG_REPLICA_QUALITY;
/
