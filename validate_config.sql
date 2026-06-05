SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

@@config.local.sql

CONNECT SYS/"&&SOURCE_SYS_PASSWORD"@&&SOURCE_SYS_CONNECT AS SYSDBA

DECLARE
  l_schemas SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
    UPPER(TRIM(q'[&&CLIENT1_SCHEMA]')),
    UPPER(TRIM(q'[&&CLIENT2_SCHEMA]')),
    UPPER(TRIM(q'[&&AGENT_SCHEMA]')),
    UPPER(TRIM(q'[&&ARCHIVER_SCHEMA]')),
    UPPER(TRIM(q'[&&REPLICA_SCHEMA]')),
    UPPER(TRIM(q'[&&SHARED_SCHEMA]'))
  );

  PROCEDURE assert_present(p_name IN VARCHAR2, p_value IN VARCHAR2) IS
  BEGIN
    IF TRIM(p_value) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20300, p_name || ' must not be empty');
    END IF;
  END;

  PROCEDURE assert_name(p_name IN VARCHAR2, p_value IN VARCHAR2) IS
  BEGIN
    assert_present(p_name, p_value);
    IF NOT REGEXP_LIKE(p_value, '^[A-Za-z][A-Za-z0-9_$#]{0,127}$') THEN
      RAISE_APPLICATION_ERROR(-20301, p_name || ' is not a valid Oracle identifier');
    END IF;
  END;

  PROCEDURE assert_link(p_name IN VARCHAR2, p_value IN VARCHAR2) IS
  BEGIN
    assert_name(p_name, p_value);
    IF UPPER(TRIM(p_value)) IN ('LOCAL', 'NONE') THEN
      RAISE_APPLICATION_ERROR(-20302, p_name || ' must identify a real DB link');
    END IF;
  END;

  PROCEDURE assert_yes_no(p_name IN VARCHAR2, p_value IN VARCHAR2) IS
  BEGIN
    IF UPPER(TRIM(p_value)) NOT IN ('Y', 'N') THEN
      RAISE_APPLICATION_ERROR(-20306, p_name || ' must be Y or N');
    END IF;
  END;
BEGIN
  IF UPPER(TRIM(q'[&&INSTALL_MODEL]')) NOT IN ('SHARED', 'SPLIT') THEN
    RAISE_APPLICATION_ERROR(-20303, 'INSTALL_MODEL must be SHARED or SPLIT');
  END IF;

  assert_yes_no('RUN_SEEDS_AFTER_REINSTALL', q'[&&RUN_SEEDS_AFTER_REINSTALL]');
  assert_yes_no('REBUILD_SEED_CLIENT', q'[&&REBUILD_SEED_CLIENT]');
  assert_yes_no('REBUILD_SEED_ARCHIVER', q'[&&REBUILD_SEED_ARCHIVER]');
  assert_yes_no('REBUILD_SEED_REPLICA', q'[&&REBUILD_SEED_REPLICA]');

  assert_name('DEFAULT_TABLESPACE', q'[&&DEFAULT_TABLESPACE]');
  assert_name('TEMPORARY_TABLESPACE', q'[&&TEMPORARY_TABLESPACE]');

  assert_present('SOURCE_SYS_CONNECT', q'[&&SOURCE_SYS_CONNECT]');
  assert_present('SOURCE_SYS_PASSWORD', q'[&&SOURCE_SYS_PASSWORD]');
  assert_present('ARCHIVER_SYS_CONNECT', q'[&&ARCHIVER_SYS_CONNECT]');
  assert_present('ARCHIVER_SYS_PASSWORD', q'[&&ARCHIVER_SYS_PASSWORD]');
  assert_present('REPLICA_SYS_CONNECT', q'[&&REPLICA_SYS_CONNECT]');
  assert_present('REPLICA_SYS_PASSWORD', q'[&&REPLICA_SYS_PASSWORD]');

  assert_name('CLIENT1_SCHEMA', q'[&&CLIENT1_SCHEMA]');
  assert_present('CLIENT1_PASSWORD', q'[&&CLIENT1_PASSWORD]');
  assert_name('CLIENT2_SCHEMA', q'[&&CLIENT2_SCHEMA]');
  assert_present('CLIENT2_PASSWORD', q'[&&CLIENT2_PASSWORD]');
  assert_name('AGENT_SCHEMA', q'[&&AGENT_SCHEMA]');
  assert_present('AGENT_PASSWORD', q'[&&AGENT_PASSWORD]');
  assert_name('ARCHIVER_SCHEMA', q'[&&ARCHIVER_SCHEMA]');
  assert_present('ARCHIVER_PASSWORD', q'[&&ARCHIVER_PASSWORD]');
  assert_name('REPLICA_SCHEMA', q'[&&REPLICA_SCHEMA]');
  assert_present('REPLICA_PASSWORD', q'[&&REPLICA_PASSWORD]');
  assert_name('SHARED_SCHEMA', q'[&&SHARED_SCHEMA]');
  assert_present('SHARED_PASSWORD', q'[&&SHARED_PASSWORD]');

  FOR i IN 1 .. l_schemas.COUNT LOOP
    IF i < l_schemas.COUNT THEN
      FOR j IN i + 1 .. l_schemas.COUNT LOOP
        IF l_schemas(i) = l_schemas(j) THEN
          RAISE_APPLICATION_ERROR(-20305, 'Configured schema names must be unique: ' || l_schemas(i));
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  assert_link('ARCHIVER_AGENT_DB_LINK', q'[&&ARCHIVER_AGENT_DB_LINK]');
  assert_link('REPLICA_ARCHIVER_DB_LINK', q'[&&REPLICA_ARCHIVER_DB_LINK]');
  assert_link('SHARED_AGENT_DB_LINK', q'[&&SHARED_AGENT_DB_LINK]');
  assert_link('SHARED_ARCHIVER_DB_LINK', q'[&&SHARED_ARCHIVER_DB_LINK]');

  IF UPPER(q'[&&SHARED_AGENT_DB_LINK]') = UPPER(q'[&&SHARED_ARCHIVER_DB_LINK]') THEN
    RAISE_APPLICATION_ERROR(-20304, 'SHARED DB link names must be distinct');
  END IF;

  DBMS_OUTPUT.PUT_LINE('Configuration valid. Install model=' || UPPER(q'[&&INSTALL_MODEL]'));
END;
/
