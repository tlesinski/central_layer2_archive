CREATE OR REPLACE PACKAGE BODY PKG_UTIL_REPORT
AS
  FUNCTION fn_get_config
  (
    p_config_key IN VARCHAR2,
    p_default    IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2
  IS
    l_value TBL_UTIL_CONFIG.CONFIG_VALUE%TYPE;
  BEGIN
    SELECT CONFIG_VALUE
      INTO l_value
      FROM TBL_UTIL_CONFIG
     WHERE CONFIG_KEY = UPPER(TRIM(p_config_key));

    RETURN NVL(l_value, p_default);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN p_default;
  END fn_get_config;

  FUNCTION fn_html_escape
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN REPLACE(
             REPLACE(
               REPLACE(
                 REPLACE(NVL(p_value, ''), '&', '&amp;'),
                 '<',
                 '&lt;'
               ),
               '>',
               '&gt;'
             ),
             '"',
             '&quot;'
           );
  END fn_html_escape;

  FUNCTION fn_assert_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_name)));
  END fn_assert_name;

  FUNCTION fn_enquote_column
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN '"' || REPLACE(p_name, '"', '""') || '"';
  END fn_enquote_column;

  FUNCTION fn_transform_sql_html
  (
    p_sql IN CLOB
  )
  RETURN CLOB
  IS
    l_cur         PLS_INTEGER;
    l_col_cnt     PLS_INTEGER;
    l_desc_tab    DBMS_SQL.DESC_TAB2;
    l_header_sql  VARCHAR2(32767);
    l_row_sql     VARCHAR2(32767);
    l_result      CLOB;
    l_row_html    VARCHAR2(32767);
    l_rows        PLS_INTEGER := 0;
    l_max_rows    PLS_INTEGER := TO_NUMBER(fn_get_config('REPORT_MAX_ROWS', '100'));
    l_rc          SYS_REFCURSOR;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_result, TRUE);

    l_cur := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(l_cur, DBMS_LOB.SUBSTR(p_sql, 32767, 1), DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS2(l_cur, l_col_cnt, l_desc_tab);
    DBMS_SQL.CLOSE_CURSOR(l_cur);

    l_header_sql := 'SELECT ''<tr>';
    l_row_sql := 'SELECT ''<tr>''';

    FOR i IN 1 .. l_col_cnt LOOP
      l_header_sql := l_header_sql ||
                      '<th>' || fn_html_escape(l_desc_tab(i).COL_NAME) || '</th>';
      l_row_sql := l_row_sql ||
                   ' || ''<td>'' || PKG_UTIL_REPORT.fn_html_escape(TO_CHAR(' ||
                   fn_enquote_column(l_desc_tab(i).COL_NAME) ||
                   ')) || ''</td>''';
    END LOOP;

    l_header_sql := l_header_sql || '</tr>'' FROM dual';
    l_row_sql := l_row_sql || ' || ''</tr>'' FROM (' || DBMS_LOB.SUBSTR(p_sql, 32767, 1) || ')';

    DBMS_LOB.APPEND(l_result, TO_CLOB('<table>'));

    EXECUTE IMMEDIATE l_header_sql INTO l_row_html;
    DBMS_LOB.APPEND(l_result, TO_CLOB(l_row_html));

    OPEN l_rc FOR l_row_sql;
    LOOP
      FETCH l_rc INTO l_row_html;
      EXIT WHEN l_rc%NOTFOUND OR l_rows >= l_max_rows;
      DBMS_LOB.APPEND(l_result, TO_CLOB(l_row_html));
      l_rows := l_rows + 1;
    END LOOP;
    CLOSE l_rc;

    DBMS_LOB.APPEND(l_result, TO_CLOB('</table>'));
    RETURN l_result;
  EXCEPTION
    WHEN OTHERS THEN
      IF DBMS_SQL.IS_OPEN(l_cur) THEN
        DBMS_SQL.CLOSE_CURSOR(l_cur);
      END IF;

      IF l_rc%ISOPEN THEN
        CLOSE l_rc;
      END IF;

      RAISE;
  END fn_transform_sql_html;

  FUNCTION fn_report_html
  (
    p_report_name IN VARCHAR2,
    p_parm1       IN VARCHAR2 DEFAULT NULL,
    p_parm2       IN VARCHAR2 DEFAULT NULL,
    p_parm3       IN VARCHAR2 DEFAULT NULL
  )
  RETURN CLOB
  IS
    l_report      CLOB;
    l_scan        VARCHAR2(32767);
    l_sql_name    VARCHAR2(128);
    l_sql_code    CLOB;
    l_sql_html    CLOB;
    l_tag         VARCHAR2(4000);
    l_tag_count   PLS_INTEGER;
    l_report_name VARCHAR2(128);
    l_safe_sql_name VARCHAR2(128);
  BEGIN
    l_report_name := fn_assert_name(p_report_name);

    SELECT REPORT_HTML
      INTO l_report
      FROM TBL_UTIL_REPORTS
     WHERE REPORT_NAME = l_report_name;

    l_report := REPLACE(l_report, '<PARM1>', NVL(p_parm1, TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')));
    l_report := REPLACE(l_report, '<PARM2>', NVL(p_parm2, ''));
    l_report := REPLACE(l_report, '<PARM3>', NVL(p_parm3, ''));

    l_scan := DBMS_LOB.SUBSTR(l_report, 32767, 1);
    l_tag_count := REGEXP_COUNT(l_scan, '<SQL>([^<]+)</SQL>', 1, 'i');

    FOR i IN 1 .. l_tag_count LOOP
      l_sql_name := REGEXP_SUBSTR(l_scan, '<SQL>([^<]+)</SQL>', 1, i, 'i', 1);
      l_tag := '<SQL>' || l_sql_name || '</SQL>';
      l_safe_sql_name := fn_assert_name(l_sql_name);

      SELECT SQL_CODE
        INTO l_sql_code
        FROM TBL_UTIL_REPORT_SQL
       WHERE SQL_NAME = l_safe_sql_name;

      l_sql_html := fn_transform_sql_html(l_sql_code);
      l_report := REPLACE(l_report, l_tag, DBMS_LOB.SUBSTR(l_sql_html, 32767, 1));
    END LOOP;

    RETURN l_report;
  END fn_report_html;
END PKG_UTIL_REPORT;
/
