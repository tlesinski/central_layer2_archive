CREATE OR REPLACE PACKAGE PKG_REPLICA_REPLICATE
AS
  /*
    Package      : PKG_REPLICA_REPLICATE
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Replicate ARCHIVER units selected by REPLICATE_EXPRESSION.

    Prerequisite : PKG_REPLICA_SQL, PKG_REPLICA_LOG, VW_REPLICA_REPLICATE_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  PROCEDURE prc_replicate
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_REPLICATE;
/
