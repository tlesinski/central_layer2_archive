CREATE OR REPLACE PACKAGE PKG_REPLICA_PARTITION
AS
  /*
    Package      : PKG_REPLICA_PARTITION
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Partition exchange staging for layer 3 replica -
                   create staging, load from L2 source partition,
                   build indexes, exchange, drop staging.

    Prerequisite : PKG_SQL, PKG_REPLICA_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  PROCEDURE prc_create_exchange_staging
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_partition_name     IN VARCHAR2,
    p_staging_table_name OUT VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_tablespace_name    IN VARCHAR2
  );

  PROCEDURE prc_load_exchange_staging
  (
    p_source_db_link         IN VARCHAR2,
    p_source_owner           IN VARCHAR2,
    p_source_table           IN VARCHAR2,
    p_target_owner           IN VARCHAR2,
    p_target_table           IN VARCHAR2,
    p_staging_table_name     IN VARCHAR2,
    p_high_value             IN VARCHAR2,
    p_prev_high_value        IN VARCHAR2 DEFAULT NULL,
    p_execute                IN VARCHAR2 DEFAULT 'Y',
    p_log_id                 IN NUMBER DEFAULT NULL,
    p_parallel_degree        IN NUMBER DEFAULT 4,
    p_rows_loaded            OUT NUMBER
  );

  PROCEDURE prc_load_exchange_staging_subpartition
  (
    p_source_db_link              IN VARCHAR2,
    p_source_owner                IN VARCHAR2,
    p_source_table                IN VARCHAR2,
    p_target_owner                IN VARCHAR2,
    p_target_table                IN VARCHAR2,
    p_staging_table_name          IN VARCHAR2,
    p_partition_high_value        IN VARCHAR2,
    p_prev_partition_high_value   IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value     IN VARCHAR2,
    p_execute                     IN VARCHAR2 DEFAULT 'Y',
    p_log_id                      IN NUMBER DEFAULT NULL,
    p_parallel_degree             IN NUMBER DEFAULT 4,
    p_rows_loaded                 OUT NUMBER
  );

  PROCEDURE prc_build_staging_indexes
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_parallel_degree    IN NUMBER DEFAULT 4,
    p_tablespace_name    IN VARCHAR2
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

  PROCEDURE prc_cleanup_orphan_staging
  (
    p_retention_days IN NUMBER DEFAULT 30,
    p_execute        IN VARCHAR2 DEFAULT 'N',
    p_log_id         IN NUMBER DEFAULT NULL
  );
END PKG_REPLICA_PARTITION;
/
