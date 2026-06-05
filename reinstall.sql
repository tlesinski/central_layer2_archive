SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Starting destructive schema reset and code reinstallation
@@reset_schemas.sql
@@install_code.sql

COLUMN seed_script NEW_VALUE SEED_SCRIPT NOPRINT
SELECT CASE UPPER(TRIM('&&RUN_SEEDS_AFTER_REINSTALL'))
         WHEN 'Y' THEN 'seed.sql'
         ELSE 'seed/skip_seed.sql'
       END AS seed_script
  FROM dual;

@@&&SEED_SCRIPT
PROMPT Reinstallation completed successfully
