CREATE OR REPLACE PACKAGE PKG_ARCHIVER_IMPORT
AS
  /*
    Package      : PKG_ARCHIVER_IMPORT
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Import source partitions into target archive via EXCHANGE

    Prerequisite : PKG_ARCHIVER_SQL, PKG_ARCHIVER_LOG, PKG_ARCHIVER_PARTITION,
                   VW_ARCHIVER_IMPORT_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-28   Tomasz Lesinski    Add PARALLEL_DEGREE support,
                                                ALTER SESSION ENABLE PARALLEL DML,
                                                process summary logging
     1.2        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
     1.3        2026-10-11   Tomasz Lesinski    Exchange archive units by
                                                HIGH_VALUE, not physical names
  */
  -- Loads eligible source units into staging and exchanges them into archive targets.
  -- Parameters:
  -- p_execute           Y executes imports; N previews them
  -- p_target_owner      optionally limits import to this target schema
  -- p_target_table_name optionally limits import to this target table
  PROCEDURE prc_import
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_IMPORT;
/
