CREATE OR REPLACE PACKAGE PKG_UTIL_REPORT
AUTHID CURRENT_USER
AS
  /*
    Package      : PKG_UTIL_REPORT
    Purpose      : Render configured operational reports as HTML.

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-10-11   Tomasz Lesinski    Add package change history
  */
  -- Reads a report configuration value, using a fallback when it is not configured.
  -- Parameters:
  -- p_config_key configuration key to read
  -- p_default    value returned when the key has no configured value
  -- Returns the configured value or the fallback.
  FUNCTION fn_get_config
  (
    p_config_key IN VARCHAR2,
    p_default    IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2;

  -- Escapes special characters in a VARCHAR2 value for safe HTML output.
  -- Parameters:
  -- p_value text to escape
  -- Returns the HTML-escaped text.
  FUNCTION fn_html_escape
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2;

  -- Escapes special characters in a CLOB for safe HTML output.
  -- Parameters:
  -- p_value CLOB text to escape
  -- Returns the HTML-escaped CLOB.
  FUNCTION fn_html_escape_clob
  (
    p_value IN CLOB
  )
  RETURN CLOB;

  -- Renders a configured report as HTML, substituting up to three report arguments.
  -- Parameters:
  -- p_report_name configured report name
  -- p_parm1       first optional report argument
  -- p_parm2       second optional report argument
  -- p_parm3       third optional report argument
  -- Returns the rendered report as HTML.
  FUNCTION fn_report_html
  (
    p_report_name IN VARCHAR2,
    p_parm1       IN VARCHAR2 DEFAULT NULL,
    p_parm2       IN VARCHAR2 DEFAULT NULL,
    p_parm3       IN VARCHAR2 DEFAULT NULL
  )
  RETURN CLOB;

  -- Renders the latest process summary for a component and process as HTML.
  -- Parameters:
  -- p_component component whose process history to report
  -- p_process   process name to report
  -- Returns the latest summary as HTML.
  FUNCTION fn_latest_summary_html
  (
    p_component IN VARCHAR2,
    p_process   IN VARCHAR2
  )
  RETURN CLOB;
END PKG_UTIL_REPORT;
/
