SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Loading local installation configuration
@deploy/config/install_config.local.sql

DECLARE
  l_application_schema       VARCHAR2(128)  := TRIM(q'[&&APPLICATION_SCHEMA]');
  l_application_password     VARCHAR2(1000) := q'[&&APPLICATION_PASSWORD]';
  l_default_tablespace       VARCHAR2(128)  := TRIM(q'[&&DEFAULT_TABLESPACE]');
  l_temporary_tablespace     VARCHAR2(128)  := TRIM(q'[&&TEMPORARY_TABLESPACE]');
  l_install_agent            VARCHAR2(1)    := UPPER(TRIM(q'[&&INSTALL_AGENT]'));
  l_install_archiver         VARCHAR2(1)    := UPPER(TRIM(q'[&&INSTALL_ARCHIVER]'));
  l_install_replica          VARCHAR2(1)    := UPPER(TRIM(q'[&&INSTALL_REPLICA]'));
  l_archiver_connect         VARCHAR2(1000) := TRIM(q'[&&ARCHIVER_CONNECT]');
  l_replica_connect          VARCHAR2(1000) := TRIM(q'[&&REPLICA_CONNECT]');
  l_archiver_admin_user      VARCHAR2(128)  := TRIM(q'[&&ARCHIVER_ADMIN_USER]');
  l_archiver_admin_password  VARCHAR2(1000) := q'[&&ARCHIVER_ADMIN_PASSWORD]';
  l_replica_admin_user       VARCHAR2(128)  := TRIM(q'[&&REPLICA_ADMIN_USER]');
  l_replica_admin_password   VARCHAR2(1000) := q'[&&REPLICA_ADMIN_PASSWORD]';
  l_replica_archiver_db_link VARCHAR2(128)  := TRIM(q'[&&REPLICA_ARCHIVER_DB_LINK]');
  l_combined_connect         VARCHAR2(1000) := TRIM(q'[&&COMBINED_CONNECT]');
  l_combined_agent_db_link   VARCHAR2(128)  := TRIM(q'[&&COMBINED_AGENT_DB_LINK]');
  l_combined_archiver_link   VARCHAR2(128)  := TRIM(q'[&&COMBINED_ARCHIVER_DB_LINK]');

  PROCEDURE assert_present
  (
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2
  )
  IS
  BEGIN
    IF p_value IS NULL THEN
      RAISE_APPLICATION_ERROR(-20100, p_name || ' must not be empty');
    END IF;
  END assert_present;

  PROCEDURE assert_simple_name
  (
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2
  )
  IS
  BEGIN
    assert_present(p_name, p_value);
    IF NOT REGEXP_LIKE(p_value, '^[A-Za-z][A-Za-z0-9_$#]{0,127}$') THEN
      RAISE_APPLICATION_ERROR(-20101, p_name || ' is not a valid Oracle identifier');
    END IF;
  END assert_simple_name;

  PROCEDURE assert_flag
  (
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2
  )
  IS
  BEGIN
    IF p_value NOT IN ('Y', 'N') THEN
      RAISE_APPLICATION_ERROR(-20102, p_name || ' must be Y or N');
    END IF;
  END assert_flag;
BEGIN
  assert_simple_name('APPLICATION_SCHEMA', l_application_schema);
  assert_present('APPLICATION_PASSWORD', l_application_password);
  assert_simple_name('DEFAULT_TABLESPACE', l_default_tablespace);
  assert_simple_name('TEMPORARY_TABLESPACE', l_temporary_tablespace);
  assert_flag('INSTALL_AGENT', l_install_agent);
  assert_flag('INSTALL_ARCHIVER', l_install_archiver);
  assert_flag('INSTALL_REPLICA', l_install_replica);

  IF l_install_agent = 'N' AND l_install_archiver = 'N' AND l_install_replica = 'N' THEN
    RAISE_APPLICATION_ERROR(-20103, 'At least one component must be enabled');
  END IF;

  IF l_install_archiver = 'Y' THEN
    assert_present('ARCHIVER_CONNECT', l_archiver_connect);
    assert_simple_name('ARCHIVER_ADMIN_USER', l_archiver_admin_user);
    assert_present('ARCHIVER_ADMIN_PASSWORD', l_archiver_admin_password);
  END IF;

  IF l_install_replica = 'Y' THEN
    assert_present('REPLICA_CONNECT', l_replica_connect);
    assert_simple_name('REPLICA_ADMIN_USER', l_replica_admin_user);
    assert_present('REPLICA_ADMIN_PASSWORD', l_replica_admin_password);
    assert_simple_name('REPLICA_ARCHIVER_DB_LINK', l_replica_archiver_db_link);
    IF UPPER(l_replica_archiver_db_link) IN ('LOCAL', 'NONE') THEN
      RAISE_APPLICATION_ERROR(-20104, 'REPLICA_ARCHIVER_DB_LINK must identify a real DB link');
    END IF;
  END IF;

  IF l_install_agent = 'Y' AND l_install_archiver = 'Y' AND l_install_replica = 'Y' THEN
    assert_present('COMBINED_CONNECT', l_combined_connect);
    assert_simple_name('COMBINED_AGENT_DB_LINK', l_combined_agent_db_link);
    assert_simple_name('COMBINED_ARCHIVER_DB_LINK', l_combined_archiver_link);

    IF UPPER(l_combined_agent_db_link) IN ('LOCAL', 'NONE')
       OR UPPER(l_combined_archiver_link) IN ('LOCAL', 'NONE') THEN
      RAISE_APPLICATION_ERROR(-20105, 'Combined component links must identify real DB links');
    ELSIF UPPER(l_combined_agent_db_link) = UPPER(l_combined_archiver_link) THEN
      RAISE_APPLICATION_ERROR(-20106, 'Combined AGENT and ARCHIVER DB links must have distinct names');
    END IF;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Validated global installation configuration');
  DBMS_OUTPUT.PUT_LINE('Application schema: ' || UPPER(l_application_schema));
  DBMS_OUTPUT.PUT_LINE(
    'Enabled components: AGENT=' || l_install_agent ||
    ' ARCHIVER=' || l_install_archiver ||
    ' REPLICA=' || l_install_replica
  );
  assert_present('AGENT_INSTANCE_MANIFEST', q'[&&AGENT_INSTANCE_MANIFEST]');
  assert_present('PROVISION_TARGET_MANIFEST', q'[&&PROVISION_TARGET_MANIFEST]');
END;
/

DEFINE AGENT_ACTION_SCRIPT = deploy/config/validate_agent_instance.sql

BEGIN
  IF UPPER(TRIM(q'[&&INSTALL_AGENT]')) = 'Y' THEN
    DBMS_OUTPUT.PUT_LINE('Validating configured AGENT instances');
  ELSE
    DBMS_OUTPUT.PUT_LINE('AGENT installation disabled; validating remote AGENT topology entries');
  END IF;
END;
/

-- The manifest is intentionally executable and reusable by later stages.
-- For Stage 1 it validates entries. Later orchestration will set another action.
@&&AGENT_INSTANCE_MANIFEST

PROMPT Installation configuration validation completed successfully
