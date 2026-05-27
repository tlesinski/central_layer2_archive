CREATE OR REPLACE PACKAGE PKG_ARCHIVE_QUALITY
AS
  PROCEDURE check_table
  (
    p_source_db_link IN VARCHAR2,
    p_owner          IN VARCHAR2,
    p_table_name     IN VARCHAR2,
    p_execute        IN VARCHAR2 DEFAULT 'N'
  );

  PROCEDURE check_all
  (
    p_execute IN VARCHAR2 DEFAULT 'N'
  );
END PKG_ARCHIVE_QUALITY;
/

