SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
  l_schema VARCHAR2(128) := UPPER(TRIM(q'[&1]'));
  l_count  PLS_INTEGER;
BEGIN
  l_schema := DBMS_ASSERT.SIMPLE_SQL_NAME(l_schema);
  SELECT COUNT(*) INTO l_count FROM DBA_USERS WHERE USERNAME = l_schema;
  IF l_count > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER ' || l_schema || ' CASCADE';
    DBMS_OUTPUT.PUT_LINE('Dropped schema ' || l_schema);
  END IF;
END;
/
