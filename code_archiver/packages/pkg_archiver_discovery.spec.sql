CREATE OR REPLACE PACKAGE PKG_ARCHIVER_DISCOVERY
AS
  /*
    Package      : PKG_ARCHIVER_DISCOVERY
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Discover source partitions - add missing target partitions,
                   insert partition metadata into TBL_ARCHIVER_PARTITIONS

    Prerequisite : PKG_ARCHIVER_SQL, PKG_ARCHIVER_LOG, VW_ARCHIVER_DISCOVERY_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
  */
  -- Validates source and target table setup and their partition key definitions.
  -- Parameters:
  -- p_source_db_link      database link to the source database
  -- p_source_owner        schema owning the source table
  -- p_source_table_name   source table name
  -- p_target_owner        schema owning the archive target
  -- p_target_table_name   archive target table name
  -- p_partition_method    configured partition method: RANGE or LIST
  -- p_subpartition_method configured subpartition method, when used
  PROCEDURE prc_validate_table_setup
  (
    p_source_db_link      IN VARCHAR2,
    p_source_owner        IN VARCHAR2,
    p_source_table_name   IN VARCHAR2,
    p_target_owner        IN VARCHAR2,
    p_target_table_name   IN VARCHAR2,
    p_partition_method    IN VARCHAR2,
    p_subpartition_method IN VARCHAR2
  );

  -- Discovers source units, creates missing target partitions, and records metadata.
  -- Parameters:
  -- p_execute           Y applies DDL and metadata changes; N previews the work
  -- p_target_owner      optionally limits discovery to this target schema
  -- p_target_table_name optionally limits discovery to this target table
  PROCEDURE prc_discover
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_DISCOVERY;
/
