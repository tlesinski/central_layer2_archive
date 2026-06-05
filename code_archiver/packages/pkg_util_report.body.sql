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

  FUNCTION fn_html_escape_clob
  (
    p_value IN CLOB
  )
  RETURN CLOB
  IS
  BEGIN
    RETURN REPLACE(
             REPLACE(
               REPLACE(
                 REPLACE(NVL(p_value, TO_CLOB('')), '&', '&amp;'),
                 '<',
                 '&lt;'
               ),
               '>',
               '&gt;'
             ),
             '"',
             '&quot;'
           );
  END fn_html_escape_clob;

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
    l_header_html VARCHAR2(32767);
    l_row_html    CLOB;
    l_rows        PLS_INTEGER := 0;
    l_max_rows    PLS_INTEGER := TO_NUMBER(fn_get_config('REPORT_MAX_ROWS', '100'));
    l_rc          SYS_REFCURSOR;
    l_summary_col PLS_INTEGER := 0;
    l_display_cols PLS_INTEGER := 0;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_result, TRUE);

    l_cur := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(l_cur, DBMS_LOB.SUBSTR(p_sql, 32767, 1), DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS2(l_cur, l_col_cnt, l_desc_tab);
    DBMS_SQL.CLOSE_CURSOR(l_cur);

    l_header_sql := 'SELECT ''<tr>';
    l_row_sql := 'SELECT TO_CLOB(''<tr>'')';

    FOR i IN 1 .. l_col_cnt LOOP
      IF UPPER(l_desc_tab(i).COL_NAME) = 'SUMMARY_TEXT' THEN
        l_summary_col := i;
      ELSE
        l_display_cols := l_display_cols + 1;
        l_header_sql := l_header_sql ||
                        '<th>' || fn_html_escape(l_desc_tab(i).COL_NAME) || '</th>';
        l_row_sql := l_row_sql ||
                     ' || ''<td>'' || PKG_UTIL_REPORT.fn_html_escape(TO_CHAR(' ||
                     fn_enquote_column(l_desc_tab(i).COL_NAME) ||
                     ')) || ''</td>''';
      END IF;
    END LOOP;

    l_header_sql := l_header_sql || '</tr>'' FROM dual';
    IF l_summary_col > 0 THEN
      l_row_sql := l_row_sql ||
                   ' || ''</tr><tr><td colspan="' || TO_CHAR(l_display_cols) ||
                   '" class="log-text">'' || PKG_UTIL_REPORT.fn_html_escape_clob(' ||
                   fn_enquote_column(l_desc_tab(l_summary_col).COL_NAME) ||
                   ') || ''</td>''';
    END IF;

    l_row_sql := l_row_sql || ' || ''</tr>'' FROM (' || DBMS_LOB.SUBSTR(p_sql, 32767, 1) || ')';

    DBMS_LOB.APPEND(l_result, TO_CLOB('<table>'));

    EXECUTE IMMEDIATE l_header_sql INTO l_header_html;
    DBMS_LOB.APPEND(l_result, TO_CLOB(l_header_html));

    OPEN l_rc FOR l_row_sql;
    LOOP
      FETCH l_rc INTO l_row_html;
      EXIT WHEN l_rc%NOTFOUND OR l_rows >= l_max_rows;
      DBMS_LOB.APPEND(l_result, l_row_html);
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

  FUNCTION fn_latest_summary_html
  (
    p_component IN VARCHAR2,
    p_process   IN VARCHAR2
  )
  RETURN CLOB
  IS
    l_component VARCHAR2(30) := UPPER(TRIM(p_component));
    l_process   VARCHAR2(30) := UPPER(TRIM(p_process));
    l_table     VARCHAR2(128);
    l_sql       VARCHAR2(32767);
    l_log_sttus VARCHAR2(30);
    l_start_date DATE;
    l_end_date DATE;
    l_log_id NUMBER;
    l_begin_pos PLS_INTEGER;
    l_end_pos PLS_INTEGER;
    l_log_msg CLOB;
    l_summary CLOB;
    l_html CLOB;
    l_amount PLS_INTEGER;
  BEGIN
    IF l_component = 'ARCHIVER' THEN
      IF l_process NOT IN ('DISCOVER', 'ARCHIVE', 'QUALITY', 'TRUNCATE', 'RUNNER') THEN
        RAISE_APPLICATION_ERROR(-20750, 'Invalid ARCHIVER process: ' || p_process);
      END IF;
      l_table := 'TBL_ARCHIVER_PROCESS_LOG';
    ELSIF l_component = 'REPLICA' THEN
      IF l_process NOT IN ('DISCOVER', 'REPLICATE', 'QUALITY', 'PURGE', 'RUNNER') THEN
        RAISE_APPLICATION_ERROR(-20751, 'Invalid REPLICA process: ' || p_process);
      END IF;
      l_table := 'TBL_REPLICA_PROCESS_LOG';
    ELSE
      RAISE_APPLICATION_ERROR(-20752, 'Invalid component: ' || p_component);
    END IF;

    l_sql :=
      'SELECT log_sttus, start_date, end_date, log_id, ' ||
      '       DBMS_LOB.INSTR(log_msg, ''<<<PARTMGR_SUMMARY_BEGIN>>>'') begin_pos, ' ||
      '       DBMS_LOB.INSTR(log_msg, ''<<<PARTMGR_SUMMARY_END>>>'') end_pos, ' ||
      '       log_msg ' ||
      '  FROM (SELECT log_sttus, start_date, end_date, log_id, log_msg ' ||
      '          FROM ' || l_table ||
      '         WHERE log_categ = :process ' ||
      '           AND DBMS_LOB.INSTR(log_msg, ''<<<PARTMGR_SUMMARY_BEGIN>>>'') > 0 ' ||
      '           AND DBMS_LOB.INSTR(log_msg, ''<<<PARTMGR_SUMMARY_END>>>'') > 0 ' ||
      '         ORDER BY start_date DESC, log_id DESC) ' ||
      ' WHERE ROWNUM = 1';

    EXECUTE IMMEDIATE l_sql
      INTO l_log_sttus, l_start_date, l_end_date, l_log_id, l_begin_pos, l_end_pos, l_log_msg
      USING l_process;

    DBMS_LOB.CREATETEMPORARY(l_summary, TRUE);
    l_amount := GREATEST(0, l_end_pos - (l_begin_pos + LENGTH('<<<PARTMGR_SUMMARY_BEGIN>>>')));

    IF l_amount > 0 THEN
      DBMS_LOB.COPY(
        dest_lob    => l_summary,
        src_lob     => l_log_msg,
        amount      => l_amount,
        dest_offset => 1,
        src_offset  => l_begin_pos + LENGTH('<<<PARTMGR_SUMMARY_BEGIN>>>')
      );
    END IF;

    l_summary := REGEXP_REPLACE(l_summary, '^[[:space:]]+|[[:space:]]+$', '');

    l_html := TO_CLOB('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>') ||
              fn_html_escape(l_component || ' ' || l_process || ' summary') ||
              TO_CLOB('</title><style>body{font-family:Arial,sans-serif;font-size:13px;color:#1f2933;}') ||
              TO_CLOB('table{border-collapse:collapse;margin:10px 0 16px;}th,td{border:1px solid #c7d0d9;padding:6px 8px;text-align:left;}') ||
              TO_CLOB('th{background:#eef2f6;}pre{white-space:pre-wrap;font-family:Consolas,"Courier New",monospace;font-size:12px;line-height:1.45;background:#f8fafc;border:1px solid #c7d0d9;padding:10px;}') ||
              TO_CLOB('</style></head><body><h1>') ||
              fn_html_escape(l_component || ' ' || l_process || ' summary') ||
              TO_CLOB('</h1><table><tr><th>Component</th><th>Process</th><th>Status</th><th>Started</th><th>Ended</th><th>Log ID</th></tr><tr><td>') ||
              fn_html_escape(l_component) || TO_CLOB('</td><td>') ||
              fn_html_escape(l_process) || TO_CLOB('</td><td>') ||
              fn_html_escape(l_log_sttus) || TO_CLOB('</td><td>') ||
              fn_html_escape(TO_CHAR(l_start_date, 'YYYY-MM-DD HH24:MI:SS')) || TO_CLOB('</td><td>') ||
              fn_html_escape(TO_CHAR(l_end_date, 'YYYY-MM-DD HH24:MI:SS')) || TO_CLOB('</td><td>') ||
              fn_html_escape(TO_CHAR(l_log_id)) ||
              TO_CLOB('</td></tr></table><pre>') ||
              fn_html_escape_clob(l_summary) ||
              TO_CLOB('</pre></body></html>');

    RETURN l_html;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN TO_CLOB('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>') ||
             fn_html_escape(l_component || ' ' || l_process || ' summary') ||
             TO_CLOB('</title></head><body><h1>') ||
             fn_html_escape(l_component || ' ' || l_process || ' summary') ||
             TO_CLOB('</h1><p>No summary available.</p></body></html>');
  END fn_latest_summary_html;
END PKG_UTIL_REPORT;
/
