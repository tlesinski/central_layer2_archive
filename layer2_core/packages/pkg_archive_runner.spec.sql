CREATE OR REPLACE PACKAGE PKG_ARCHIVE_RUNNER
AS
  /*
    Package      : PKG_ARCHIVE_RUNNER
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive runner - orchestrates DISCOVER -> ARCHIVE -> QUALITY
                   -> TRUNCATE flow for one or all tables

    Prerequisite : PKG_ARCHIVE_DISCOVERY, PKG_ARCHIVE_IMPORT, PKG_ARCHIVE_QUALITY,
                   PKG_ARCHIVE_TRUNCATE, PKG_ARCHIVE_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  PROCEDURE prc_run_table
  (
    p_source_db_link  IN VARCHAR2,
    p_owner           IN VARCHAR2,
    p_table_name      IN VARCHAR2,
    p_execute         IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step IN VARCHAR2 DEFAULT 'QUALITY',
    p_truncate_execute IN VARCHAR2 DEFAULT 'N'
  );

  PROCEDURE prc_run_all
  (
    p_execute         IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step IN VARCHAR2 DEFAULT 'QUALITY',
    p_truncate_execute IN VARCHAR2 DEFAULT 'N'
  );
END PKG_ARCHIVE_RUNNER;
/
