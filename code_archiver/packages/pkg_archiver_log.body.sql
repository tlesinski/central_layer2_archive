CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVER_LOG
AS
  /*
    Package      : PKG_ARCHIVER_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_ARCHIVER_TL_LOGGING, TBL_ARCHIVER_RUNS, SEQ_ARCHIVER_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    NOTE-first in fn_summary_row, fn_summary_cell added
  */
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_create_run
  (
    p_run_type       IN VARCHAR2,
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  RETURN NUMBER
  IS
    l_run_id       NUMBER;
    l_log_id       NUMBER;
    l_run_type     VARCHAR2(30);
    l_execute_flag VARCHAR2(1);
  BEGIN
    l_run_type := UPPER(TRIM(p_run_type));
    l_execute_flag := fn_normalize_execute(p_execute);
    l_log_id := SEQ_ARCHIVER_PROCESS_LOG.NEXTVAL;

    INSERT INTO TBL_ARCHIVER_RUNS
      (RUN_TYPE, RUN_STATUS, SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, MSTR_LOG_ID, EXECUTE_FLAG)
    VALUES
      (l_run_type, 'RUNNING', UPPER(p_source_db_link), UPPER(p_source_owner), UPPER(p_source_table), l_log_id, l_execute_flag)
    RETURNING RUN_ID INTO l_run_id;

    RETURN l_run_id;
  END fn_create_run;

  FUNCTION fn_get_log_id
  (
    p_run_id IN NUMBER
  )
  RETURN NUMBER
  IS
    l_log_id NUMBER;
  BEGIN
    SELECT MSTR_LOG_ID
      INTO l_log_id
      FROM TBL_ARCHIVER_RUNS
     WHERE RUN_ID = p_run_id;

    RETURN l_log_id;
  END fn_get_log_id;

  PROCEDURE prc_log_message
  (
    p_run_id    IN NUMBER,
    p_log_msg   IN CLOB,
    p_log_type  IN VARCHAR2 DEFAULT 'TEXT',
    p_log_sttus IN VARCHAR2 DEFAULT PKG_ARCHIVER_TL_LOGGING.g_sttus_running_const
  )
  IS
    l_log_id NUMBER;
    l_log_msg CLOB := p_log_msg;
  BEGIN
    IF p_run_id IS NULL THEN
      RETURN;
    END IF;

    l_log_id := fn_get_log_id(p_run_id);

    IF UPPER(TRIM(p_log_type)) = 'SUMMARY' THEN
      l_log_msg := TO_CLOB('<<<PARTMGR_SUMMARY_BEGIN>>>') || CHR(10) ||
                   p_log_msg || CHR(10) ||
                   TO_CLOB('<<<PARTMGR_SUMMARY_END>>>');
    END IF;

    PKG_ARCHIVER_TL_LOGGING.prc_log
    (
      p_log_id      => l_log_id,
      p_mstr_log_id => l_log_id,
      p_log_msg     => l_log_msg,
      p_log_sttus   => p_log_sttus,
      p_log_type    => p_log_type
    );
  END prc_log_message;

  PROCEDURE prc_log_error_stack
  (
    p_run_id IN NUMBER
  )
  IS
    l_log_id NUMBER;
  BEGIN
    IF p_run_id IS NULL THEN
      RETURN;
    END IF;

    l_log_id := fn_get_log_id(p_run_id);
    PKG_ARCHIVER_TL_LOGGING.prc_error_stack
    (
      p_log_id      => l_log_id,
      p_mstr_log_id => l_log_id
    );
  END prc_log_error_stack;

  FUNCTION fn_sanitize_summary_cell
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF p_value IS NULL OR p_value = '#' THEN
      RETURN '-';
    END IF;

    RETURN REPLACE(REPLACE(REPLACE(TRIM(p_value), CHR(13), ' '), CHR(10), ' '), '|', '/');
  END fn_sanitize_summary_cell;

  FUNCTION fn_summary_cell
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN fn_sanitize_summary_cell(p_value);
  END fn_summary_cell;

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
   RETURN CLOB
   IS
   BEGIN
     RETURN fn_sanitize_summary_cell(p_note) || '|' ||
            fn_sanitize_summary_cell(p_source_db_link) || '|' ||
            fn_sanitize_summary_cell(p_table_owner) || '|' ||
            fn_sanitize_summary_cell(p_table_name) || '|' ||
            fn_sanitize_summary_cell(p_partition_name) || '|' ||
            fn_sanitize_summary_cell(p_subpartition_name) || '|' ||
            fn_sanitize_summary_cell(p_partition_high_value) || '|' ||
            fn_sanitize_summary_cell(p_subpartition_high_value) || '|' ||
            fn_sanitize_summary_cell(p_archive_status) || '|' ||
            fn_sanitize_summary_cell(p_quality_status) || '|' ||
            fn_sanitize_summary_cell(p_truncate_status) || '|' ||
            fn_sanitize_summary_cell(TO_CHAR(p_source_row_count)) || '|' ||
            fn_sanitize_summary_cell(TO_CHAR(p_target_row_count)) || CHR(10);
   END fn_summary_row;

  PROCEDURE prc_log_summary
  (
    p_run_id        IN NUMBER,
    p_process_name  IN VARCHAR2,
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_max_col_width IN NUMBER DEFAULT 120
  )
  IS
    l_msg CLOB;
  BEGIN
    IF p_rows IS NULL THEN
      RETURN;
    END IF;

    l_msg := 'SUMMARY:' || CHR(10) ||
             'Process : ' || NVL(p_process_name, '-') || CHR(10) || CHR(10) ||
             PKG_ARCHIVER_SQL.fn_format_table
             (
               p_columns       => p_columns,
               p_rows          => p_rows,
               p_null_text     => '-',
               p_max_col_width => p_max_col_width,
               p_box_style     => 'SIMPLE'
             );

    prc_log_message
    (
      p_run_id   => p_run_id,
      p_log_msg  => l_msg,
      p_log_type => 'SUMMARY'
    );
  END prc_log_summary;

  PROCEDURE prc_finish_run
  (
    p_run_id        IN NUMBER,
    p_status        IN VARCHAR2,
    p_error_message IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_log_id   NUMBER;
    l_run_type TBL_ARCHIVER_RUNS.RUN_TYPE%TYPE;
  BEGIN
    SELECT MSTR_LOG_ID, RUN_TYPE
      INTO l_log_id, l_run_type
      FROM TBL_ARCHIVER_RUNS
     WHERE RUN_ID = p_run_id;

    UPDATE TBL_ARCHIVER_RUNS
       SET RUN_STATUS = p_status,
           ENDED_AT = SYSTIMESTAMP,
           ERROR_MESSAGE = SUBSTR(p_error_message, 1, 4000),
           UPDATED_AT = SYSTIMESTAMP
     WHERE RUN_ID = p_run_id;

    PKG_ARCHIVER_TL_LOGGING.prc_log
    (
      p_log_id          => l_log_id,
      p_mstr_log_id     => l_log_id,
      p_log_categ       => l_run_type,
      p_mstr_fun        => 'PKG_ARCHIVER_' || l_run_type,
      p_log_sttus       => p_status,
      p_end_date        => SYSDATE,
      p_last_err_code   => CASE WHEN p_status = 'ERROR' THEN TO_CHAR(SQLCODE) END,
      p_last_err_desc   => CASE WHEN p_status = 'ERROR' THEN SUBSTR(p_error_message, 1, 256) END,
      p_log_type        => CASE WHEN p_status = 'ERROR' THEN 'ERROR' ELSE 'TEXT' END,
      p_log_msg         => 'Finished ' || l_run_type || ' with status ' || p_status ||
                           CASE WHEN p_error_message IS NOT NULL THEN ': ' || SUBSTR(p_error_message, 1, 3000) END
    );
  END prc_finish_run;
END PKG_ARCHIVER_LOG;
/
