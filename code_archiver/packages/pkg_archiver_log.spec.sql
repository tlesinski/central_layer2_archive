CREATE OR REPLACE PACKAGE PKG_ARCHIVER_LOG
AS
  /*
    Package      : PKG_ARCHIVER_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_ARCHIVER_LOGGING, TBL_ARCHIVER_RUNS, SEQ_ARCHIVER_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    NOTE-first in fn_summary_row, fn_summary_cell added
  */
  -- Creates a process run record and returns its run identifier.
  -- Parameters:
  -- p_run_type       process type, such as DISCOVER or IMPORT
  -- p_source_db_link database link identifying the source database
  -- p_source_owner   schema owning the source table
  -- p_source_table   source table name
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
    p_log_sttus IN VARCHAR2 DEFAULT PKG_ARCHIVER_LOGGING.g_sttus_running_const
  );

  -- Writes source and target table context for a process step.
  -- Parameters:
  -- p_run_id            run identifier
  -- p_process_name      process step name
  -- p_source_db_link    database link identifying the source database
  -- p_source_owner      schema owning the source table
  -- p_source_table_name source table name
  -- p_target_owner      schema owning the archive target
  -- p_target_table_name archive target table name
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

   -- Formats one source/archive unit as a row in a process summary.
   -- Parameters:
   -- p_note                    optional note displayed with this row
   -- p_source_db_link          database link identifying the source database
   -- p_table_owner             source table schema
   -- p_table_name              source table name
   -- p_partition_name          physical partition name for display
   -- p_subpartition_name       physical subpartition name for display
   -- p_partition_high_value    partition HIGH_VALUE expression
   -- p_subpartition_high_value subpartition HIGH_VALUE expression, when applicable
   -- p_archive_status          archive status to display
   -- p_quality_status          quality status to display
   -- p_truncate_status         source cleanup status to display
   -- p_source_row_count        optional source row count
   -- p_target_row_count        optional archive row count
   -- Returns the formatted summary row as a CLOB.
   FUNCTION fn_summary_row
   (
     p_note                    IN VARCHAR2 DEFAULT NULL,
     p_source_db_link          IN VARCHAR2,
     p_table_owner             IN VARCHAR2,
     p_table_name              IN VARCHAR2,
     p_partition_name          IN VARCHAR2,
     p_subpartition_name       IN VARCHAR2,
     p_partition_high_value    IN VARCHAR2,
     p_subpartition_high_value IN VARCHAR2,
     p_archive_status          IN VARCHAR2,
     p_quality_status          IN VARCHAR2,
     p_truncate_status         IN VARCHAR2,
     p_source_row_count        IN NUMBER DEFAULT NULL,
     p_target_row_count        IN NUMBER DEFAULT NULL
   )
   RETURN CLOB;

  -- Logs a formatted tabular summary for a process step.
  -- Parameters:
  -- p_run_id        run identifier
  -- p_process_name  process step name
  -- p_columns       delimited column headings
  -- p_rows          formatted summary rows
  -- p_max_col_width maximum rendered column width
  PROCEDURE prc_log_summary
  (
    p_run_id        IN NUMBER,
    p_process_name  IN VARCHAR2,
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_max_col_width IN NUMBER DEFAULT 120
  );

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
END PKG_ARCHIVER_LOG;
/
