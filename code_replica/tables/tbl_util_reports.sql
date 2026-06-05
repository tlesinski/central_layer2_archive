SET SQLBLANKLINES ON

DECLARE
  l_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_count
    FROM USER_TABLES
   WHERE TABLE_NAME = 'TBL_UTIL_REPORTS';

  IF l_count = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE TBL_UTIL_REPORTS
      (
        REPORT_NAME   VARCHAR2(128) NOT NULL,
        REPORT_COMMENT VARCHAR2(4000),
        REPORT_HTML   CLOB NOT NULL,
        CREATED_AT    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
        UPDATED_AT    TIMESTAMP,
        CONSTRAINT TBL_UTIL_REPORTS_PK PRIMARY KEY (REPORT_NAME)
      )
      LOB (REPORT_HTML) STORE AS SECUREFILE
    ]';
  END IF;
END;
/

MERGE INTO TBL_UTIL_REPORTS t
USING (
  SELECT 'UTIL_SMOKE_REPORT' report_name,
         'Utility smoke report' report_comment,
         TO_CLOB(q'[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Utility smoke report</title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 13px; color: #1f2933; }
    table { border-collapse: collapse; width: 100%; margin: 12px 0; }
    th, td { border: 1px solid #c7d0d9; padding: 6px 8px; text-align: left; }
    th { background: #eef2f6; }
  </style>
</head>
<body>
  <h1>Utility smoke report</h1>
  <p>Generated at <PARM1></p>
  <SQL>SQL_UTIL_SMOKE</SQL>
</body>
</html>
]') report_html
    FROM dual
  UNION ALL
  SELECT 'REPLICA_SUMMARY' report_name,
         'REPLICA component summary report for the configured lookback window' report_comment,
         TO_CLOB(q'[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>REPLICA summary</title>
  <style>
    body { font-family: Arial, sans-serif; font-size: 13px; color: #1f2933; }
    h1 { margin-bottom: 4px; }
    h2 { margin-top: 22px; border-bottom: 1px solid #c7d0d9; padding-bottom: 4px; }
    table { border-collapse: collapse; width: 100%; margin: 10px 0 16px; }
    th, td { border: 1px solid #c7d0d9; padding: 6px 8px; text-align: left; vertical-align: top; }
    th { background: #eef2f6; }
    .muted { color: #65758b; }
    .log-text { white-space: pre-wrap; font-family: Consolas, "Courier New", monospace; font-size: 12px; line-height: 1.45; background: #f8fafc; }
  </style>
</head>
<body>
  <h1>REPLICA summary</h1>
  <p class="muted">Generated at <PARM1>. Window is controlled by TBL_UTIL_CONFIG.REPORT_LOOKBACK_DAYS.</p>

  <h2>Report Window</h2>
  <SQL>SQL_REPLICA_REPORT_WINDOW</SQL>

  <h2>Executive Summary</h2>
  <SQL>SQL_REPLICA_EXEC_SUMMARY</SQL>

  <h2>Process Summary</h2>
  <SQL>SQL_REPLICA_PROCESS_SUMMARY</SQL>

  <h2>Latest Process Summary Attachments</h2>
  <p>Full latest process summaries are attached to this mail as separate HTML files.</p>

  <h2>Data Status Summary</h2>
  <SQL>SQL_REPLICA_DATA_STATUS</SQL>

  <h2>Current Pending Work</h2>
  <SQL>SQL_REPLICA_PENDING_WORK</SQL>

  <h2>Recent Failures And Warnings</h2>
  <SQL>SQL_REPLICA_RECENT_ISSUES</SQL>
</body>
</html>
]') report_html
    FROM dual
) s
ON (t.REPORT_NAME = s.REPORT_NAME)
WHEN MATCHED THEN
  UPDATE SET t.REPORT_COMMENT = s.REPORT_COMMENT,
             t.REPORT_HTML = s.REPORT_HTML,
             t.UPDATED_AT = SYSTIMESTAMP
WHEN NOT MATCHED THEN
  INSERT (REPORT_NAME, REPORT_COMMENT, REPORT_HTML)
  VALUES (s.REPORT_NAME, s.REPORT_COMMENT, s.REPORT_HTML);

COMMIT;
