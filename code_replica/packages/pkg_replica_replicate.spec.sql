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
     1.1        2026-10-11   Tomasz Lesinski    Exchange replica units by
                                                HIGH_VALUE, not physical names
  */
  -- Loads eligible ARCHIVER units into REPLICA targets through staging and exchange.
  -- Parameters:
  -- p_execute           Y executes replication; N previews it
  -- p_target_owner      optionally limits replication to this target schema
  -- p_target_table_name optionally limits replication to this target table
  PROCEDURE prc_replicate
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_REPLICATE;
/
