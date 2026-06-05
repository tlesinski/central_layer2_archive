PROMPT REPLICA 005 - utility report and mail

CONNECT &&ACTIVE_REPLICA_SCHEMA/"&&ACTIVE_REPLICA_PASSWORD"@&&ACTIVE_REPLICA_CONNECT

DECLARE
  l_report CLOB;
  l_summary CLOB;
  l_enabled VARCHAR2(1);
  l_lookback_days VARCHAR2(4000);
  l_summary_max_chars VARCHAR2(4000);
BEGIN
  l_enabled := PKG_UTIL_MAIL.fn_mail_enabled;
  l_lookback_days := PKG_UTIL_REPORT.fn_get_config('REPORT_LOOKBACK_DAYS');
  l_summary_max_chars := PKG_UTIL_REPORT.fn_get_config('REPORT_SUMMARY_MAX_CHARS');

  IF l_enabled NOT IN ('Y', 'N') THEN
    RAISE_APPLICATION_ERROR(-20640, 'REPLICA utility mail enabled flag must be Y or N');
  END IF;

  IF l_lookback_days IS NULL OR NOT REGEXP_LIKE(l_lookback_days, '^[0-9]+$') THEN
    RAISE_APPLICATION_ERROR(-20642, 'REPLICA REPORT_LOOKBACK_DAYS must be numeric');
  END IF;

  IF l_summary_max_chars IS NULL OR NOT REGEXP_LIKE(l_summary_max_chars, '^[0-9]+$') THEN
    RAISE_APPLICATION_ERROR(-20644, 'REPLICA REPORT_SUMMARY_MAX_CHARS must be numeric');
  END IF;

  l_report := PKG_UTIL_REPORT.fn_report_html('UTIL_SMOKE_REPORT');
  IF DBMS_LOB.GETLENGTH(l_report) = 0 THEN
    RAISE_APPLICATION_ERROR(-20641, 'REPLICA utility report returned empty HTML');
  END IF;

  l_summary := PKG_UTIL_REPORT.fn_report_html('REPLICA_SUMMARY');
  IF DBMS_LOB.GETLENGTH(l_summary) = 0 THEN
    RAISE_APPLICATION_ERROR(-20643, 'REPLICA summary report returned empty HTML');
  END IF;

  IF l_enabled = 'Y' THEN
    PKG_UTIL_MAIL.prc_send_report('REPLICA_SUMMARY');
  ELSE
    PKG_UTIL_MAIL.prc_send_html('nobody@example.invalid', 'Disabled mail smoke', l_report);
  END IF;
END;
/

PROMPT REPLICA 005 completed
