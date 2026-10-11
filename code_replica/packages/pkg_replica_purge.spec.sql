CREATE OR REPLACE PACKAGE PKG_REPLICA_PURGE
AS
  /*
    Package      : PKG_REPLICA_PURGE
    Purpose      : Purge local REPLICA units no longer selected for replication.

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-06-01   Tomasz Lesinski    Initial version
    1.1        2026-10-11   Tomasz Lesinski    Truncate target units using
                                                HIGH_VALUE-based FOR selectors
  */
  -- Identifies local units no longer selected for replication and optionally purges them.
  -- Parameters:
  -- p_execute           Y purges eligible units; N previews the operations
  -- p_target_owner      optionally limits purge to this target schema
  -- p_target_table_name optionally limits purge to this target table
  PROCEDURE prc_purge
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_PURGE;
/
