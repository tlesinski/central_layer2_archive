CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_LOG
AS
  /*
    Package      : PKG_ARCHIVE_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_TL_LOGGING, TW_ARCHIVE_RUNS, MD_PROCESS_LOG_SEQ

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
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
    l_log_id := MD_PROCESS_LOG_SEQ.NEXTVAL;

    INSERT INTO TW_ARCHIVE_RUNS
      (RUN_TYPE, RUN_STATUS, SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, MSTR_LOG_ID, EXECUTE_FLAG)
    VALUES
      (l_run_type, 'RUNNING', UPPER(p_source_db_link), UPPER(p_source_owner), UPPER(p_source_table), l_log_id, l_execute_flag)
    RETURNING RUN_ID INTO l_run_id;

    PKG_TL_LOGGING.prc_log
    (
      p_log_id      => l_log_id,
      p_mstr_log_id => l_log_id,
      p_log_categ   => l_run_type,
      p_mstr_fun    => 'PKG_ARCHIVE_' || l_run_type,
      p_log_sttus   => PKG_TL_LOGGING.g_sttus_running_const,
      p_start_date  => SYSDATE,
      p_log_msg     => 'Started ' || l_run_type || ' for ' ||
                       UPPER(p_source_db_link) || '.' ||
                       UPPER(p_source_owner) || '.' ||
                       UPPER(p_source_table) ||
                       ', execute=' || l_execute_flag
    );

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
      FROM TW_ARCHIVE_RUNS
     WHERE RUN_ID = p_run_id;

    RETURN l_log_id;
  END fn_get_log_id;

  PROCEDURE prc_log_message
  (
    p_run_id    IN NUMBER,
    p_log_msg   IN CLOB,
    p_log_type  IN VARCHAR2 DEFAULT 'TEXT',
    p_log_sttus IN VARCHAR2 DEFAULT PKG_TL_LOGGING.g_sttus_running_const
  )
  IS
    l_log_id NUMBER;
  BEGIN
    IF p_run_id IS NULL THEN
      RETURN;
    END IF;

    l_log_id := fn_get_log_id(p_run_id);

    PKG_TL_LOGGING.prc_log
    (
      p_log_id      => l_log_id,
      p_mstr_log_id => l_log_id,
      p_log_msg     => p_log_msg,
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
    PKG_TL_LOGGING.prc_error_stack
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
    p_target_row_count        IN NUMBER DEFAULT NULL,
    p_note                    IN VARCHAR2 DEFAULT NULL
  )
  RETURN CLOB
  IS
  BEGIN
    RETURN fn_sanitize_summary_cell(p_table_owner) || '|' ||
           fn_sanitize_summary_cell(p_table_name) || '|' ||
           fn_sanitize_summary_cell(p_partition_name) || '|' ||
           fn_sanitize_summary_cell(p_subpartition_name) || '|' ||
           fn_sanitize_summary_cell(p_partition_high_value) || '|' ||
           fn_sanitize_summary_cell(p_subpartition_high_value) || '|' ||
           fn_sanitize_summary_cell(p_archive_status) || '|' ||
           fn_sanitize_summary_cell(p_quality_status) || '|' ||
           fn_sanitize_summary_cell(p_truncate_status) || '|' ||
           fn_sanitize_summary_cell(TO_CHAR(p_source_row_count)) || '|' ||
           fn_sanitize_summary_cell(TO_CHAR(p_target_row_count)) || '|' ||
           fn_sanitize_summary_cell(p_note) || CHR(10);
  END fn_summary_row;

  FUNCTION fn_summary_col_count
  (
    p_columns IN VARCHAR2
  )
  RETURN PLS_INTEGER
  IS
    l_count PLS_INTEGER := 1;
    l_pos   PLS_INTEGER := 0;
  BEGIN
    IF p_columns IS NULL THEN
      RETURN 0;
    END IF;

    LOOP
      l_pos := INSTR(p_columns, '|', l_pos + 1);
      EXIT WHEN l_pos = 0;
      l_count := l_count + 1;
    END LOOP;

    RETURN l_count;
  END fn_summary_col_count;

  FUNCTION fn_summary_col_value
  (
    p_line   IN VARCHAR2,
    p_col_no IN PLS_INTEGER
  )
  RETURN VARCHAR2
  IS
    l_text       VARCHAR2(32767) := p_line || '|';
    l_start_pos  PLS_INTEGER := 1;
    l_end_pos    PLS_INTEGER;
  BEGIN
    FOR i IN 1 .. p_col_no LOOP
      l_end_pos := INSTR(l_text, '|', l_start_pos);

      IF l_end_pos = 0 THEN
        RETURN NULL;
      END IF;

      IF i = p_col_no THEN
        RETURN SUBSTR(l_text, l_start_pos, l_end_pos - l_start_pos);
      END IF;

      l_start_pos := l_end_pos + 1;
    END LOOP;

    RETURN NULL;
  END fn_summary_col_value;

  FUNCTION fn_summary_next_line
  (
    p_rows IN CLOB,
    p_pos  IN OUT PLS_INTEGER
  )
  RETURN VARCHAR2
  IS
    l_end_pos PLS_INTEGER;
    l_line    VARCHAR2(32767);
  BEGIN
    IF p_rows IS NULL OR p_pos > DBMS_LOB.GETLENGTH(p_rows) THEN
      RETURN NULL;
    END IF;

    l_end_pos := DBMS_LOB.INSTR(p_rows, CHR(10), p_pos);

    IF l_end_pos = 0 THEN
      l_line := DBMS_LOB.SUBSTR(p_rows, 32767, p_pos);
      p_pos := DBMS_LOB.GETLENGTH(p_rows) + 1;
    ELSE
      l_line := DBMS_LOB.SUBSTR(p_rows, l_end_pos - p_pos, p_pos);
      p_pos := l_end_pos + 1;
    END IF;

    RETURN l_line;
  END fn_summary_next_line;

  FUNCTION fn_summary_fit
  (
    p_value IN VARCHAR2,
    p_width IN PLS_INTEGER
  )
  RETURN VARCHAR2
  IS
    l_value VARCHAR2(32767) := NVL(p_value, '-');
  BEGIN
    IF LENGTH(l_value) > p_width THEN
      IF p_width <= 3 THEN
        l_value := SUBSTR(l_value, 1, p_width);
      ELSE
        l_value := SUBSTR(l_value, 1, p_width - 3) || '...';
      END IF;
    END IF;

    RETURN RPAD(l_value, p_width);
  END fn_summary_fit;

  FUNCTION fn_render_summary
  (
    p_process_name  IN VARCHAR2,
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_max_col_width IN NUMBER DEFAULT 120
  )
  RETURN CLOB
  IS
    TYPE t_widths IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

    l_widths       t_widths;
    l_col_count    PLS_INTEGER;
    l_max_width    PLS_INTEGER := LEAST(GREATEST(NVL(p_max_col_width, 120), 20), 300);
    l_pos          PLS_INTEGER;
    l_line         VARCHAR2(32767);
    l_value        VARCHAR2(32767);
    l_result       CLOB;
    l_rows_count   NUMBER := 0;
    l_xml          CLOB;
  BEGIN
    l_col_count := fn_summary_col_count(p_columns);

    IF l_col_count = 0 THEN
      RETURN 'SUMMARY:' || CHR(10) ||
             'Process : ' || NVL(p_process_name, '-') || CHR(10) ||
             'Rows    : 0' || CHR(10);
    END IF;

    l_xml := '<summary><header>';

    FOR i IN 1 .. l_col_count LOOP
      l_value := fn_summary_col_value(p_columns, i);
      l_widths(i) := LEAST(GREATEST(LENGTH(NVL(l_value, '-')), 1), l_max_width);
      l_xml := l_xml || '<column>' || DBMS_XMLGEN.CONVERT(NVL(l_value, '-'), DBMS_XMLGEN.ENTITY_ENCODE) || '</column>';
    END LOOP;

    l_xml := l_xml || '</header><rows>';
    l_pos := 1;

    LOOP
      l_line := fn_summary_next_line(p_rows, l_pos);
      EXIT WHEN l_line IS NULL;
      CONTINUE WHEN TRIM(l_line) IS NULL;

      l_rows_count := l_rows_count + 1;
      l_xml := l_xml || '<row>';

      FOR i IN 1 .. l_col_count LOOP
        l_value := fn_summary_col_value(l_line, i);
        l_widths(i) := LEAST(GREATEST(l_widths(i), LENGTH(NVL(l_value, '-'))), l_max_width);
        l_xml := l_xml || '<column>' || DBMS_XMLGEN.CONVERT(NVL(l_value, '-'), DBMS_XMLGEN.ENTITY_ENCODE) || '</column>';
      END LOOP;

      l_xml := l_xml || '</row>';
    END LOOP;

    l_xml := l_xml || '</rows></summary>';

    l_result := 'SUMMARY:' || CHR(10) ||
                'Process : ' || NVL(p_process_name, '-') || CHR(10) ||
                'Rows    : ' || l_rows_count || CHR(10) || CHR(10);

    FOR i IN 1 .. l_col_count LOOP
      l_result := l_result || fn_summary_fit(fn_summary_col_value(p_columns, i), l_widths(i)) ||
                  CASE WHEN i < l_col_count THEN '  ' END;
    END LOOP;

    l_result := l_result || CHR(10);

    FOR i IN 1 .. l_col_count LOOP
      l_result := l_result || RPAD('-', l_widths(i), '-') ||
                  CASE WHEN i < l_col_count THEN '  ' END;
    END LOOP;

    l_result := l_result || CHR(10);
    l_pos := 1;

    LOOP
      l_line := fn_summary_next_line(p_rows, l_pos);
      EXIT WHEN l_line IS NULL;
      CONTINUE WHEN TRIM(l_line) IS NULL;

      FOR i IN 1 .. l_col_count LOOP
        l_result := l_result || fn_summary_fit(fn_summary_col_value(l_line, i), l_widths(i)) ||
                    CASE WHEN i < l_col_count THEN '  ' END;
      END LOOP;

      l_result := l_result || CHR(10);
    END LOOP;

    RETURN l_result;
  END fn_render_summary;

  PROCEDURE prc_log_summary
  (
    p_run_id        IN NUMBER,
    p_process_name  IN VARCHAR2,
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_max_col_width IN NUMBER DEFAULT 120
  )
  IS
  BEGIN
    IF p_rows IS NULL THEN
      RETURN;
    END IF;

    prc_log_message
    (
      p_run_id   => p_run_id,
      p_log_msg  => fn_render_summary(p_process_name, p_columns, p_rows, p_max_col_width),
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
    l_run_type TW_ARCHIVE_RUNS.RUN_TYPE%TYPE;
  BEGIN
    SELECT MSTR_LOG_ID, RUN_TYPE
      INTO l_log_id, l_run_type
      FROM TW_ARCHIVE_RUNS
     WHERE RUN_ID = p_run_id;

    UPDATE TW_ARCHIVE_RUNS
       SET RUN_STATUS = p_status,
           ENDED_AT = SYSTIMESTAMP,
           ERROR_MESSAGE = SUBSTR(p_error_message, 1, 4000),
           UPDATED_AT = SYSTIMESTAMP
     WHERE RUN_ID = p_run_id;

    PKG_TL_LOGGING.prc_log
    (
      p_log_id          => l_log_id,
      p_mstr_log_id     => l_log_id,
      p_log_categ       => l_run_type,
      p_mstr_fun        => 'PKG_ARCHIVE_' || l_run_type,
      p_log_sttus       => p_status,
      p_end_date        => SYSDATE,
      p_last_err_code   => CASE WHEN p_status = 'ERROR' THEN TO_CHAR(SQLCODE) END,
      p_last_err_desc   => CASE WHEN p_status = 'ERROR' THEN SUBSTR(p_error_message, 1, 256) END,
      p_log_type        => CASE WHEN p_status = 'ERROR' THEN 'ERROR' ELSE 'TEXT' END,
      p_log_msg         => 'Finished ' || l_run_type || ' with status ' || p_status ||
                           CASE WHEN p_error_message IS NOT NULL THEN ': ' || SUBSTR(p_error_message, 1, 3000) END
    );
  END prc_finish_run;
END PKG_ARCHIVE_LOG;
/
