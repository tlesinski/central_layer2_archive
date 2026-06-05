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
) s
ON (t.REPORT_NAME = s.REPORT_NAME)
WHEN NOT MATCHED THEN
  INSERT (REPORT_NAME, REPORT_COMMENT, REPORT_HTML)
  VALUES (s.REPORT_NAME, s.REPORT_COMMENT, s.REPORT_HTML);

COMMIT;
