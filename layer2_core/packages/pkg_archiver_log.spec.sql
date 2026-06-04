CREATE OR REPLACE PACKAGE PKG_ARCHIVER_LOG
AS
  /*
    Package      : PKG_ARCHIVER_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_ARCHIVER_TL_LOGGING, TBL_ARCHIVER_RUNS, ARCHIVER_PROCESS_LOG_SEQ

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    NOTE-first in fn_summary_row, fn_summary_cell added
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
    p_log_sttus IN VARCHAR2 DEFAULT PKG_ARCHIVER_TL_LOGGING.g_sttus_running_const
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

  PROCEDURE prc_log_summary
  (
    p_run_id        IN NUMBER,
    p_process_name  IN VARCHAR2,
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_max_col_width IN NUMBER DEFAULT 120
  );

  PROCEDURE prc_finish_run
  (
    p_run_id        IN NUMBER,
    p_status        IN VARCHAR2,
    p_error_message IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_LOG;
/
