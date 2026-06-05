SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

@@validate_config.sql

COLUMN source_mail_schema NEW_VALUE SOURCE_MAIL_SCHEMA NOPRINT
COLUMN archiver_mail_schema NEW_VALUE ARCHIVER_MAIL_SCHEMA NOPRINT
COLUMN replica_mail_schema NEW_VALUE REPLICA_MAIL_SCHEMA NOPRINT

SELECT CASE UPPER(TRIM('&&INSTALL_MODEL'))
         WHEN 'SHARED' THEN UPPER('&&SHARED_SCHEMA')
         ELSE '__SKIP__'
       END source_mail_schema,
       CASE UPPER(TRIM('&&INSTALL_MODEL'))
         WHEN 'SPLIT' THEN UPPER('&&ARCHIVER_SCHEMA')
         ELSE '__SKIP__'
       END archiver_mail_schema,
       CASE UPPER(TRIM('&&INSTALL_MODEL'))
         WHEN 'SPLIT' THEN UPPER('&&REPLICA_SCHEMA')
         ELSE '__SKIP__'
       END replica_mail_schema
  FROM dual;

PROMPT Configuring mail ACL on SOURCE database
CONNECT SYS/"&&SOURCE_SYS_PASSWORD"@&&SOURCE_SYS_CONNECT AS SYSDBA

DECLARE
  l_host      VARCHAR2(256) := LOWER(TRIM(q'[&&MAIL_SMTP_HOST]'));
  l_port      PLS_INTEGER := TO_NUMBER(TRIM(q'[&&MAIL_SMTP_PORT]'));
  l_principal VARCHAR2(128) := UPPER(TRIM(q'[&&SOURCE_MAIL_SCHEMA]'));

  FUNCTION ace_exists
  (
    p_privilege IN VARCHAR2,
    p_lower_port IN NUMBER,
    p_upper_port IN NUMBER
  ) RETURN BOOLEAN
  IS
    l_count PLS_INTEGER;
  BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM DBA_HOST_ACES
     WHERE UPPER(HOST) = UPPER(l_host)
       AND UPPER(PRINCIPAL) = l_principal
       AND UPPER(PRIVILEGE) = UPPER(p_privilege)
       AND ((LOWER_PORT IS NULL AND p_lower_port IS NULL) OR LOWER_PORT = p_lower_port)
       AND ((UPPER_PORT IS NULL AND p_upper_port IS NULL) OR UPPER_PORT = p_upper_port);

    RETURN l_count > 0;
  END ace_exists;

  PROCEDURE append_ace
  (
    p_privilege IN VARCHAR2,
    p_lower_port IN NUMBER,
    p_upper_port IN NUMBER
  ) IS
  BEGIN
    IF NOT ace_exists(p_privilege, p_lower_port, p_upper_port) THEN
      DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => l_host,
        lower_port => p_lower_port,
        upper_port => p_upper_port,
        ace        => XS$ACE_TYPE(
          privilege_list => XS$NAME_LIST(p_privilege),
          principal_name => l_principal,
          principal_type => XS_ACL.PTYPE_DB
        )
      );
      DBMS_OUTPUT.PUT_LINE('Granted ' || p_privilege || ' on ' || l_host || ' to ' || l_principal);
    ELSE
      DBMS_OUTPUT.PUT_LINE('ACL already has ' || p_privilege || ' on ' || l_host || ' for ' || l_principal);
    END IF;
  END append_ace;
BEGIN
  IF l_principal = '__SKIP__' THEN
    DBMS_OUTPUT.PUT_LINE('SOURCE mail ACL skipped for install model &&INSTALL_MODEL');
    RETURN;
  END IF;

  append_ace('connect', l_port, l_port);
  append_ace('resolve', NULL, NULL);
END;
/

PROMPT Configuring mail ACL on ARCHIVER database
CONNECT SYS/"&&ARCHIVER_SYS_PASSWORD"@&&ARCHIVER_SYS_CONNECT AS SYSDBA

DECLARE
  l_host      VARCHAR2(256) := LOWER(TRIM(q'[&&MAIL_SMTP_HOST]'));
  l_port      PLS_INTEGER := TO_NUMBER(TRIM(q'[&&MAIL_SMTP_PORT]'));
  l_principal VARCHAR2(128) := UPPER(TRIM(q'[&&ARCHIVER_MAIL_SCHEMA]'));

  FUNCTION ace_exists
  (
    p_privilege IN VARCHAR2,
    p_lower_port IN NUMBER,
    p_upper_port IN NUMBER
  ) RETURN BOOLEAN
  IS
    l_count PLS_INTEGER;
  BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM DBA_HOST_ACES
     WHERE UPPER(HOST) = UPPER(l_host)
       AND UPPER(PRINCIPAL) = l_principal
       AND UPPER(PRIVILEGE) = UPPER(p_privilege)
       AND ((LOWER_PORT IS NULL AND p_lower_port IS NULL) OR LOWER_PORT = p_lower_port)
       AND ((UPPER_PORT IS NULL AND p_upper_port IS NULL) OR UPPER_PORT = p_upper_port);

    RETURN l_count > 0;
  END ace_exists;

  PROCEDURE append_ace
  (
    p_privilege IN VARCHAR2,
    p_lower_port IN NUMBER,
    p_upper_port IN NUMBER
  ) IS
  BEGIN
    IF NOT ace_exists(p_privilege, p_lower_port, p_upper_port) THEN
      DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => l_host,
        lower_port => p_lower_port,
        upper_port => p_upper_port,
        ace        => XS$ACE_TYPE(
          privilege_list => XS$NAME_LIST(p_privilege),
          principal_name => l_principal,
          principal_type => XS_ACL.PTYPE_DB
        )
      );
      DBMS_OUTPUT.PUT_LINE('Granted ' || p_privilege || ' on ' || l_host || ' to ' || l_principal);
    ELSE
      DBMS_OUTPUT.PUT_LINE('ACL already has ' || p_privilege || ' on ' || l_host || ' for ' || l_principal);
    END IF;
  END append_ace;
BEGIN
  IF l_principal = '__SKIP__' THEN
    DBMS_OUTPUT.PUT_LINE('ARCHIVER mail ACL skipped for install model &&INSTALL_MODEL');
    RETURN;
  END IF;

  append_ace('connect', l_port, l_port);
  append_ace('resolve', NULL, NULL);
END;
/

PROMPT Configuring mail ACL on REPLICA database
CONNECT SYS/"&&REPLICA_SYS_PASSWORD"@&&REPLICA_SYS_CONNECT AS SYSDBA

DECLARE
  l_host      VARCHAR2(256) := LOWER(TRIM(q'[&&MAIL_SMTP_HOST]'));
  l_port      PLS_INTEGER := TO_NUMBER(TRIM(q'[&&MAIL_SMTP_PORT]'));
  l_principal VARCHAR2(128) := UPPER(TRIM(q'[&&REPLICA_MAIL_SCHEMA]'));

  FUNCTION ace_exists
  (
    p_privilege IN VARCHAR2,
    p_lower_port IN NUMBER,
    p_upper_port IN NUMBER
  ) RETURN BOOLEAN
  IS
    l_count PLS_INTEGER;
  BEGIN
    SELECT COUNT(*)
      INTO l_count
      FROM DBA_HOST_ACES
     WHERE UPPER(HOST) = UPPER(l_host)
       AND UPPER(PRINCIPAL) = l_principal
       AND UPPER(PRIVILEGE) = UPPER(p_privilege)
       AND ((LOWER_PORT IS NULL AND p_lower_port IS NULL) OR LOWER_PORT = p_lower_port)
       AND ((UPPER_PORT IS NULL AND p_upper_port IS NULL) OR UPPER_PORT = p_upper_port);

    RETURN l_count > 0;
  END ace_exists;

  PROCEDURE append_ace
  (
    p_privilege IN VARCHAR2,
    p_lower_port IN NUMBER,
    p_upper_port IN NUMBER
  ) IS
  BEGIN
    IF NOT ace_exists(p_privilege, p_lower_port, p_upper_port) THEN
      DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => l_host,
        lower_port => p_lower_port,
        upper_port => p_upper_port,
        ace        => XS$ACE_TYPE(
          privilege_list => XS$NAME_LIST(p_privilege),
          principal_name => l_principal,
          principal_type => XS_ACL.PTYPE_DB
        )
      );
      DBMS_OUTPUT.PUT_LINE('Granted ' || p_privilege || ' on ' || l_host || ' to ' || l_principal);
    ELSE
      DBMS_OUTPUT.PUT_LINE('ACL already has ' || p_privilege || ' on ' || l_host || ' for ' || l_principal);
    END IF;
  END append_ace;
BEGIN
  IF l_principal = '__SKIP__' THEN
    DBMS_OUTPUT.PUT_LINE('REPLICA mail ACL skipped for install model &&INSTALL_MODEL');
    RETURN;
  END IF;

  append_ace('connect', l_port, l_port);
  append_ace('resolve', NULL, NULL);
END;
/

COMMIT;

PROMPT Mail ACL configuration completed
