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
  PROCEDURE prc_discover
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_DISCOVERY;
/
