CREATE OR REPLACE PACKAGE BODY PKG_SQL
AS
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

      RAISE;
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

      RAISE;
  END fn_run_into_sql_in_bind;
END PKG_SQL;
/
