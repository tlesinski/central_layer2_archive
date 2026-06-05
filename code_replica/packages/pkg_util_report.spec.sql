CREATE OR REPLACE PACKAGE PKG_UTIL_REPORT
AUTHID CURRENT_USER
AS
  FUNCTION fn_get_config
  (
    p_config_key IN VARCHAR2,
    p_default    IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2;

  FUNCTION fn_html_escape
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2;

  FUNCTION fn_html_escape_clob
  (
    p_value IN CLOB
  )
  RETURN CLOB;

  FUNCTION fn_report_html
  (
    p_report_name IN VARCHAR2,
    p_parm1       IN VARCHAR2 DEFAULT NULL,
    p_parm2       IN VARCHAR2 DEFAULT NULL,
    p_parm3       IN VARCHAR2 DEFAULT NULL
  )
  RETURN CLOB;

  FUNCTION fn_latest_summary_html
  (
    p_component IN VARCHAR2,
    p_process   IN VARCHAR2
  )
  RETURN CLOB;
END PKG_UTIL_REPORT;
/
