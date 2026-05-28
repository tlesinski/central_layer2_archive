CREATE OR REPLACE PACKAGE PKG_ARCHIVE_RUNNER
AS
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
