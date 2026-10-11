CREATE OR REPLACE PACKAGE PKG_REPLICA_DISCOVERY
AS
  /*
    Package      : PKG_REPLICA_DISCOVERY
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Discover layer 2 archive partitions for layer 3 replica -
                   add missing target partitions and insert metadata into
                   TBL_REPLICA_PARTITIONS

    Prerequisite : PKG_REPLICA_SQL, PKG_REPLICA_LOG, VW_REPLICA_DISCOVERY_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  -- Validates ARCHIVER source and REPLICA target table setup and partition keys.
  -- Parameters:
  -- p_source_db_link      database link to the ARCHIVER database
  -- p_source_owner        schema owning the ARCHIVER source table
  -- p_source_table_name   ARCHIVER source table name
  -- p_target_owner        schema owning the REPLICA target
  -- p_target_table_name   REPLICA target table name
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

  -- Discovers ARCHIVER units, creates missing REPLICA partitions, and records metadata.
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
END PKG_REPLICA_DISCOVERY;
/
