CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_IMPORT
AS
  FUNCTION normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION qualified_table(p_owner IN VARCHAR2, p_table IN VARCHAR2, p_source_db_link IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_owner) || '.' || PKG_SQL.fn_assert_simple_name(p_table);
    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;
    RETURN l_name;
  END;

  FUNCTION create_run(p_source_db_link IN VARCHAR2, p_source_owner IN VARCHAR2, p_source_table IN VARCHAR2, p_execute IN VARCHAR2)
  RETURN NUMBER
  IS
  BEGIN
    RETURN PKG_ARCHIVE_LOG.create_run('ARCHIVE', p_source_db_link, p_source_owner, p_source_table, p_execute);
  END;

  PROCEDURE finish_run(p_run_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    PKG_ARCHIVE_LOG.finish_run(p_run_id, p_status, p_error_message);
  END;

  PROCEDURE mark_partition
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
  END mark_partition;

  PROCEDURE import_one_table
  (
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_target_owner   IN VARCHAR2,
    p_target_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  IS
    l_run_id        NUMBER;
    l_target_table  VARCHAR2(300);
    l_rows_loaded   NUMBER;
    l_units         NUMBER := 0;
    l_imported      NUMBER := 0;
    l_execute_flag  VARCHAR2(1);
    l_log_id        NUMBER;
    l_staging_table VARCHAR2(128);
  BEGIN
    l_execute_flag := normalize_execute(p_execute);
    l_run_id := create_run(p_source_db_link, p_source_owner, p_source_table, p_execute);
    l_log_id := PKG_ARCHIVE_LOG.get_log_id(l_run_id);
    l_target_table := qualified_table(p_target_owner, p_target_table);

    FOR r IN (
      SELECT p.*,
             (
               SELECT MAX(pp.PARTITION_HIGH_VALUE) KEEP (DENSE_RANK LAST ORDER BY pp.PARTITION_POSITION)
                 FROM TW_ARCHIVE_PARTITIONS pp
                WHERE pp.SOURCE_DB_LINK = p.SOURCE_DB_LINK
                  AND pp.SOURCE_OWNER = p.SOURCE_OWNER
                  AND pp.SOURCE_TABLE_NAME = p.SOURCE_TABLE_NAME
                  AND pp.PARTITION_POSITION < p.PARTITION_POSITION
             ) AS PREV_PARTITION_HIGH_VALUE
        FROM TW_ARCHIVE_PARTITIONS p
       WHERE SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_source_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_source_table)
         AND TARGET_OWNER = UPPER(p_target_owner)
         AND TARGET_TABLE_NAME = UPPER(p_target_table)
         AND ARCHIVE_STATUS = 'N'
       ORDER BY PARTITION_POSITION, SUBPARTITION_POSITION
    ) LOOP
      l_units := l_units + 1;

      IF l_execute_flag = 'Y' THEN
        mark_partition(
          r.SOURCE_DB_LINK,
          r.SOURCE_OWNER,
          r.SOURCE_TABLE_NAME,
          r.PARTITION_HIGH_VALUE,
          r.SUBPARTITION_HIGH_VALUE,
          'N',
          l_run_id
        );
      END IF;

      PKG_ARCHIVE_PARTITION.create_exchange_staging
      (
        p_target_owner       => p_target_owner,
        p_target_table       => p_target_table,
        p_partition_name     => r.PARTITION_NAME,
        p_staging_table_name => l_staging_table,
        p_execute            => l_execute_flag,
        p_log_id             => l_log_id
      );

      IF r.ARCHIVE_UNIT_TYPE = 'SUBPARTITION' THEN
        PKG_ARCHIVE_PARTITION.load_exchange_staging_subpartition
        (
          p_source_db_link             => p_source_db_link,
          p_source_owner               => p_source_owner,
          p_source_table               => p_source_table,
          p_target_owner               => p_target_owner,
          p_target_table               => p_target_table,
          p_staging_table_name         => l_staging_table,
          p_partition_high_value       => r.PARTITION_HIGH_VALUE,
          p_prev_partition_high_value  => r.PREV_PARTITION_HIGH_VALUE,
          p_subpartition_high_value    => r.SUBPARTITION_HIGH_VALUE,
          p_execute                    => l_execute_flag,
          p_log_id                     => l_log_id,
          p_rows_loaded                => l_rows_loaded
        );
      ELSE
        PKG_ARCHIVE_PARTITION.load_exchange_staging
        (
          p_source_db_link     => p_source_db_link,
          p_source_owner       => p_source_owner,
          p_source_table       => p_source_table,
          p_target_owner       => p_target_owner,
          p_target_table       => p_target_table,
          p_staging_table_name => l_staging_table,
          p_high_value         => r.PARTITION_HIGH_VALUE,
          p_prev_high_value    => r.PREV_PARTITION_HIGH_VALUE,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id,
          p_rows_loaded        => l_rows_loaded
        );
      END IF;

      PKG_ARCHIVE_PARTITION.build_staging_indexes
      (
        p_target_owner       => p_target_owner,
        p_target_table       => p_target_table,
        p_staging_table_name => l_staging_table,
        p_execute            => l_execute_flag,
        p_log_id             => l_log_id
      );

      IF r.ARCHIVE_UNIT_TYPE = 'SUBPARTITION' THEN
        PKG_ARCHIVE_PARTITION.exchange_subpartition
        (
          p_target_owner       => p_target_owner,
          p_target_table       => p_target_table,
          p_subpartition_name  => r.SUBPARTITION_NAME,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id
        );
      ELSE
        PKG_ARCHIVE_PARTITION.exchange_partition
        (
          p_target_owner       => p_target_owner,
          p_target_table       => p_target_table,
          p_partition_name     => r.PARTITION_NAME,
          p_staging_table_name => l_staging_table,
          p_execute            => l_execute_flag,
          p_log_id             => l_log_id
        );
      END IF;

      PKG_ARCHIVE_PARTITION.drop_staging
      (
        p_staging_owner      => p_target_owner,
        p_staging_table_name => l_staging_table,
        p_execute            => l_execute_flag,
        p_log_id             => l_log_id
      );

      IF l_execute_flag = 'Y' THEN
        mark_partition(
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
        DBMS_OUTPUT.PUT_LINE('IMPORT_DONE EXCHANGE ' ||
                             UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' ||
                             UPPER(p_source_table) || ' ' || r.PARTITION_NAME ||
                             CASE WHEN r.ARCHIVE_UNIT_TYPE = 'SUBPARTITION' THEN '.' || r.SUBPARTITION_NAME END ||
                             ' loaded=' || l_rows_loaded || ' target_rows=' || l_rows_loaded);
      END IF;
    END LOOP;

    IF l_execute_flag = 'Y' THEN COMMIT; END IF;
    DBMS_OUTPUT.PUT_LINE('IMPORT_SUMMARY ' || UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' ||
                         UPPER(p_source_table) || ' units=' || l_units || ' imported=' || l_imported ||
                         ' execute=' || l_execute_flag);
    finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN finish_run(l_run_id, 'ERROR', SQLERRM); END IF;
      RAISE;
  END;

  PROCEDURE import_table(p_source_db_link IN VARCHAR2, p_owner IN VARCHAR2, p_table_name IN VARCHAR2, p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, TARGET_OWNER, TARGET_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
         AND SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_table_name)
    ) LOOP
      import_one_table(r.SOURCE_DB_LINK, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, r.TARGET_OWNER, r.TARGET_TABLE_NAME, p_execute);
    END LOOP;
  END;

  PROCEDURE import_all(p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, TARGET_OWNER, TARGET_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
       ORDER BY SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME
    ) LOOP
      import_one_table(r.SOURCE_DB_LINK, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, r.TARGET_OWNER, r.TARGET_TABLE_NAME, p_execute);
    END LOOP;
  END;
END PKG_ARCHIVE_IMPORT;
/
