CREATE OR REPLACE PACKAGE PKG_REPLICA_LOG
AS
  /*
    Package      : PKG_REPLICA_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Replica process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_REPLICA_LOGGING, TBL_REPLICA_RUNS, SEQ_REPLICA_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  -- Creates a replication process run record and returns its run identifier.
  -- Parameters:
  -- p_run_type       process type, such as DISCOVER or REPLICATE
  -- p_source_db_link database link identifying the ARCHIVER database
  -- p_source_owner   schema owning the ARCHIVER source table
  -- p_source_table   ARCHIVER source table name
  -- p_execute        execution mode recorded for the run
  -- Returns the created run identifier.
  FUNCTION fn_create_run
  (
    p_run_type       IN VARCHAR2,
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  RETURN NUMBER;

  -- Returns the process log identifier associated with a run.
  -- Parameters:
  -- p_run_id run identifier
  -- Returns the corresponding log identifier.
  FUNCTION fn_get_log_id
  (
    p_run_id IN NUMBER
  )
  RETURN NUMBER;

  -- Writes a message and status to the process log for a run.
  -- Parameters:
  -- p_run_id    run identifier
  -- p_log_msg   message text
  -- p_log_type  message format/type
  -- p_log_sttus process status for this log message
  PROCEDURE prc_log_message
  (
    p_run_id    IN NUMBER,
    p_log_msg   IN CLOB,
    p_log_type  IN VARCHAR2 DEFAULT 'TEXT',
    p_log_sttus IN VARCHAR2 DEFAULT PKG_REPLICA_LOGGING.g_sttus_running_const
  );

  -- Writes source and target table context for a process step.
  -- Parameters:
  -- p_run_id            run identifier
  -- p_process_name      process step name
  -- p_source_db_link    database link identifying the ARCHIVER database
  -- p_source_owner      schema owning the ARCHIVER source table
  -- p_source_table_name ARCHIVER source table name
  -- p_target_owner      schema owning the REPLICA target
  -- p_target_table_name REPLICA target table name
  PROCEDURE prc_log_table_context
  (
    p_run_id            IN NUMBER,
    p_process_name      IN VARCHAR2,
    p_source_db_link    IN VARCHAR2,
    p_source_owner      IN VARCHAR2,
    p_source_table_name IN VARCHAR2,
    p_target_owner      IN VARCHAR2,
    p_target_table_name IN VARCHAR2
  );

  -- Adds the current Oracle error stack and backtrace to the run log.
  -- Parameters:
  -- p_run_id run identifier
  PROCEDURE prc_log_error_stack
  (
    p_run_id IN NUMBER
  );

  -- Escapes a value for inclusion in a formatted process summary.
  -- Parameters:
  -- p_value value to format
  -- Returns the safe formatted cell value.
  FUNCTION fn_summary_cell
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2;

  -- Finishes a process run and records its final status and optional error.
  -- Parameters:
  -- p_run_id        run identifier
  -- p_status        final process status
  -- p_error_message optional error description
  PROCEDURE prc_finish_run
  (
    p_run_id        IN NUMBER,
    p_status        IN VARCHAR2,
    p_error_message IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_LOG;
/
