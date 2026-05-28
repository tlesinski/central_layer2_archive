CREATE OR REPLACE PACKAGE PKG_ARCHIVE_PARTITION
AS
  PROCEDURE prc_create_exchange_staging
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_partition_name     IN VARCHAR2,
    p_staging_table_name OUT VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  );

  PROCEDURE prc_load_exchange_staging
  (
    p_source_db_link     IN VARCHAR2,
    p_source_owner       IN VARCHAR2,
    p_source_table       IN VARCHAR2,
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_high_value         IN VARCHAR2,
    p_prev_high_value    IN VARCHAR2 DEFAULT NULL,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_rows_loaded        OUT NUMBER
  );

  PROCEDURE prc_load_exchange_staging_subpartition
  (
    p_source_db_link         IN VARCHAR2,
    p_source_owner           IN VARCHAR2,
    p_source_table           IN VARCHAR2,
    p_target_owner           IN VARCHAR2,
    p_target_table           IN VARCHAR2,
    p_staging_table_name     IN VARCHAR2,
    p_partition_high_value   IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value IN VARCHAR2,
    p_execute                IN VARCHAR2 DEFAULT 'Y',
    p_log_id                 IN NUMBER DEFAULT NULL,
    p_rows_loaded            OUT NUMBER
  );

  PROCEDURE prc_build_staging_indexes
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  );

  PROCEDURE prc_exchange_partition
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_partition_name     IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  );

  PROCEDURE prc_exchange_subpartition
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_subpartition_name  IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  );

  PROCEDURE prc_drop_staging
  (
    p_staging_owner      IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  );
END PKG_ARCHIVE_PARTITION;
/
