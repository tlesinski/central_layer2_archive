COLUMN test_one_script NEW_VALUE TEST_ONE_SCRIPT NOPRINT
SELECT CASE UPPER(TRIM('&&TEST_ID'))
         WHEN '001' THEN '001_source_tables.sql'
         WHEN '002' THEN '002_agent_health.sql'
         WHEN '003' THEN '003_agent_counts.sql'
         ELSE '../fail_invalid_test_id.sql'
       END AS test_one_script
  FROM dual;

@@&&TEST_ONE_SCRIPT
