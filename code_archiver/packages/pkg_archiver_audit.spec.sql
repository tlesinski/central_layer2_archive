CREATE OR REPLACE PACKAGE PKG_ARCHIVER_AUDIT
AS
  /*
    Package      : PKG_ARCHIVER_AUDIT
    Purpose      : Non-blocking, historical validation of archived row counts.
    Prerequisite : PKG_ARCHIVER_LOG, PKG_ARCHIVER_PARTITION,
                   VW_ARCHIVER_SOFT_VALIDATION
  */
  PROCEDURE prc_soft_count
  (
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_AUDIT;
/
