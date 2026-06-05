COLUMN test_one_script NEW_VALUE TEST_ONE_SCRIPT NOPRINT
SELECT CASE UPPER(TRIM('&&TEST_ID'))
         WHEN '001' THEN '001_metadata.sql'
         WHEN '002' THEN '002_db_link.sql'
         WHEN '003' THEN '003_archive_flow.sql'
         WHEN '004' THEN '004_quality.sql'
         WHEN '005' THEN '005_util_objects.sql'
         ELSE '../fail_invalid_test_id.sql'
       END AS test_one_script
  FROM dual;

@@&&TEST_ONE_SCRIPT
