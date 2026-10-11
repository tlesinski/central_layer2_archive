CREATE OR REPLACE PACKAGE PKG_ARCHIVER_PARTITION
AS
  /*
    Package      : PKG_ARCHIVER_PARTITION
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Partition operations - exchange staging, load staging data,
                   build staging indexes, exchange, drop staging

    Prerequisite : PKG_ARCHIVER_SQL, PKG_ARCHIVER_LOGGING

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
    1.1        2026-05-28   Tomasz Lesinski    Add PARALLEL_DEGREE support
    1.2        2026-10-11   Tomasz Lesinski    Resolve exchange units with
                                                PARTITION FOR selectors
  */
  -- Builds the PARTITION FOR or SUBPARTITION FOR clause for an archive unit.
  -- Parameters:
  -- p_target_owner              schema owning the archive target
  -- p_target_table              archive target table name
  -- p_partition_high_value      partition HIGH_VALUE expression
  -- p_prev_partition_high_value previous partition HIGH_VALUE; RANGE selector value
  -- p_subpartition_high_value   subpartition HIGH_VALUE expression, when applicable
  -- p_archive_unit_type         unit type used to select PARTITION or SUBPARTITION
  -- Returns the target unit selector clause used in dynamic DDL.
  FUNCTION fn_partition_for_clause
  (
    p_target_owner              IN VARCHAR2,
    p_target_table              IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2,
    p_subpartition_high_value   IN VARCHAR2,
    p_archive_unit_type         IN VARCHAR2
  )
  RETURN VARCHAR2;

  -- Creates an exchange staging table matching the target table structure.
  -- Parameters:
  -- p_target_owner       schema owning the archive target
  -- p_target_table       archive target table name
  -- p_staging_table_name receives the generated staging table name
  -- p_execute            Y creates the table; N previews the operation
  -- p_log_id             optional process log identifier
  -- p_tablespace_name    tablespace for the staging table
  PROCEDURE prc_create_exchange_staging
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_staging_table_name OUT VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_tablespace_name    IN VARCHAR2
  );

  -- Loads one source partition's rows into its exchange staging table.
  -- Parameters:
  -- p_source_db_link     database link to the source database
  -- p_source_owner       schema owning the source table
  -- p_source_table       source table name
  -- p_target_owner       schema owning the archive target
  -- p_target_table       archive target table name
  -- p_staging_table_name staging table to load
  -- p_high_value         source partition HIGH_VALUE expression
  -- p_prev_high_value    previous partition HIGH_VALUE for RANGE selection
  -- p_execute            Y loads the data; N previews the operation
  -- p_log_id             optional process log identifier
  -- p_parallel_degree    parallel DML degree
  -- p_rows_loaded        receives the number of rows loaded
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
    p_parallel_degree    IN NUMBER DEFAULT 4,
    p_rows_loaded        OUT NUMBER
  );

  -- Loads one source subpartition's rows into its exchange staging table.
  -- Parameters:
  -- p_source_db_link              database link to the source database
  -- p_source_owner                schema owning the source table
  -- p_source_table                source table name
  -- p_target_owner                schema owning the archive target
  -- p_target_table                archive target table name
  -- p_staging_table_name          staging table to load
  -- p_partition_high_value        parent partition HIGH_VALUE expression
  -- p_prev_partition_high_value   previous parent partition HIGH_VALUE for RANGE selection
  -- p_subpartition_high_value     subpartition HIGH_VALUE expression
  -- p_execute                     Y loads the data; N previews the operation
  -- p_log_id                      optional process log identifier
  -- p_parallel_degree             parallel DML degree
  -- p_rows_loaded                 receives the number of rows loaded
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
    p_parallel_degree        IN NUMBER DEFAULT 4,
    p_rows_loaded            OUT NUMBER
  );

  -- Creates or rebuilds indexes on an exchange staging table.
  -- Parameters:
  -- p_target_owner       schema owning the archive target and its indexes
  -- p_target_table       archive target table whose indexes are mirrored
  -- p_staging_table_name staging table to index
  -- p_execute            Y creates indexes; N previews the operation
  -- p_log_id             optional process log identifier
  -- p_parallel_degree    parallel index-build degree
  -- p_tablespace_name    tablespace for the staging indexes
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

  -- Exchanges a staging table with the target partition selected by HIGH_VALUE.
  -- Parameters:
  -- p_target_owner              schema owning the archive target
  -- p_target_table              archive target table name
  -- p_partition_high_value      partition HIGH_VALUE expression
  -- p_prev_partition_high_value previous partition HIGH_VALUE for RANGE selection
  -- p_staging_table_name        staging table to exchange
  -- p_execute                   Y exchanges the partition; N previews the DDL
  -- p_log_id                    optional process log identifier
  PROCEDURE prc_exchange_partition
  (
    p_target_owner              IN VARCHAR2,
    p_target_table              IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2,
    p_staging_table_name        IN VARCHAR2,
    p_execute                   IN VARCHAR2 DEFAULT 'Y',
    p_log_id                    IN NUMBER DEFAULT NULL
  );

  -- Exchanges a staging table with the target subpartition selected by HIGH_VALUE.
  -- Parameters:
  -- p_target_owner              schema owning the archive target
  -- p_target_table              archive target table name
  -- p_partition_high_value      parent partition HIGH_VALUE expression
  -- p_prev_partition_high_value previous parent partition HIGH_VALUE for RANGE selection
  -- p_subpartition_high_value   subpartition HIGH_VALUE expression
  -- p_staging_table_name        staging table to exchange
  -- p_execute                   Y exchanges the subpartition; N previews the DDL
  -- p_log_id                    optional process log identifier
  PROCEDURE prc_exchange_subpartition
  (
    p_target_owner              IN VARCHAR2,
    p_target_table              IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2,
    p_subpartition_high_value   IN VARCHAR2,
    p_staging_table_name        IN VARCHAR2,
    p_execute                   IN VARCHAR2 DEFAULT 'Y',
    p_log_id                    IN NUMBER DEFAULT NULL
  );

  -- Drops an exchange staging table.
  -- Parameters:
  -- p_staging_owner      schema owning the staging table
  -- p_staging_table_name staging table name
  -- p_execute            Y drops the table; N previews the operation
  -- p_log_id             optional process log identifier
  PROCEDURE prc_drop_staging
  (
    p_staging_owner      IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  );

  -- Removes staging tables left behind beyond the configured retention period.
  -- Parameters:
  -- p_retention_days minimum age in days before an orphan staging table is removed
  -- p_execute        Y drops eligible tables; N previews the cleanup
  -- p_log_id         optional process log identifier
  PROCEDURE prc_cleanup_orphan_staging
  (
    p_retention_days IN NUMBER DEFAULT 30,
    p_execute        IN VARCHAR2 DEFAULT 'N',
    p_log_id         IN NUMBER DEFAULT NULL
  );
END PKG_ARCHIVER_PARTITION;
/
