CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_IMPORT
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

    RETURN PKG_SQL.fn_assert_simple_name(p_name);
  END;

  PROCEDURE prc_mark_partition
  (
    p_source_db_link          IN VARCHAR2,
    p_source_owner            IN VARCHAR2,
    p_source_table_name       IN VARCHAR2,
    p_partition_high_value    IN VARCHAR2,
    p_subpartition_high_value IN VARCHAR2,
    p_archive_status   IN VARCHAR2,
    p_run_id           IN NUMBER,
    p_target_row_count IN NUMBER DEFAULT NULL,
    p_error_message    IN VARCHAR2 DEFAULT NULL
  )
  IS
  BEGIN
    UPDATE TW_ARCHIVE_PARTITIONS
       SET ARCHIVE_STATUS = p_archive_status,
           QUALITY_STATUS = CASE WHEN p_archive_status = 'Y' THEN 'N' ELSE QUALITY_STATUS END,
           TARGET_ROW_COUNT = COALESCE(p_target_row_count, TARGET_ROW_COUNT),
           LAST_RUN_ID = p_run_id,
           ERROR_MESSAGE = p_error_message,
           UPDATED_AT = SYSTIMESTAMP
     WHERE SOURCE_DB_LINK = p_source_db_link
       AND SOURCE_OWNER = p_source_owner
       AND SOURCE_TABLE_NAME = p_source_table_name
       AND PARTITION_HIGH_VALUE = p_partition_high_value
       AND SUBPARTITION_HIGH_VALUE = p_subpartition_high_value;
  END prc_mark_partition;

  PROCEDURE prc_import
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
    l_rows_available  NUMBER := 0;
    l_rows_loaded     NUMBER;
    l_units           NUMBER := 0;
    l_imported        NUMBER := 0;
    l_tables          NUMBER := 0;
    l_staging_table   VARCHAR2(128);
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('ARCHIVE', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVE_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Import filter: target_owner=' || NVL(l_target_owner, '<ALL>') ||
                   ', target_table_name=' || NVL(l_target_table, '<ALL>')
    );

    l_sql :=
      'SELECT COUNT(*) ' ||
      '  FROM TW_ARCHIVE_IMPORT_PARTITIONS_VW ' ||
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
        FROM TW_ARCHIVE_IMPORT_PARTITIONS_VW
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_tables := l_tables + 1;

      FOR r IN (
        SELECT p.*
          FROM TW_ARCHIVE_IMPORT_PARTITIONS_VW p
         WHERE p.source_db_link = t.source_db_link
           AND p.source_owner = t.source_owner
           AND p.source_table_name = t.source_table_name
           AND p.target_owner = t.target_owner
           AND p.target_table_name = t.target_table_name
         ORDER BY p.partition_position, p.subpartition_position
      ) LOOP
        l_units := l_units + 1;
        l_rows_loaded := NULL;

        IF l_execute_flag = 'Y' THEN
          prc_mark_partition(
            r.SOURCE_DB_LINK,
            r.SOURCE_OWNER,
            r.SOURCE_TABLE_NAME,
            r.PARTITION_HIGH_VALUE,
            r.SUBPARTITION_HIGH_VALUE,
            'N',
            l_run_id
          );
        END IF;

        PKG_ARCHIVE_PARTITION.prc_create_exchange_staging
        (
          p_target_owner       => r.TARGET_OWNER,
          p_target_table       => r.TARGET_TABLE_NAME,
          p_partition_name     => r.PARTITION_NAME,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id
        );

        IF r.ARCHIVE_UNIT_TYPE = 'SUBPARTITION' THEN
          PKG_ARCHIVE_PARTITION.prc_load_exchange_staging_subpartition
          (
            p_source_db_link             => r.SOURCE_DB_LINK,
            p_source_owner               => r.SOURCE_OWNER,
            p_source_table               => r.SOURCE_TABLE_NAME,
            p_target_owner               => r.TARGET_OWNER,
            p_target_table               => r.TARGET_TABLE_NAME,
            p_staging_table_name         => l_staging_table,
            p_partition_high_value       => r.PARTITION_HIGH_VALUE,
            p_prev_partition_high_value  => r.PREV_PARTITION_HIGH_VALUE,
            p_subpartition_high_value    => r.SUBPARTITION_HIGH_VALUE,
            p_execute                    => l_execute_flag,
            p_log_id                     => l_log_id,
            p_rows_loaded                => l_rows_loaded
          );
        ELSE
          PKG_ARCHIVE_PARTITION.prc_load_exchange_staging
          (
            p_source_db_link     => r.SOURCE_DB_LINK,
            p_source_owner       => r.SOURCE_OWNER,
            p_source_table       => r.SOURCE_TABLE_NAME,
            p_target_owner       => r.TARGET_OWNER,
            p_target_table       => r.TARGET_TABLE_NAME,
            p_staging_table_name => l_staging_table,
            p_high_value         => r.PARTITION_HIGH_VALUE,
            p_prev_high_value    => r.PREV_PARTITION_HIGH_VALUE,
            p_execute            => l_execute_flag,
            p_log_id             => l_log_id,
            p_rows_loaded        => l_rows_loaded
          );
        END IF;

        PKG_ARCHIVE_PARTITION.prc_build_staging_indexes
        (
          p_target_owner       => r.TARGET_OWNER,
          p_target_table       => r.TARGET_TABLE_NAME,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id
        );

        IF r.ARCHIVE_UNIT_TYPE = 'SUBPARTITION' THEN
          PKG_ARCHIVE_PARTITION.prc_exchange_subpartition
          (
            p_target_owner       => r.TARGET_OWNER,
            p_target_table       => r.TARGET_TABLE_NAME,
            p_subpartition_name  => r.SUBPARTITION_NAME,
            p_staging_table_name => l_staging_table,
            p_execute            => l_execute_flag,
            p_log_id             => l_log_id
          );
        ELSE
          PKG_ARCHIVE_PARTITION.prc_exchange_partition
          (
            p_target_owner       => r.TARGET_OWNER,
            p_target_table       => r.TARGET_TABLE_NAME,
            p_partition_name     => r.PARTITION_NAME,
            p_staging_table_name => l_staging_table,
            p_execute            => l_execute_flag,
            p_log_id             => l_log_id
          );
        END IF;

        PKG_ARCHIVE_PARTITION.prc_drop_staging
        (
          p_staging_owner      => r.TARGET_OWNER,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id
        );

        IF l_execute_flag = 'Y' THEN
          prc_mark_partition(
            r.SOURCE_DB_LINK,
            r.SOURCE_OWNER,
            r.SOURCE_TABLE_NAME,
            r.PARTITION_HIGH_VALUE,
            r.SUBPARTITION_HIGH_VALUE,
            'Y',
            l_run_id,
            l_rows_loaded
          );

          l_imported := l_imported + 1;
          COMMIT;
        END IF;

        DBMS_OUTPUT.PUT_LINE('IMPORT_DONE EXCHANGE ' ||
                             r.SOURCE_DB_LINK || '.' || r.SOURCE_OWNER || '.' ||
                             r.SOURCE_TABLE_NAME || ' ' || r.PARTITION_NAME ||
                             CASE WHEN r.ARCHIVE_UNIT_TYPE = 'SUBPARTITION' THEN '.' || r.SUBPARTITION_NAME END ||
                             ' loaded=' || NVL(TO_CHAR(l_rows_loaded), '<DRY_RUN>') ||
                             ' target_rows=' || NVL(TO_CHAR(l_rows_loaded), '<DRY_RUN>'));
      END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(
      'IMPORT tables=' || l_tables ||
      ' units=' || l_units ||
      ' found=' || l_rows_available ||
      ' imported=' || l_imported ||
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
  END prc_import;
END PKG_ARCHIVE_IMPORT;
/


