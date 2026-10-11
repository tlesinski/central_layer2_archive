CREATE OR REPLACE PACKAGE PKG_REPLICA_RUNNER
AS
  /*
    Package      : PKG_REPLICA_RUNNER
    Purpose      : Orchestrate REPLICA discovery, replication, quality, and purge.

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-10-11   Tomasz Lesinski    Add package change history
  */
  -- Runs configured REPLICA steps in DISCOVER, REPLICATE, QUALITY, PURGE order.
  -- Parameters:
  -- p_execute           Y executes DISCOVER/REPLICATE/QUALITY; N previews them
  -- p_stop_after_step   optional last non-purge step to run
  -- p_purge_execute     Y executes eligible purges after quality succeeds
  -- p_target_owner      optionally limits the run to this target schema
  -- p_target_table_name optionally limits the run to this target table
  PROCEDURE prc_run
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step   IN VARCHAR2 DEFAULT NULL,
    p_purge_execute     IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_RUNNER;
/
