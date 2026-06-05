DECLARE
  l_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_count
    FROM USER_TABLES
   WHERE TABLE_NAME = 'TBL_UTIL_CONFIG';

  IF l_count = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE TBL_UTIL_CONFIG
      (
        CONFIG_KEY     VARCHAR2(128) NOT NULL,
        CONFIG_VALUE   VARCHAR2(4000),
        CONFIG_COMMENT VARCHAR2(4000),
        CREATED_AT     TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
        UPDATED_AT     TIMESTAMP,
        CONSTRAINT TBL_UTIL_CONFIG_PK PRIMARY KEY (CONFIG_KEY)
      )
    ]';
  END IF;
END;
/

MERGE INTO TBL_UTIL_CONFIG t
USING (
  SELECT 'MAIL_ENABLED' config_key, 'N' config_value, 'Enables real SMTP sending when set to Y' config_comment FROM dual UNION ALL
  SELECT 'SMTP_HOST', NULL, 'SMTP host used by PKG_UTIL_MAIL' FROM dual UNION ALL
  SELECT 'SMTP_PORT', '25', 'SMTP port used by PKG_UTIL_MAIL' FROM dual UNION ALL
  SELECT 'MAIL_FROM', NULL, 'Default sender address' FROM dual UNION ALL
  SELECT 'MAIL_TO', NULL, 'Default recipient list' FROM dual UNION ALL
  SELECT 'REPORT_MAX_ROWS', '100', 'Maximum rows rendered by report SQL sections' FROM dual UNION ALL
  SELECT 'REPORT_LOOKBACK_DAYS', '7', 'Default report lookback window in days' FROM dual UNION ALL
  SELECT 'REPORT_SUMMARY_MAX_CHARS', '4000', 'Maximum characters rendered per process in latest process summary logs' FROM dual
) s
ON (t.CONFIG_KEY = s.CONFIG_KEY)
WHEN NOT MATCHED THEN
  INSERT (CONFIG_KEY, CONFIG_VALUE, CONFIG_COMMENT)
  VALUES (s.CONFIG_KEY, s.CONFIG_VALUE, s.CONFIG_COMMENT);

COMMIT;
