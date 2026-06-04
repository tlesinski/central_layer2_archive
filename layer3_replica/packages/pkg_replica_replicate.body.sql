CREATE OR REPLACE PACKAGE BODY PKG_REPLICA_REPLICATE
AS
  /*
    Package      : PKG_REPLICA_REPLICATE
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Replicate archived layer 2 partitions into layer 3 target
                   tables for the configured online window.

    Prerequisite : PKG_SQL, PKG_REPLICA_LOG, TW_REPLICA_REPLICATE_PARTITIONS_VW

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END fn_normalize_execute;

  FUNCTION fn_normalize_name(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_name IS NULL OR TRIM(p_name) IS NULL THEN
      RETURN NULL;
    END IF;

    RETURN PKG_SQL.fn_assert_simple_name(p_name);
  END fn_normalize_name;

  PROCEDURE prc_mark_partition
  (
    p_source_db_link          IN VARCHAR2,
    p_source_owner            IN VARCHAR2,
    p_source_table_name       IN VARCHAR2,
    p_partition_high_value    IN VARCHAR2,
    p_subpartition_high_value IN VARCHAR2,
    p_replica_status          IN VARCHAR2,
    p_run_id                  IN NUMBER,
    p_target_row_count        IN NUMBER DEFAULT NULL,
    p_error_message           IN VARCHAR2 DEFAULT NULL
  )
  IS
  BEGIN
    UPDATE tw_replica_partitions
       SET replica_status = p_replica_status,
           quality_status = CASE WHEN p_replica_status = 'Y' THEN 'N' ELSE quality_status END,
           target_row_count = COALESCE(p_target_row_count, target_row_count),
           last_run_id = p_run_id,
           error_message = p_error_message,
           updated_at = SYSTIMESTAMP
     WHERE source_db_link = p_source_db_link
       AND source_owner = p_source_owner
       AND source_table_name = p_source_table_name
       AND partition_high_value = p_partition_high_value
       AND subpartition_high_value = p_subpartition_high_value;
  END prc_mark_partition;

  PROCEDURE prc_replicate
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
    l_rows_loaded       NUMBER;
    l_staging_table     VARCHAR2(128);
    l_units             NUMBER := 0;
    l_replicated        NUMBER := 0;
    l_tables            NUMBER := 0;
    l_summary           CLOB := NULL;
    l_table_summary     CLOB;
    l_partition_columns VARCHAR2(1000) :=
      'NOTE|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_NAME|SUBPARTITION_NAME|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|REPLICA_STATUS|QUALITY_STATUS|PURGE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_REPLICA_LOG.fn_create_run('REPLICATE', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_REPLICA_LOG.fn_get_log_id(l_run_id);

    PKG_REPLICA_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started REPLICA REPLICATE with parameters:' || CHR(10) ||
                   '  p_execute           => ' || l_execute_flag || CHR(10) ||
                   '  p_target_owner      => ' || NVL(l_target_owner, '<ALL>') || CHR(10) ||
                   '  p_target_table_name => ' || NVL(l_target_table, '<ALL>')
    );

    IF l_execute_flag = 'Y' THEN
      COMMIT;
      EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    END IF;

    l_sql :=
      'SELECT COUNT(*) ' ||
      '  FROM TW_REPLICA_REPLICATE_PARTITIONS_VW ' ||
      ' WHERE (:1 IS NULL OR target_owner = :1) ' ||
      '   AND (:2 IS NULL OR target_table_name = :2)';

    l_rows_available := PKG_SQL.fn_run_into_sql_in_bind
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
        FROM tw_replica_replicate_partitions_vw
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_tables := l_tables + 1;
      l_table_summary := NULL;

      FOR r IN (
        SELECT p.*
          FROM tw_replica_replicate_partitions_vw p
         WHERE p.source_db_link = t.source_db_link
           AND p.source_owner = t.source_owner
           AND p.source_table_name = t.source_table_name
           AND p.target_owner = t.target_owner
           AND p.target_table_name = t.target_table_name
         ORDER BY p.partition_high_value, p.subpartition_high_value
      ) LOOP
        l_units := l_units + 1;
        l_rows_loaded := NULL;

        IF l_execute_flag = 'Y' THEN
          prc_mark_partition
          (
            r.source_db_link,
            r.source_owner,
            r.source_table_name,
            r.partition_high_value,
            r.subpartition_high_value,
            'N',
            l_run_id
          );
        END IF;

        PKG_REPLICA_PARTITION.prc_create_exchange_staging
        (
          p_target_owner       => r.target_owner,
          p_target_table       => r.target_table_name,
          p_partition_name     => r.partition_name,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id,
          p_tablespace_name    => r.tablespace_name
        );

        IF r.archive_unit_type = 'SUBPARTITION' THEN
          PKG_REPLICA_PARTITION.prc_load_exchange_staging_subpartition
          (
            p_source_db_link              => r.source_db_link,
            p_source_owner                => r.source_owner,
            p_source_table                => r.source_table_name,
            p_target_owner                => r.target_owner,
            p_target_table                => r.target_table_name,
            p_staging_table_name          => l_staging_table,
            p_partition_high_value        => r.partition_high_value,
            p_prev_partition_high_value   => r.prev_partition_high_value,
            p_subpartition_high_value     => r.subpartition_high_value,
            p_execute                     => l_execute_flag,
            p_log_id                      => l_log_id,
            p_parallel_degree             => r.parallel_degree,
            p_rows_loaded                 => l_rows_loaded
          );
        ELSE
          PKG_REPLICA_PARTITION.prc_load_exchange_staging
          (
            p_source_db_link        => r.source_db_link,
            p_source_owner          => r.source_owner,
            p_source_table          => r.source_table_name,
            p_target_owner          => r.target_owner,
            p_target_table          => r.target_table_name,
            p_staging_table_name    => l_staging_table,
            p_high_value            => r.partition_high_value,
            p_prev_high_value       => r.prev_partition_high_value,
            p_execute               => l_execute_flag,
            p_log_id                => l_log_id,
            p_parallel_degree       => r.parallel_degree,
            p_rows_loaded           => l_rows_loaded
          );
        END IF;

        PKG_REPLICA_PARTITION.prc_build_staging_indexes
        (
          p_target_owner       => r.target_owner,
          p_target_table       => r.target_table_name,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id,
          p_parallel_degree    => r.parallel_degree,
          p_tablespace_name    => r.tablespace_name
        );

        IF r.archive_unit_type = 'SUBPARTITION' THEN
          PKG_REPLICA_PARTITION.prc_exchange_subpartition
          (
            p_target_owner       => r.target_owner,
            p_target_table       => r.target_table_name,
            p_subpartition_name  => r.subpartition_name,
            p_staging_table_name => l_staging_table,
            p_execute            => l_execute_flag,
            p_log_id             => l_log_id
          );
        ELSE
          PKG_REPLICA_PARTITION.prc_exchange_partition
          (
            p_target_owner       => r.target_owner,
            p_target_table       => r.target_table_name,
            p_partition_name     => r.partition_name,
            p_staging_table_name => l_staging_table,
            p_execute            => l_execute_flag,
            p_log_id             => l_log_id
          );
        END IF;

        PKG_REPLICA_PARTITION.prc_drop_staging
        (
          p_staging_owner      => r.target_owner,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id
        );

        PKG_REPLICA_LOG.prc_log_message
        (
          p_run_id   => l_run_id,
          p_log_type => 'REPLICA_EXCHANGE',
          p_log_msg  => 'REPLICA_EXCHANGE ' ||
                        'source=' || r.source_db_link || '.' || r.source_owner || '.' || r.source_table_name ||
                        ' ' || r.source_partition_name ||
                        CASE
                          WHEN r.archive_unit_type = 'SUBPARTITION'
                            THEN '.' || r.source_subpartition_name
                        END ||
                        ', target=' || r.target_owner || '.' || r.target_table_name ||
                        ' ' || r.partition_name ||
                        CASE
                          WHEN r.archive_unit_type = 'SUBPARTITION'
                            THEN '.' || r.subpartition_name
                        END ||
                        ', staging=' || r.target_owner || '.' || l_staging_table ||
                        ', rows_loaded=' || NVL(TO_CHAR(l_rows_loaded), '<DRY_RUN>') ||
                        ', execute=' || l_execute_flag
        );

        IF l_execute_flag = 'Y' THEN
          prc_mark_partition
          (
            r.source_db_link,
            r.source_owner,
            r.source_table_name,
            r.partition_high_value,
            r.subpartition_high_value,
            'Y',
            l_run_id,
            l_rows_loaded
          );

          l_replicated := l_replicated + 1;
          COMMIT;
        END IF;

        DBMS_OUTPUT.PUT_LINE('REPLICATE_EXCHANGE ' ||
                             r.source_db_link || '.' || r.source_owner || '.' ||
                             r.source_table_name || ' ' || r.source_partition_name ||
                             CASE WHEN r.archive_unit_type = 'SUBPARTITION' THEN '.' || r.source_subpartition_name END ||
                             ' target=' || r.target_owner || '.' || r.target_table_name || ' ' ||
                             r.partition_name ||
                             CASE WHEN r.archive_unit_type = 'SUBPARTITION' THEN '.' || r.subpartition_name END ||
                             ' staging=' || r.target_owner || '.' || l_staging_table ||
                             ' loaded=' || NVL(TO_CHAR(l_rows_loaded), '<DRY_RUN>'));

        IF l_execute_flag = 'Y' THEN
          l_table_summary := l_table_summary ||
            TO_CLOB(PKG_REPLICA_LOG.fn_summary_cell('EXCHANGED')) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.source_partition_name) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.source_subpartition_name) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.partition_name) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.subpartition_name) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.partition_high_value) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.subpartition_high_value) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell('Y') || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell('N') || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(r.purge_status) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(TO_CHAR(r.source_row_count)) || '|' ||
            PKG_REPLICA_LOG.fn_summary_cell(TO_CHAR(l_rows_loaded)) || CHR(10);
        END IF;
      END LOOP;

      IF l_execute_flag = 'Y' AND l_table_summary IS NOT NULL THEN
        l_summary := l_summary ||
          '=== TABLE: ' || t.source_db_link || '.' || t.source_owner || '.' || t.source_table_name || ' ===' || CHR(10) || CHR(10) ||
          PKG_SQL.fn_format_table
          (
            p_columns => 'SOURCE_DB_LINK|TABLE_OWNER|TABLE_NAME|EXECUTE',
            p_rows    => PKG_REPLICA_LOG.fn_summary_cell(t.source_db_link) || '|' ||
                         PKG_REPLICA_LOG.fn_summary_cell(t.source_owner) || '|' ||
                         PKG_REPLICA_LOG.fn_summary_cell(t.source_table_name) || '|' ||
                         PKG_REPLICA_LOG.fn_summary_cell(l_execute_flag) || CHR(10)
          ) || CHR(10) ||
          PKG_SQL.fn_format_table
          (
            p_columns => l_partition_columns,
            p_rows    => l_table_summary
          ) || CHR(10);
      END IF;
    END LOOP;

    IF l_summary IS NOT NULL THEN
      PKG_REPLICA_LOG.prc_log_message(l_run_id, l_summary, 'SUMMARY');
    END IF;

    DBMS_OUTPUT.PUT_LINE(
      'REPLICATE tables=' || l_tables ||
      ' units=' || l_units ||
      ' found=' || l_rows_available ||
      ' replicated=' || l_replicated ||
      ' target_owner=' || NVL(l_target_owner, '<ALL>') ||
      ' target_table=' || NVL(l_target_table, '<ALL>') ||
      ' execute=' || l_execute_flag
    );

    PKG_REPLICA_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_REPLICA_LOG.prc_log_error_stack(l_run_id);
        PKG_REPLICA_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_replicate;
END PKG_REPLICA_REPLICATE;
/
