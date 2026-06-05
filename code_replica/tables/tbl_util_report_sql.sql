SET SQLBLANKLINES ON

DECLARE
  l_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_count
    FROM USER_TABLES
   WHERE TABLE_NAME = 'TBL_UTIL_REPORT_SQL';

  IF l_count = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE TBL_UTIL_REPORT_SQL
      (
        SQL_NAME   VARCHAR2(128) NOT NULL,
        SQL_CODE   CLOB NOT NULL,
        CREATED_AT TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
        UPDATED_AT TIMESTAMP,
        CONSTRAINT TBL_UTIL_REPORT_SQL_PK PRIMARY KEY (SQL_NAME)
      )
      LOB (SQL_CODE) STORE AS SECUREFILE
    ]';
  END IF;
END;
/

MERGE INTO TBL_UTIL_REPORT_SQL t
USING (
  SELECT 'SQL_UTIL_SMOKE' sql_name,
         TO_CLOB(q'[SELECT USER AS schema_name, SYSDATE AS generated_at FROM dual]') sql_code
    FROM dual
  UNION ALL
  SELECT 'SQL_REPLICA_REPORT_WINDOW' sql_name,
         TO_CLOB(q'[
WITH cfg AS (
  SELECT TO_NUMBER(NVL(MAX(CASE WHEN config_key = 'REPORT_LOOKBACK_DAYS' THEN config_value END), '7')) lookback_days
  FROM TBL_UTIL_CONFIG
)
SELECT USER AS schema_name,
       lookback_days,
       TO_CHAR(SYSTIMESTAMP - NUMTODSINTERVAL(lookback_days, 'DAY'), 'YYYY-MM-DD HH24:MI:SS') AS window_start,
       TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS window_end
  FROM cfg
]') sql_code
    FROM dual
  UNION ALL
  SELECT 'SQL_REPLICA_EXEC_SUMMARY' sql_name,
         TO_CLOB(q'[
WITH cfg AS (
  SELECT TO_NUMBER(NVL(MAX(CASE WHEN config_key = 'REPORT_LOOKBACK_DAYS' THEN config_value END), '7')) lookback_days
  FROM TBL_UTIL_CONFIG
),
runs AS (
  SELECT r.*
    FROM TBL_REPLICA_RUNS r
         CROSS JOIN cfg c
   WHERE r.started_at >= SYSTIMESTAMP - NUMTODSINTERVAL(c.lookback_days, 'DAY')
),
latest AS (
  SELECT run_id, run_type, run_status, started_at, ended_at, error_message
    FROM (
      SELECT r.*,
             ROW_NUMBER() OVER (ORDER BY started_at DESC, run_id DESC) rn
        FROM TBL_REPLICA_RUNS r
    )
   WHERE rn = 1
)
SELECT COUNT(r.run_id) AS runs_total,
       SUM(CASE WHEN r.run_status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_runs,
       SUM(CASE WHEN r.run_status = 'WARNING' THEN 1 ELSE 0 END) AS warning_runs,
       SUM(CASE WHEN r.run_status = 'ERROR' THEN 1 ELSE 0 END) AS error_runs,
       SUM(CASE WHEN r.execute_flag = 'Y' THEN 1 ELSE 0 END) AS execute_runs,
       SUM(CASE WHEN r.execute_flag = 'N' THEN 1 ELSE 0 END) AS preview_runs,
       MAX(l.run_status) AS latest_status,
       MAX(TO_CHAR(l.started_at, 'YYYY-MM-DD HH24:MI:SS')) AS latest_started,
       MAX(SUBSTR(l.error_message, 1, 240)) AS latest_error
  FROM runs r
       CROSS JOIN latest l
]') sql_code
    FROM dual
  UNION ALL
SELECT 'SQL_REPLICA_PROCESS_SUMMARY' sql_name,
         TO_CLOB(q'[
WITH cfg AS (
  SELECT TO_NUMBER(NVL(MAX(CASE WHEN config_key = 'REPORT_LOOKBACK_DAYS' THEN config_value END), '7')) lookback_days
  FROM TBL_UTIL_CONFIG
),
processes AS (
  SELECT 'DISCOVER' run_type FROM dual UNION ALL
  SELECT 'REPLICATE' FROM dual UNION ALL
  SELECT 'QUALITY' FROM dual UNION ALL
  SELECT 'PURGE' FROM dual UNION ALL
  SELECT 'RUNNER' FROM dual
),
runs AS (
  SELECT r.*
    FROM TBL_REPLICA_RUNS r
         CROSS JOIN cfg c
   WHERE r.started_at >= SYSTIMESTAMP - NUMTODSINTERVAL(c.lookback_days, 'DAY')
)
SELECT p.run_type,
       COUNT(r.run_id) AS runs_total,
       SUM(CASE WHEN r.run_status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_runs,
       SUM(CASE WHEN r.run_status = 'WARNING' THEN 1 ELSE 0 END) AS warning_runs,
       SUM(CASE WHEN r.run_status = 'ERROR' THEN 1 ELSE 0 END) AS error_runs,
       SUM(CASE WHEN r.execute_flag = 'Y' THEN 1 ELSE 0 END) AS execute_runs,
       SUM(CASE WHEN r.execute_flag = 'N' THEN 1 ELSE 0 END) AS preview_runs,
       MAX(TO_CHAR(r.started_at, 'YYYY-MM-DD HH24:MI:SS')) AS latest_started
  FROM processes p
       LEFT JOIN runs r ON r.run_type = p.run_type
 GROUP BY p.run_type
 ORDER BY CASE p.run_type WHEN 'DISCOVER' THEN 1 WHEN 'REPLICATE' THEN 2 WHEN 'QUALITY' THEN 3 WHEN 'PURGE' THEN 4 ELSE 5 END
]') sql_code
    FROM dual
  UNION ALL
SELECT 'SQL_REPLICA_LATEST_SUMMARIES' sql_name,
         TO_CLOB(q'[
WITH cfg AS (
  SELECT TO_NUMBER(NVL(MAX(CASE WHEN config_key = 'REPORT_LOOKBACK_DAYS' THEN config_value END), '7')) lookback_days,
         TO_NUMBER(NVL(MAX(CASE WHEN config_key = 'REPORT_SUMMARY_MAX_CHARS' THEN config_value END), '32000')) summary_max_chars
  FROM TBL_UTIL_CONFIG
),
processes AS (
  SELECT 'DISCOVER' run_type FROM dual UNION ALL
  SELECT 'REPLICATE' FROM dual UNION ALL
  SELECT 'QUALITY' FROM dual UNION ALL
  SELECT 'PURGE' FROM dual UNION ALL
  SELECT 'RUNNER' FROM dual
),
marked AS (
  SELECT log_categ,
         log_sttus,
         start_date,
         log_id,
         DBMS_LOB.INSTR(log_msg, '<<<PARTMGR_SUMMARY_BEGIN>>>') begin_pos,
         DBMS_LOB.INSTR(log_msg, '<<<PARTMGR_SUMMARY_END>>>') end_pos,
         log_msg
    FROM TBL_REPLICA_PROCESS_LOG l
         CROSS JOIN cfg c
   WHERE l.start_date >= SYSDATE - c.lookback_days
     AND DBMS_LOB.INSTR(log_msg, '<<<PARTMGR_SUMMARY_BEGIN>>>') > 0
     AND DBMS_LOB.INSTR(log_msg, '<<<PARTMGR_SUMMARY_END>>>') > 0
),
summaries AS (
  SELECT log_categ,
         log_sttus,
         start_date,
         REGEXP_REPLACE(SUBSTR(
           log_msg,
           begin_pos + LENGTH('<<<PARTMGR_SUMMARY_BEGIN>>>'),
           LEAST(summary_max_chars, end_pos - (begin_pos + LENGTH('<<<PARTMGR_SUMMARY_BEGIN>>>')))
         ), '^[[:space:]]+|[[:space:]]+$', '') AS summary_text,
         ROW_NUMBER() OVER (PARTITION BY log_categ ORDER BY start_date DESC, log_id DESC) rn
    FROM marked
         CROSS JOIN cfg
   WHERE end_pos > begin_pos + LENGTH('<<<PARTMGR_SUMMARY_BEGIN>>>')
)
SELECT p.run_type,
       NVL(s.log_sttus, 'N/A') AS latest_status,
       NVL(TO_CHAR(s.start_date, 'YYYY-MM-DD HH24:MI:SS'), 'N/A') AS latest_started,
       NVL(s.summary_text, 'No summary available') AS summary_text
  FROM processes p
       LEFT JOIN summaries s
         ON s.log_categ = p.run_type
        AND s.rn = 1
 ORDER BY CASE p.run_type WHEN 'DISCOVER' THEN 1 WHEN 'REPLICATE' THEN 2 WHEN 'QUALITY' THEN 3 WHEN 'PURGE' THEN 4 ELSE 5 END
]') sql_code
    FROM dual
  UNION ALL
  SELECT 'SQL_REPLICA_DATA_STATUS' sql_name,
         TO_CLOB(q'[
SELECT target_owner,
       target_table_name,
       COUNT(*) AS units_total,
       SUM(CASE WHEN replica_status = 'Y' THEN 1 ELSE 0 END) AS replicated_units,
       SUM(CASE WHEN replica_status = 'N' THEN 1 ELSE 0 END) AS replicate_pending,
       SUM(CASE WHEN quality_status = 'Y' THEN 1 ELSE 0 END) AS quality_ok_units,
       SUM(CASE WHEN quality_status = 'N' THEN 1 ELSE 0 END) AS quality_pending,
       SUM(CASE WHEN purge_status = 'Y' THEN 1 ELSE 0 END) AS purged_units,
       SUM(CASE WHEN purge_status = 'N' THEN 1 ELSE 0 END) AS purge_pending,
       SUM(source_row_count) AS source_rows,
       SUM(target_row_count) AS target_rows
  FROM TBL_REPLICA_PARTITIONS
 GROUP BY target_owner, target_table_name
 ORDER BY target_owner, target_table_name
]') sql_code
    FROM dual
  UNION ALL
  SELECT 'SQL_REPLICA_PENDING_WORK' sql_name,
         TO_CLOB(q'[
SELECT source_db_link,
       source_owner,
       source_table_name,
       target_table_name,
       SUM(CASE WHEN replica_status = 'N' THEN 1 ELSE 0 END) AS pending_replicate,
       SUM(CASE WHEN replica_status = 'Y' AND quality_status = 'N' THEN 1 ELSE 0 END) AS pending_quality,
       SUM(CASE WHEN replica_status = 'Y' AND quality_status = 'Y' AND purge_status = 'N' THEN 1 ELSE 0 END) AS purge_candidates,
       SUM(CASE WHEN error_message IS NOT NULL THEN 1 ELSE 0 END) AS units_with_error
  FROM TBL_REPLICA_PARTITIONS
 GROUP BY source_db_link, source_owner, source_table_name, target_table_name
HAVING SUM(CASE WHEN replica_status = 'N'
                  OR (replica_status = 'Y' AND quality_status = 'N')
                  OR (replica_status = 'Y' AND quality_status = 'Y' AND purge_status = 'N')
                  OR error_message IS NOT NULL
                THEN 1 ELSE 0 END) > 0
 ORDER BY source_owner, source_table_name, target_table_name
]') sql_code
    FROM dual
  UNION ALL
  SELECT 'SQL_REPLICA_RECENT_ISSUES' sql_name,
         TO_CLOB(q'[
WITH cfg AS (
  SELECT TO_NUMBER(NVL(MAX(CASE WHEN config_key = 'REPORT_LOOKBACK_DAYS' THEN config_value END), '7')) lookback_days
  FROM TBL_UTIL_CONFIG
),
issues AS (
  SELECT CAST(started_at AS TIMESTAMP) AS issue_time,
         'RUN ' || run_type AS source_name,
         run_status AS status_name,
         SUBSTR(NVL(error_message, source_owner || '.' || source_table_name), 1, 300) AS message_text
    FROM TBL_REPLICA_RUNS r
         CROSS JOIN cfg c
   WHERE r.started_at >= SYSTIMESTAMP - NUMTODSINTERVAL(c.lookback_days, 'DAY')
     AND r.run_status IN ('WARNING', 'ERROR')
  UNION ALL
  SELECT CAST(start_date AS TIMESTAMP) AS issue_time,
         NVL(mstr_fun, log_categ) AS source_name,
         log_sttus AS status_name,
         SUBSTR(DBMS_LOB.SUBSTR(log_msg, 300, 1), 1, 300) AS message_text
    FROM TBL_REPLICA_PROCESS_LOG l
         CROSS JOIN cfg c
   WHERE l.start_date >= SYSDATE - c.lookback_days
     AND (UPPER(l.log_sttus) IN ('WARNING', 'ERROR') OR l.last_err_code IS NOT NULL)
)
SELECT TO_CHAR(issue_time, 'YYYY-MM-DD HH24:MI:SS') AS issue_time,
       source_name,
       status_name,
       message_text
  FROM issues
 ORDER BY issue_time DESC
 FETCH FIRST 20 ROWS ONLY
]') sql_code
    FROM dual
) s
ON (t.SQL_NAME = s.SQL_NAME)
WHEN MATCHED THEN
  UPDATE SET t.SQL_CODE = s.SQL_CODE,
             t.UPDATED_AT = SYSTIMESTAMP
WHEN NOT MATCHED THEN
  INSERT (SQL_NAME, SQL_CODE)
  VALUES (s.SQL_NAME, s.SQL_CODE);

COMMIT;
