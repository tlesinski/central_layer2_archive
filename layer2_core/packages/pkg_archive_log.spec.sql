CREATE OR REPLACE PACKAGE PKG_ARCHIVE_LOG
AS
  FUNCTION create_run
  (
    p_run_type       IN VARCHAR2,
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  RETURN NUMBER;

  FUNCTION get_log_id
  (
    p_run_id IN NUMBER
  )
  RETURN NUMBER;

  PROCEDURE log_message
  (
    p_run_id    IN NUMBER,
    p_log_msg   IN CLOB,
    p_log_type  IN VARCHAR2 DEFAULT 'TEXT',
    p_log_sttus IN VARCHAR2 DEFAULT PKG_TL_LOGGING.g_sttus_running_const
  );

  PROCEDURE finish_run
  (
    p_run_id        IN NUMBER,
    p_status        IN VARCHAR2,
    p_error_message IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVE_LOG;
/
