SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Starting destructive schema reset and code reinstallation
@@reset_schemas.sql
@@install_code.sql

COLUMN mail_acl_script NEW_VALUE MAIL_ACL_SCRIPT NOPRINT
SELECT CASE UPPER(TRIM('&&CONFIGURE_MAIL_ACL'))
         WHEN 'Y' THEN 'configure_mail_acl.sql'
         ELSE 'seed/skip_seed.sql'
       END AS mail_acl_script
  FROM dual;

@@&&MAIL_ACL_SCRIPT

COLUMN seed_script NEW_VALUE SEED_SCRIPT NOPRINT
SELECT CASE UPPER(TRIM('&&RUN_SEEDS_AFTER_REINSTALL'))
         WHEN 'Y' THEN 'seed.sql'
         ELSE 'seed/skip_seed.sql'
       END AS seed_script
  FROM dual;

@@&&SEED_SCRIPT

COLUMN test_script NEW_VALUE TEST_SCRIPT NOPRINT
SELECT CASE UPPER(TRIM('&&RUN_TESTS_AFTER_REINSTALL'))
         WHEN 'Y' THEN 'test.sql'
         ELSE 'tests/skip_test.sql'
       END AS test_script
  FROM dual;

@@&&TEST_SCRIPT &&REINSTALL_TEST_LEVEL &&REINSTALL_TEST_ID
PROMPT Reinstallation completed successfully
