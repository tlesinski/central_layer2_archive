CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVER_AUDIT
AS
  /* Manual audit. It writes audit history only and never changes operational metadata. */
  FUNCTION fn_name(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF TRIM(p_name) IS NULL THEN RETURN NULL; END IF;
    RETURN PKG_ARCHIVER_SQL.fn_assert_simple_name(p_name);
  END;

  PROCEDURE prc_soft_count
  (
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  ) IS
    l_run_id NUMBER;
    l_log_id NUMBER;
    l_owner VARCHAR2(128) := fn_name(p_target_owner);
    l_table VARCHAR2(128) := fn_name(p_target_table_name);
    l_source_count NUMBER;
    l_target_count NUMBER;
    l_status VARCHAR2(20);
    l_error VARCHAR2(4000);
    l_sql CLOB;
    l_units NUMBER := 0;
    l_matches NUMBER := 0;
    l_mismatches NUMBER := 0;
    l_errors NUMBER := 0;
  BEGIN
    l_run_id := PKG_ARCHIVER_LOG.fn_create_run('SOFT_COUNT', NULL, NULL, NULL, 'Y');
    l_log_id := PKG_ARCHIVER_LOG.fn_get_log_id(l_run_id);
    PKG_ARCHIVER_LOG.prc_log_message(l_run_id,
      'Started SOFT_COUNT target_owner=' || NVL(l_owner, '<ALL>') ||
      ' target_table=' || NVL(l_table, '<ALL>'));

    FOR r IN (
      SELECT p.*, v.current_source_partition_name, v.current_source_subpartition_name,
             v.current_target_partition_name, v.current_target_subpartition_name
        FROM TBL_ARCHIVER_PARTITIONS p
        LEFT JOIN VW_ARCHIVER_SOFT_VALIDATION v
          ON v.source_db_link=p.source_db_link AND v.source_owner=p.source_owner
         AND v.source_table_name=p.source_table_name
         AND v.partition_high_value=p.partition_high_value
         AND v.subpartition_high_value=p.subpartition_high_value
       WHERE p.archive_status='Y' AND p.quality_status='Y' AND p.truncate_status='N'
         AND (l_owner IS NULL OR p.target_owner=l_owner)
         AND (l_table IS NULL OR p.target_table_name=l_table)
       ORDER BY p.source_db_link, p.source_owner, p.source_table_name,
                p.partition_high_value, p.subpartition_high_value
    ) LOOP
      l_units := l_units + 1;
      l_source_count := NULL; l_target_count := NULL; l_error := NULL;
      BEGIN
        l_sql := 'SELECT PKG_AGENT_ARCHIVE.FN_GET_ROW_COUNT@' ||
                 PKG_ARCHIVER_SQL.fn_assert_simple_name(r.source_db_link) ||
                 '(:1,:2,:3,:4,:5,:6) FROM dual';
        l_source_count := PKG_ARCHIVER_SQL.fn_run_into_sql_in_bind(
          l_log_id, l_sql,
          SYS.ODCIVARCHAR2LIST(r.source_owner, r.source_table_name,
            r.partition_high_value, r.prev_partition_high_value,
            CASE WHEN r.subpartition_high_value='#' THEN NULL ELSE r.subpartition_high_value END,
            r.archive_unit_type), 'Y');

        l_sql := 'SELECT COUNT(*) FROM ' ||
                 PKG_ARCHIVER_SQL.fn_assert_simple_name(r.target_owner) || '.' ||
                 PKG_ARCHIVER_SQL.fn_assert_simple_name(r.target_table_name) || ' ' ||
                 PKG_ARCHIVER_PARTITION.fn_partition_for_clause(
                   r.target_owner, r.target_table_name, r.partition_high_value,
                   r.prev_partition_high_value,
                   CASE WHEN r.subpartition_high_value='#' THEN NULL ELSE r.subpartition_high_value END,
                   r.archive_unit_type);
        l_target_count := PKG_ARCHIVER_SQL.fn_run_into_sql_in_bind(
          l_log_id, l_sql, SYS.ODCIVARCHAR2LIST(), 'Y');
        IF l_source_count = l_target_count THEN
          l_status := 'MATCH'; l_matches := l_matches + 1;
        ELSE
          l_status := 'MISMATCH'; l_mismatches := l_mismatches + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        l_status := 'ERROR'; l_error := SUBSTR(SQLERRM,1,4000); l_errors := l_errors + 1;
      END;

      INSERT INTO TBL_ARCHIVER_AUDIT_RESULTS
      (run_id, source_db_link, source_owner, source_table_name,
       target_owner, target_table_name, archive_unit_type,
       partition_high_value, subpartition_high_value, prev_partition_high_value,
       source_partition_name, source_subpartition_name,
       target_partition_name, target_subpartition_name,
       stored_source_row_count, stored_target_row_count,
       fresh_source_row_count, fresh_target_row_count, count_difference,
       audit_status, error_message)
      VALUES
      (l_run_id, r.source_db_link, r.source_owner, r.source_table_name,
       r.target_owner, r.target_table_name, r.archive_unit_type,
       r.partition_high_value, r.subpartition_high_value, r.prev_partition_high_value,
       r.current_source_partition_name, r.current_source_subpartition_name,
       r.current_target_partition_name, r.current_target_subpartition_name,
       r.source_row_count, r.target_row_count,
       l_source_count, l_target_count, l_source_count-l_target_count,
       l_status, l_error);
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('SOFT_COUNT ' || r.source_owner || '.' || r.source_table_name ||
        ' high_value=' || r.partition_high_value || ' status=' || l_status ||
        ' source=' || NVL(TO_CHAR(l_source_count),'NULL') ||
        ' target=' || NVL(TO_CHAR(l_target_count),'NULL') ||
        CASE WHEN l_error IS NOT NULL THEN ' error=' || l_error END);
    END LOOP;

    PKG_ARCHIVER_LOG.prc_log_message(l_run_id,
      'SOFT_COUNT units=' || l_units || ' match=' || l_matches ||
      ' mismatch=' || l_mismatches || ' errors=' || l_errors, 'SUMMARY');
    PKG_ARCHIVER_LOG.prc_finish_run(l_run_id,
      CASE WHEN l_mismatches+l_errors > 0 THEN 'WARNING' ELSE 'SUCCESS' END);
  EXCEPTION WHEN OTHERS THEN
    IF l_run_id IS NOT NULL THEN
      PKG_ARCHIVER_LOG.prc_log_error_stack(l_run_id);
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
    END IF;
    RAISE;
  END prc_soft_count;
END PKG_ARCHIVER_AUDIT;
/
