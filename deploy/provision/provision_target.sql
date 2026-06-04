SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Connecting to provisioning target &1 at &2
CONNECT &3/"&4"@&2 AS &5

SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
  l_target_key VARCHAR2(128) := UPPER(TRIM(q'[&1]'));
  l_admin_role VARCHAR2(30)  := UPPER(TRIM(q'[&5]'));
BEGIN
  IF NOT REGEXP_LIKE(l_target_key, '^[A-Z][A-Z0-9_$#]{0,127}$') THEN
    RAISE_APPLICATION_ERROR(-20210, 'Provision target key is not a valid identifier');
  END IF;

  IF l_admin_role <> 'SYSDBA' THEN
    RAISE_APPLICATION_ERROR(-20211, 'Provision admin role must be SYSDBA');
  END IF;

  DBMS_OUTPUT.PUT_LINE('Provisioning target validated: ' || l_target_key);
END;
/

@deploy/config/validate_install_config.sql
@deploy/provision/create_application_schema.sql
