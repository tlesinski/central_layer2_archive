CREATE OR REPLACE PACKAGE PKG_ARCHIVER_RUNNER
AS
  /*
    Package      : PKG_ARCHIVER_RUNNER
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive runner - orchestrates DISCOVER -> ARCHIVE -> QUALITY
                   -> TRUNCATE flow for one or all tables

    Prerequisite : PKG_ARCHIVER_DISCOVERY, PKG_ARCHIVER_IMPORT, PKG_ARCHIVER_QUALITY,
                   PKG_ARCHIVER_TRUNCATE, PKG_ARCHIVER_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  -- Runs configured archive steps for one source table in pipeline order.
  -- Parameters:
  -- p_source_db_link   database link identifying the source database
  -- p_owner            schema owning the source table
  -- p_table_name       source table name
  -- p_execute          Y executes DISCOVER/ARCHIVE/QUALITY; N previews them
  -- p_stop_after_step  last non-destructive step to run (default QUALITY)
  -- p_truncate_execute Y executes eligible source cleanup after quality succeeds
  PROCEDURE prc_run_table
  (
    p_source_db_link  IN VARCHAR2,
    p_owner           IN VARCHAR2,
    p_table_name      IN VARCHAR2,
    p_execute         IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step IN VARCHAR2 DEFAULT 'QUALITY',
    p_truncate_execute IN VARCHAR2 DEFAULT 'N'
  );

  -- Runs the archive pipeline for all configured source tables.
  -- Parameters:
  -- p_execute          Y executes DISCOVER/ARCHIVE/QUALITY; N previews them
  -- p_stop_after_step  last non-destructive step to run (default QUALITY)
  -- p_truncate_execute Y executes eligible source cleanup after quality succeeds
  PROCEDURE prc_run_all
  (
    p_execute         IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step IN VARCHAR2 DEFAULT 'QUALITY',
    p_truncate_execute IN VARCHAR2 DEFAULT 'N'
  );
END PKG_ARCHIVER_RUNNER;
/
