WHENEVER SQLERROR EXIT SQL.SQLCODE
SET VERIFY OFF

DECLARE
  l_instance_key   VARCHAR2(128)  := TRIM(q'[&1]');
  l_connect_id     VARCHAR2(1000) := TRIM(q'[&2]');
  l_admin_user     VARCHAR2(128)  := TRIM(q'[&3]');
  l_admin_password VARCHAR2(1000) := q'[&4]';
  l_db_link        VARCHAR2(128)  := TRIM(q'[&5]');

  PROCEDURE assert_present
  (
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2
  )
  IS
  BEGIN
    IF p_value IS NULL THEN
      RAISE_APPLICATION_ERROR(-20110, p_name || ' must not be empty');
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
      RAISE_APPLICATION_ERROR(-20111, p_name || ' is not a valid Oracle identifier');
    END IF;
  END assert_simple_name;
BEGIN
  assert_simple_name('AGENT instance key', l_instance_key);
  assert_present('AGENT connect identifier', l_connect_id);
  assert_simple_name('AGENT admin user', l_admin_user);
  assert_present('AGENT admin password', l_admin_password);
  assert_simple_name('ARCHIVER-to-AGENT DB link', l_db_link);
  IF UPPER(l_db_link) IN ('LOCAL', 'NONE') THEN
    RAISE_APPLICATION_ERROR(-20112, 'ARCHIVER-to-AGENT DB link must identify a real DB link');
  END IF;

  DBMS_OUTPUT.PUT_LINE(
    'Validated AGENT instance ' || UPPER(l_instance_key) ||
    ' at ' || l_connect_id || ' using DB link ' || UPPER(l_db_link)
  );
END;
/
