PROMPT ARCHIVER 005 - utility report and mail

CONNECT &&ACTIVE_ARCHIVER_SCHEMA/"&&ACTIVE_ARCHIVER_PASSWORD"@&&ACTIVE_ARCHIVER_CONNECT

DECLARE
  l_report CLOB;
  l_summary CLOB;
  l_enabled VARCHAR2(1);
  l_lookback_days VARCHAR2(4000);
BEGIN
  l_enabled := PKG_UTIL_MAIL.fn_mail_enabled;
  l_lookback_days := PKG_UTIL_REPORT.fn_get_config('REPORT_LOOKBACK_DAYS');

  IF l_enabled NOT IN ('Y', 'N') THEN
    RAISE_APPLICATION_ERROR(-20630, 'ARCHIVER utility mail enabled flag must be Y or N');
  END IF;

  IF l_lookback_days IS NULL OR NOT REGEXP_LIKE(l_lookback_days, '^[0-9]+$') THEN
    RAISE_APPLICATION_ERROR(-20632, 'ARCHIVER REPORT_LOOKBACK_DAYS must be numeric');
  END IF;

  l_report := PKG_UTIL_REPORT.fn_report_html('UTIL_SMOKE_REPORT');
  IF DBMS_LOB.GETLENGTH(l_report) = 0 THEN
    RAISE_APPLICATION_ERROR(-20631, 'ARCHIVER utility report returned empty HTML');
  END IF;

  l_summary := PKG_UTIL_REPORT.fn_report_html('ARCHIVER_SUMMARY');
  IF DBMS_LOB.GETLENGTH(l_summary) = 0 THEN
    RAISE_APPLICATION_ERROR(-20633, 'ARCHIVER summary report returned empty HTML');
  END IF;

  IF l_enabled = 'Y' THEN
    PKG_UTIL_MAIL.prc_send_report('ARCHIVER_SUMMARY');
  ELSE
    PKG_UTIL_MAIL.prc_send_html('nobody@example.invalid', 'Disabled mail smoke', l_report);
  END IF;
END;
/

PROMPT ARCHIVER 005 completed
