PROMPT REPLICA 005 - utility report and mail

CONNECT &&ACTIVE_REPLICA_SCHEMA/"&&ACTIVE_REPLICA_PASSWORD"@&&ACTIVE_REPLICA_CONNECT

DECLARE
  l_report CLOB;
  l_enabled VARCHAR2(1);
BEGIN
  l_enabled := PKG_UTIL_MAIL.fn_mail_enabled;

  IF l_enabled NOT IN ('Y', 'N') THEN
    RAISE_APPLICATION_ERROR(-20640, 'REPLICA utility mail enabled flag must be Y or N');
  END IF;

  l_report := PKG_UTIL_REPORT.fn_report_html('UTIL_SMOKE_REPORT');
  IF DBMS_LOB.GETLENGTH(l_report) = 0 THEN
    RAISE_APPLICATION_ERROR(-20641, 'REPLICA utility report returned empty HTML');
  END IF;

  IF l_enabled = 'Y' THEN
    PKG_UTIL_MAIL.prc_send_report('UTIL_SMOKE_REPORT');
  ELSE
    PKG_UTIL_MAIL.prc_send_html('nobody@example.invalid', 'Disabled mail smoke', l_report);
  END IF;
END;
/

PROMPT REPLICA 005 completed
