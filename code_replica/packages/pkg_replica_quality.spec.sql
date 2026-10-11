CREATE OR REPLACE PACKAGE PKG_REPLICA_QUALITY
AS
  /*
    Package      : PKG_REPLICA_QUALITY
    Purpose      : Compare ARCHIVER source counts with REPLICA target counts.

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-06-01   Tomasz Lesinski    Initial version
    1.1        2026-10-11   Tomasz Lesinski    Count target units using
                                                HIGH_VALUE-based FOR selectors
  */
  -- Compares ARCHIVER and REPLICA row counts and updates quality status.
  -- Parameters:
  -- p_execute           Y persists quality results; N previews the checks
  -- p_target_owner      optionally limits quality checks to this target schema
  -- p_target_table_name optionally limits quality checks to this target table
  PROCEDURE prc_quality
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_QUALITY;
/
