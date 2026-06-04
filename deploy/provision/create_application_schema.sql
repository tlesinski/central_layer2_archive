SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
  l_schema_name          VARCHAR2(128)  := UPPER(TRIM(q'[&&APPLICATION_SCHEMA]'));
  l_schema_password      VARCHAR2(1000) := q'[&&APPLICATION_PASSWORD]';
  l_default_tablespace   VARCHAR2(128)  := UPPER(TRIM(q'[&&DEFAULT_TABLESPACE]'));
  l_temporary_tablespace VARCHAR2(128)  := UPPER(TRIM(q'[&&TEMPORARY_TABLESPACE]'));
  l_count                NUMBER;
  l_sql                  VARCHAR2(4000);

  FUNCTION simple_name
  (
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF NOT REGEXP_LIKE(p_value, '^[A-Z][A-Z0-9_$#]{0,127}$') THEN
      RAISE_APPLICATION_ERROR(-20200, p_name || ' is not a valid Oracle identifier');
    END IF;
    RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(p_value);
  END simple_name;

  FUNCTION quoted_password
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF p_value IS NULL THEN
      RAISE_APPLICATION_ERROR(-20201, 'APPLICATION_PASSWORD must not be empty');
    END IF;
    RETURN '"' || REPLACE(p_value, '"', '""') || '"';
  END quoted_password;
BEGIN
  l_schema_name := simple_name('APPLICATION_SCHEMA', l_schema_name);
  l_default_tablespace := simple_name('DEFAULT_TABLESPACE', l_default_tablespace);
  l_temporary_tablespace := simple_name('TEMPORARY_TABLESPACE', l_temporary_tablespace);

  SELECT COUNT(*)
    INTO l_count
    FROM dba_users
   WHERE username = l_schema_name;

  IF l_count > 0 THEN
    RAISE_APPLICATION_ERROR(-20202, 'Application schema ' || l_schema_name || ' already exists');
  END IF;

  l_sql :=
    'CREATE USER ' || l_schema_name ||
    ' IDENTIFIED BY ' || quoted_password(l_schema_password) ||
    ' DEFAULT TABLESPACE ' || l_default_tablespace ||
    ' TEMPORARY TABLESPACE ' || l_temporary_tablespace ||
    ' QUOTA UNLIMITED ON ' || l_default_tablespace;
  EXECUTE IMMEDIATE l_sql;

  FOR privilege_name IN (
    SELECT column_value AS name
      FROM TABLE(sys.odcivarchar2list(
        'CREATE SESSION',
        'CREATE TABLE',
        'CREATE VIEW',
        'CREATE SYNONYM',
        'CREATE PROCEDURE',
        'CREATE SEQUENCE',
        'CREATE TRIGGER',
        'CREATE TYPE',
        'CREATE DATABASE LINK'
      ))
  ) LOOP
    EXECUTE IMMEDIATE 'GRANT ' || privilege_name.name || ' TO ' || l_schema_name;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Created application schema ' || l_schema_name);
  DBMS_OUTPUT.PUT_LINE(
    'Default tablespace=' || l_default_tablespace ||
    ' temporary tablespace=' || l_temporary_tablespace ||
    ' quota=UNLIMITED'
  );
END;
/
