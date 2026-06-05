CREATE OR REPLACE PACKAGE PKG_REPLICA_LOG
AS
  /*
    Package      : PKG_REPLICA_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Replica process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_REPLICA_TL_LOGGING, TBL_REPLICA_RUNS, SEQ_REPLICA_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_create_run
  (
    p_run_type       IN VARCHAR2,
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  RETURN NUMBER;

  FUNCTION fn_get_log_id
  (
    p_run_id IN NUMBER
  )
  RETURN NUMBER;

  PROCEDURE prc_log_message
  (
    p_run_id    IN NUMBER,
    p_log_msg   IN CLOB,
    p_log_type  IN VARCHAR2 DEFAULT 'TEXT',
    p_log_sttus IN VARCHAR2 DEFAULT PKG_REPLICA_TL_LOGGING.g_sttus_running_const
  );

  PROCEDURE prc_log_error_stack
  (
    p_run_id IN NUMBER
  );

  FUNCTION fn_summary_cell
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2;

  PROCEDURE prc_finish_run
  (
    p_run_id        IN NUMBER,
    p_status        IN VARCHAR2,
    p_error_message IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_LOG;
/
