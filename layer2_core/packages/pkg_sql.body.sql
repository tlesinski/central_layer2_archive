CREATE OR REPLACE PACKAGE BODY PKG_SQL
AS
  /*
    Package      : PKG_SQL
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : SQL helper package - name validation, dynamic SQL execution,
                   bind variable handling, SQL logging

    Prerequisite : PKG_TL_LOGGING, MD_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_normalize_execute
  (
    p_execute IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN
      RETURN 'Y';
    END IF;

    RETURN 'N';
  END fn_normalize_execute;

  FUNCTION fn_format_sql_for_log
  (
    p_sql IN CLOB
  )
  RETURN CLOB
  IS
    l_sql CLOB;
  BEGIN
    IF p_sql IS NULL THEN
      RETURN NULL;
    END IF;

    l_sql := REGEXP_REPLACE(p_sql, '[[:space:]]+', ' ');
    l_sql := TRIM(l_sql);

    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(SELECT[[:space:]])', CHR(10) || 'SELECT ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(FROM[[:space:]])', CHR(10) || 'FROM ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(WHERE[[:space:]])', CHR(10) || 'WHERE ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(AND[[:space:]])', CHR(10) || '  AND ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(OR[[:space:]])', CHR(10) || '  OR ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(WHEN[[:space:]])', CHR(10) || 'WHEN ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(VALUES[[:space:]])', CHR(10) || 'VALUES ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(PARTITION[[:space:]])', CHR(10) || 'PARTITION ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(SUBPARTITION[[:space:]])', CHR(10) || 'SUBPARTITION ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(FOR[[:space:]]+EXCHANGE[[:space:]])', CHR(10) || 'FOR EXCHANGE ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(WITH[[:space:]]+TABLE[[:space:]])', CHR(10) || 'WITH TABLE ', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(INCLUDING[[:space:]]+INDEXES)', CHR(10) || 'INCLUDING INDEXES', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(EXCLUDING[[:space:]]+INDEXES)', CHR(10) || 'EXCLUDING INDEXES', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(WITHOUT[[:space:]]+VALIDATION)', CHR(10) || 'WITHOUT VALIDATION', 1, 0, 'i');
    l_sql := REGEXP_REPLACE(l_sql, '[[:space:]]+(UPDATE[[:space:]]+GLOBAL[[:space:]]+INDEXES)', CHR(10) || 'UPDATE GLOBAL INDEXES', 1, 0, 'i');

    RETURN l_sql;
  END fn_format_sql_for_log;

  PROCEDURE prc_log_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2
  )
  IS
    l_log_sql CLOB;
  BEGIN
    IF p_log_id IS NOT NULL THEN
      l_log_sql := fn_format_sql_for_log(p_sql);

      PKG_TL_LOGGING.prc_log
      (
        p_log_id    => p_log_id,
        p_log_msg   => CASE fn_normalize_execute(p_execute)
                         WHEN 'Y' THEN TO_CLOB('Executing SQL:') || CHR(10)
                         ELSE TO_CLOB('Preview SQL:') || CHR(10)
                       END || l_log_sql,
        p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
        p_log_type  => 'SQL'
      );
    END IF;
  END prc_log_sql;

  FUNCTION fn_assert_simple_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_name)));
  END fn_assert_simple_name;

  FUNCTION fn_assert_qualified_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN DBMS_ASSERT.QUALIFIED_SQL_NAME(UPPER(TRIM(p_name)));
  END fn_assert_qualified_name;

  FUNCTION fn_run_into_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER
  IS
    l_result NUMBER;
    l_sql    VARCHAR2(32767);
  BEGIN
    IF p_sql IS NULL THEN
      raise_application_error(-20001, 'SQL text is required');
    END IF;

    prc_log_sql(p_log_id => p_log_id, p_sql => p_sql, p_execute => p_execute);

    IF fn_normalize_execute(p_execute) = 'N' THEN
      RETURN NULL;
    END IF;

    l_sql := DBMS_LOB.SUBSTR(p_sql, 32767, 1);
    EXECUTE IMMEDIATE l_sql INTO l_result;

    RETURN l_result;
  END fn_run_into_sql;

  FUNCTION fn_run_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER
  IS
    l_sql VARCHAR2(32767);
  BEGIN
    IF p_sql IS NULL THEN
      raise_application_error(-20001, 'SQL text is required');
    END IF;

    prc_log_sql(p_log_id => p_log_id, p_sql => p_sql, p_execute => p_execute);

    IF fn_normalize_execute(p_execute) = 'N' THEN
      RETURN 0;
    END IF;

    l_sql := DBMS_LOB.SUBSTR(p_sql, 32767, 1);
    EXECUTE IMMEDIATE l_sql;

    RETURN SQL%ROWCOUNT;
  END fn_run_sql;

  FUNCTION fn_run_sql_in_bind
  (
    p_log_id     IN NUMBER,
    p_sql        IN CLOB,
    p_array_bind IN SYS.ODCIVARCHAR2LIST,
    p_execute    IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER
  IS
    l_cursor_id INTEGER;
    l_rows      INTEGER;
    l_attempt   NUMBER := 0;
  BEGIN
    IF p_sql IS NULL THEN
      raise_application_error(-20001, 'SQL text is required');
    END IF;

    prc_log_sql(p_log_id => p_log_id, p_sql => p_sql, p_execute => p_execute);

    IF p_log_id IS NOT NULL AND p_array_bind IS NOT NULL THEN
      PKG_TL_LOGGING.prc_log
      (
        p_log_id    => p_log_id,
        p_log_msg   => 'Bind count: ' || p_array_bind.COUNT,
        p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
        p_log_type  => 'SQL_BIND'
      );

      FOR i IN 1 .. p_array_bind.COUNT LOOP
        PKG_TL_LOGGING.prc_log
        (
          p_log_id    => p_log_id,
          p_log_msg   => 'Bind ' || i || ': ' || NVL(p_array_bind(i), '<NULL>'),
          p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
          p_log_type  => 'SQL_BIND'
        );
      END LOOP;
    END IF;

    IF fn_normalize_execute(p_execute) = 'N' THEN
      RETURN 0;
    END IF;

    LOOP
      l_attempt := l_attempt + 1;

      BEGIN
        l_cursor_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor_id, p_sql, DBMS_SQL.NATIVE);

        IF p_array_bind IS NOT NULL THEN
          FOR i IN 1 .. p_array_bind.COUNT LOOP
            DBMS_SQL.BIND_VARIABLE(l_cursor_id, ':' || i, p_array_bind(i));
          END LOOP;
        END IF;

        l_rows := DBMS_SQL.EXECUTE(l_cursor_id);
        DBMS_SQL.CLOSE_CURSOR(l_cursor_id);

        RETURN l_rows;
      EXCEPTION
        WHEN OTHERS THEN
          IF DBMS_SQL.IS_OPEN(l_cursor_id) THEN
            DBMS_SQL.CLOSE_CURSOR(l_cursor_id);
          END IF;

          IF SQLCODE IN (-4061, -4062, -4068) AND l_attempt = 1 THEN
            IF p_log_id IS NOT NULL THEN
              PKG_TL_LOGGING.prc_log
              (
                p_log_id    => p_log_id,
                p_log_msg   => 'Retrying SQL after remote package state changed: ' || SQLERRM,
                p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
                p_log_type  => 'SQL_RETRY'
              );
            END IF;
          ELSE
            RAISE;
          END IF;
      END;
    END LOOP;
  END fn_run_sql_in_bind;

  FUNCTION fn_run_into_sql_in_bind
  (
    p_log_id     IN NUMBER,
    p_sql        IN CLOB,
    p_array_bind IN SYS.ODCIVARCHAR2LIST,
    p_execute    IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER
  IS
    l_cursor_id INTEGER;
    l_rows      INTEGER;
    l_result    NUMBER;
    l_attempt   NUMBER := 0;
  BEGIN
    IF p_sql IS NULL THEN
      raise_application_error(-20001, 'SQL text is required');
    END IF;

    prc_log_sql(p_log_id => p_log_id, p_sql => p_sql, p_execute => p_execute);

    IF p_log_id IS NOT NULL AND p_array_bind IS NOT NULL THEN
      PKG_TL_LOGGING.prc_log
      (
        p_log_id    => p_log_id,
        p_log_msg   => 'Bind count: ' || p_array_bind.COUNT,
        p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
        p_log_type  => 'SQL_BIND'
      );

      FOR i IN 1 .. p_array_bind.COUNT LOOP
        PKG_TL_LOGGING.prc_log
        (
          p_log_id    => p_log_id,
          p_log_msg   => 'Bind ' || i || ': ' || NVL(p_array_bind(i), '<NULL>'),
          p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
          p_log_type  => 'SQL_BIND'
        );
      END LOOP;
    END IF;

    IF fn_normalize_execute(p_execute) = 'N' THEN
      RETURN NULL;
    END IF;

    LOOP
      l_attempt := l_attempt + 1;

      BEGIN
        l_cursor_id := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(l_cursor_id, p_sql, DBMS_SQL.NATIVE);

        IF p_array_bind IS NOT NULL THEN
          FOR i IN 1 .. p_array_bind.COUNT LOOP
            DBMS_SQL.BIND_VARIABLE(l_cursor_id, ':' || i, p_array_bind(i));
          END LOOP;
        END IF;

        DBMS_SQL.DEFINE_COLUMN(l_cursor_id, 1, l_result);
        l_rows := DBMS_SQL.EXECUTE(l_cursor_id);

        IF DBMS_SQL.FETCH_ROWS(l_cursor_id) > 0 THEN
          DBMS_SQL.COLUMN_VALUE(l_cursor_id, 1, l_result);
        END IF;

        DBMS_SQL.CLOSE_CURSOR(l_cursor_id);

        RETURN l_result;
      EXCEPTION
        WHEN OTHERS THEN
          IF DBMS_SQL.IS_OPEN(l_cursor_id) THEN
            DBMS_SQL.CLOSE_CURSOR(l_cursor_id);
          END IF;

          IF SQLCODE IN (-4061, -4062, -4068) AND l_attempt = 1 THEN
            IF p_log_id IS NOT NULL THEN
              PKG_TL_LOGGING.prc_log
              (
                p_log_id    => p_log_id,
                p_log_msg   => 'Retrying SQL after remote package state changed: ' || SQLERRM,
                p_log_sttus => PKG_TL_LOGGING.g_sttus_running_const,
                p_log_type  => 'SQL_RETRY'
              );
            END IF;
          ELSE
            RAISE;
          END IF;
      END;
    END LOOP;
  END fn_run_into_sql_in_bind;

  FUNCTION fn_col_count
  (
    p_line IN VARCHAR2,
    p_sep  IN VARCHAR2 DEFAULT '|'
  )
  RETURN PLS_INTEGER
  IS
    l_count PLS_INTEGER := 1;
    l_pos   PLS_INTEGER := 0;
  BEGIN
    IF p_line IS NULL THEN
      RETURN 0;
    END IF;

    LOOP
      l_pos := INSTR(p_line, p_sep, l_pos + 1);
      EXIT WHEN l_pos = 0;
      l_count := l_count + 1;
    END LOOP;

    RETURN l_count;
  END fn_col_count;

  FUNCTION fn_col_value
  (
    p_line   IN VARCHAR2,
    p_col_no IN PLS_INTEGER,
    p_sep    IN VARCHAR2 DEFAULT '|'
  )
  RETURN VARCHAR2
  IS
    l_text      VARCHAR2(32767) := p_line;
    l_start_pos PLS_INTEGER := 1;
    l_end_pos   PLS_INTEGER;
  BEGIN
    FOR i IN 1 .. p_col_no LOOP
      l_end_pos := INSTR(l_text, p_sep, l_start_pos);

      IF i = p_col_no THEN
        IF l_end_pos = 0 THEN
          RETURN SUBSTR(l_text, l_start_pos);
        ELSE
          RETURN SUBSTR(l_text, l_start_pos, l_end_pos - l_start_pos);
        END IF;
      END IF;

      IF l_end_pos = 0 THEN
        RETURN NULL;
      END IF;

      l_start_pos := l_end_pos + 1;
    END LOOP;

    RETURN NULL;
  END fn_col_value;

  FUNCTION fn_next_line
  (
    p_clob IN CLOB,
    p_pos  IN OUT PLS_INTEGER
  )
  RETURN VARCHAR2
  IS
    l_end_pos PLS_INTEGER;
    l_line    VARCHAR2(32767);
  BEGIN
    IF p_clob IS NULL OR p_pos > DBMS_LOB.GETLENGTH(p_clob) THEN
      RETURN NULL;
    END IF;

    l_end_pos := DBMS_LOB.INSTR(p_clob, CHR(10), p_pos);

    IF l_end_pos = 0 THEN
      l_line := DBMS_LOB.SUBSTR(p_clob, 32767, p_pos);
      p_pos := DBMS_LOB.GETLENGTH(p_clob) + 1;
    ELSE
      l_line := DBMS_LOB.SUBSTR(p_clob, l_end_pos - p_pos, p_pos);
      p_pos := l_end_pos + 1;
    END IF;

    RETURN l_line;
  END fn_next_line;

  FUNCTION fn_sanitize
  (
    p_value    IN VARCHAR2,
    p_null_text IN VARCHAR2 DEFAULT '-',
    p_sep      IN VARCHAR2 DEFAULT '|'
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF p_value IS NULL OR TRIM(p_value) IS NULL THEN
      RETURN p_null_text;
    END IF;

    RETURN REPLACE(REPLACE(REPLACE(TRIM(p_value), CHR(13), ' '), CHR(10), ' '), p_sep, ' ');
  END fn_sanitize;

  FUNCTION fn_format_table
  (
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_col_align     IN VARCHAR2 DEFAULT NULL,
    p_separator     IN VARCHAR2 DEFAULT '|',
    p_null_text     IN VARCHAR2 DEFAULT '-',
    p_max_col_width IN NUMBER   DEFAULT 120,
    p_box_style     IN VARCHAR2 DEFAULT 'SIMPLE'
  )
  RETURN CLOB
  IS
    TYPE t_widths IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

    l_widths       t_widths;
    l_col_count    PLS_INTEGER;
    l_max_width    PLS_INTEGER := LEAST(GREATEST(NVL(p_max_col_width, 120), 8), 300);
    l_pos          PLS_INTEGER;
    l_line         VARCHAR2(32767);
    l_value        VARCHAR2(32767);
    l_sanitized    VARCHAR2(32767);
    l_result       CLOB;
    l_rows_count   NUMBER := 0;
    l_box          VARCHAR2(20);
    l_is_right     BOOLEAN;
  BEGIN
    l_box := UPPER(NVL(TRIM(p_box_style), 'SIMPLE'));

    IF l_box NOT IN ('NONE', 'SIMPLE') THEN
      l_box := 'SIMPLE';
    END IF;

    l_col_count := fn_col_count(p_columns, p_separator);

    IF l_col_count = 0 THEN
      RETURN 'FORMAT_TABLE: no columns' || CHR(10);
    END IF;

    -- pass 1: measure max widths per column
    FOR i IN 1 .. l_col_count LOOP
      l_value := fn_col_value(p_columns, i, p_separator);
      l_widths(i) := LEAST(GREATEST(LENGTH(NVL(l_value, '-')), 1), l_max_width);
    END LOOP;

    l_pos := 1;

    LOOP
      l_line := fn_next_line(p_rows, l_pos);
      EXIT WHEN l_line IS NULL;
      CONTINUE WHEN TRIM(l_line) IS NULL;

      l_rows_count := l_rows_count + 1;

      FOR i IN 1 .. l_col_count LOOP
        l_value := fn_col_value(l_line, i, p_separator);
        l_sanitized := fn_sanitize(l_value, p_null_text, p_separator);
        l_widths(i) := LEAST(GREATEST(l_widths(i), LENGTH(l_sanitized)), l_max_width);
      END LOOP;
    END LOOP;

    -- pass 2: build output
    l_result := 'FORMAT_TABLE:' || CHR(10);
    l_result := l_result || 'Columns : ' || l_col_count || CHR(10);
    l_result := l_result || 'Rows    : ' || l_rows_count || CHR(10) || CHR(10);

    -- header + top border
    IF l_box = 'SIMPLE' THEN
      l_result := l_result || '+';
      FOR i IN 1 .. l_col_count LOOP
        l_result := l_result || RPAD('-', l_widths(i) + 2, '-') || '+';
      END LOOP;
      l_result := l_result || CHR(10) || '|';

      FOR i IN 1 .. l_col_count LOOP
        l_value := fn_col_value(p_columns, i, p_separator);
        l_result := l_result || ' ' || RPAD(NVL(l_value, '-'), l_widths(i)) || ' |';
      END LOOP;

      l_result := l_result || CHR(10) || '+';
      FOR i IN 1 .. l_col_count LOOP
        l_result := l_result || RPAD('-', l_widths(i) + 2, '-') || '+';
      END LOOP;
      l_result := l_result || CHR(10);
    ELSE
      FOR i IN 1 .. l_col_count LOOP
        l_value := fn_col_value(p_columns, i, p_separator);
        l_result := l_result || RPAD(NVL(l_value, '-'), l_widths(i));
        l_result := l_result || CASE WHEN i < l_col_count THEN '  ' END;
      END LOOP;

      l_result := l_result || CHR(10);

      FOR i IN 1 .. l_col_count LOOP
        l_result := l_result || RPAD('-', l_widths(i), '-');
        l_result := l_result || CASE WHEN i < l_col_count THEN '  ' END;
      END LOOP;

      l_result := l_result || CHR(10);
    END IF;

    -- data rows
    l_pos := 1;

    LOOP
      l_line := fn_next_line(p_rows, l_pos);
      EXIT WHEN l_line IS NULL;
      CONTINUE WHEN TRIM(l_line) IS NULL;

      IF l_box = 'SIMPLE' THEN
        l_result := l_result || '|';
      END IF;

      FOR i IN 1 .. l_col_count LOOP
        l_value := fn_col_value(l_line, i, p_separator);
        l_sanitized := fn_sanitize(l_value, p_null_text, p_separator);
        l_is_right := p_col_align IS NOT NULL AND LENGTH(p_col_align) >= i AND SUBSTR(p_col_align, i, 1) = '>';

        IF l_box = 'SIMPLE' THEN
          l_result := l_result || ' ' ||
            CASE WHEN l_is_right THEN LPAD(l_sanitized, l_widths(i)) ELSE RPAD(l_sanitized, l_widths(i)) END ||
            ' |';
        ELSE
          l_result := l_result ||
            CASE WHEN l_is_right THEN LPAD(l_sanitized, l_widths(i)) ELSE RPAD(l_sanitized, l_widths(i)) END;
          l_result := l_result || CASE WHEN i < l_col_count THEN '  ' END;
        END IF;
      END LOOP;

      l_result := l_result || CHR(10);
    END LOOP;

    -- bottom border
    IF l_box = 'SIMPLE' AND l_rows_count > 0 THEN
      l_result := l_result || '+';
      FOR i IN 1 .. l_col_count LOOP
        l_result := l_result || RPAD('-', l_widths(i) + 2, '-') || '+';
      END LOOP;
      l_result := l_result || CHR(10);
    END IF;

    RETURN l_result;
  END fn_format_table;
END PKG_SQL;
/
