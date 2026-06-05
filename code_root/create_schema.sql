SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
  l_schema    VARCHAR2(128)  := UPPER(TRIM(q'[&1]'));
  l_password  VARCHAR2(1000) := q'[&2]';
  l_profile   VARCHAR2(20)   := UPPER(TRIM(q'[&3]'));
  l_default   VARCHAR2(128)  := UPPER(TRIM(q'[&&DEFAULT_TABLESPACE]'));
  l_temporary VARCHAR2(128)  := UPPER(TRIM(q'[&&TEMPORARY_TABLESPACE]'));
  l_count     PLS_INTEGER;

  PROCEDURE grant_privilege(p_privilege IN VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'GRANT ' || p_privilege || ' TO ' || l_schema;
  END;
BEGIN
  l_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(l_schema);
  l_default := DBMS_ASSERT.SIMPLE_SQL_NAME(l_default);
  l_temporary := DBMS_ASSERT.SIMPLE_SQL_NAME(l_temporary);

  IF l_password IS NULL THEN
    RAISE_APPLICATION_ERROR(-20310, 'Schema password must not be empty');
  ELSIF l_profile NOT IN ('CLIENT', 'AGENT', 'ARCHIVER', 'REPLICA', 'SHARED') THEN
    RAISE_APPLICATION_ERROR(-20311, 'Unsupported schema profile: ' || l_profile);
  END IF;

  SELECT COUNT(*) INTO l_count FROM DBA_USERS WHERE USERNAME = l_schema;
  IF l_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20312, 'Schema already exists: ' || l_schema);
  END IF;

  EXECUTE IMMEDIATE
    'CREATE USER ' || l_schema ||
    ' IDENTIFIED BY "' || REPLACE(l_password, '"', '""') || '"' ||
    ' DEFAULT TABLESPACE ' || l_default ||
    ' TEMPORARY TABLESPACE ' || l_temporary ||
    ' QUOTA UNLIMITED ON ' || l_default;

  grant_privilege('CREATE SESSION');

  IF l_profile = 'CLIENT' THEN
    grant_privilege('CREATE TABLE');
    grant_privilege('CREATE VIEW');
    grant_privilege('CREATE SEQUENCE');
    grant_privilege('CREATE PROCEDURE');
    grant_privilege('CREATE TRIGGER');
    grant_privilege('CREATE TYPE');
  ELSIF l_profile = 'AGENT' THEN
    grant_privilege('CREATE VIEW');
    grant_privilege('CREATE PROCEDURE');
    grant_privilege('CREATE TYPE');
    grant_privilege('SELECT ANY TABLE');
    grant_privilege('ALTER ANY TABLE');
  ELSE
    grant_privilege('CREATE TABLE');
    grant_privilege('CREATE VIEW');
    grant_privilege('CREATE SYNONYM');
    grant_privilege('CREATE PROCEDURE');
    grant_privilege('CREATE SEQUENCE');
    grant_privilege('CREATE TRIGGER');
    grant_privilege('CREATE TYPE');
    grant_privilege('CREATE DATABASE LINK');
    grant_privilege('ALTER SESSION');
    grant_privilege('EXECUTE ON SYS.UTL_SMTP');
    grant_privilege('EXECUTE ON SYS.UTL_TCP');

    IF l_profile = 'SHARED' THEN
      grant_privilege('SELECT ANY TABLE');
      grant_privilege('ALTER ANY TABLE');
    END IF;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Created schema ' || l_schema || ' profile=' || l_profile);
END;
/
