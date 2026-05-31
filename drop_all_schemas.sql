SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT

PROMPT ============================================================
PROMPT Dropping all Central Layer 2 Archive schema objects
PROMPT Run this script as a DBA user (e.g. SYS or SYSTEM).
PROMPT This will drop objects in CARCH, CAGENT1, and CLIENT1.
PROMPT ============================================================

SPOOL drop_all_schemas.log

PROMPT
PROMPT ============================================================
PROMPT Section 1: Dropping CARCH (layer 2 core) objects
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CARCH;

BEGIN
  -- packages (body first)
  FOR r IN (
    SELECT object_name, object_type
      FROM dba_objects
     WHERE owner = 'CARCH'
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND object_name IN (
         'PKG_ARCHIVE_RUNNER',
         'PKG_ARCHIVE_TRUNCATE',
         'PKG_ARCHIVE_QUALITY',
         'PKG_ARCHIVE_IMPORT',
         'PKG_ARCHIVE_DISCOVERY',
         'PKG_ARCHIVE_PARTITION',
         'PKG_ARCHIVE_LOG',
         'PKG_SQL',
         'PKG_TL_LOGGING',
         'PKG_DATE',
         'DAT'
       )
     ORDER BY object_type DESC
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' CARCH.' || r.object_name;
      DBMS_OUTPUT.PUT_LINE('Dropped ' || r.object_type || ' CARCH.' || r.object_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop ' || r.object_type || ' ' ||
                             r.object_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- function
  FOR r IN (
    SELECT object_name
      FROM dba_objects
     WHERE owner = 'CARCH'
       AND object_type = 'FUNCTION'
       AND object_name IN ('FN_ARCHIVE_HIGH_VALUE_DATE', 'FN_CALCULATE_RETENTION_RULE','FN_VALIDATE_PRESERVE_RULE')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP FUNCTION CARCH.' || r.object_name;
      DBMS_OUTPUT.PUT_LINE('Dropped FUNCTION CARCH.' || r.object_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop FUNCTION ' ||
                             r.object_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- trigger
  FOR r IN (
    SELECT trigger_name
      FROM dba_triggers
     WHERE owner = 'CARCH'
       AND trigger_name = 'TRG_ARCHIVE_TABLES_RETENTION_CALC'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TRIGGER CARCH.' || r.trigger_name;
      DBMS_OUTPUT.PUT_LINE('Dropped TRIGGER CARCH.' || r.trigger_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop TRIGGER ' ||
                             r.trigger_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- views
  FOR r IN (
    SELECT view_name
      FROM dba_views
     WHERE owner = 'CARCH'
       AND view_name LIKE 'TW\_ARCHIVE\_%' ESCAPE '\'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP VIEW CARCH.' || r.view_name;
      DBMS_OUTPUT.PUT_LINE('Dropped VIEW CARCH.' || r.view_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop VIEW ' ||
                             r.view_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- drop orphan staging tables
  FOR r IN (
    SELECT table_name
      FROM dba_tables
     WHERE owner = 'CARCH'
       AND table_name LIKE 'STG\_TMP\_ARCH\_%' ESCAPE '\'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE CARCH.' || r.table_name || ' PURGE';
      DBMS_OUTPUT.PUT_LINE('Dropped staging TABLE CARCH.' || r.table_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop staging TABLE ' ||
                             r.table_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- tables
  FOR r IN (
    SELECT table_name
      FROM dba_tables
     WHERE owner = 'CARCH'
       AND table_name IN (
         'TW_ARCHIVE_PARTITIONS',
         'TW_ARCHIVE_RUNS',
         'TW_ARCHIVE_TABLES',
         'MD_PROCESS_LOG',
          'ORDERS_ARCH_SRC',
          'ORDERS_SUBPART_SRC',
          'ORDERS_DAILY_INT_SRC',
          'ORDERS_ARCH_SRC_2',
          'ORDERS_SUBPART_SRC_2',
          'ORDERS_DAILY_INT_SRC_2'
        )
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE CARCH.' || r.table_name || ' PURGE';
      DBMS_OUTPUT.PUT_LINE('Dropped TABLE CARCH.' || r.table_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop TABLE ' ||
                             r.table_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- sequence
  FOR r IN (
    SELECT sequence_name
      FROM dba_sequences
     WHERE sequence_owner = 'CARCH'
        AND sequence_name IN ('MD_PROCESS_LOG_SEQ', 'STG_TMP_ARCH_SEQ')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP SEQUENCE CARCH.' || r.sequence_name;
      DBMS_OUTPUT.PUT_LINE('Dropped SEQUENCE CARCH.' || r.sequence_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop SEQUENCE ' ||
                             r.sequence_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- database link (must be connected as the owner to drop)
--  FOR r IN (
--    SELECT db_link
--      FROM dba_db_links
--     WHERE owner = 'CARCH'
--       AND db_link = 'CLIENT1_LOOPBACK_LINK'
--  ) LOOP
--    BEGIN
--      EXECUTE IMMEDIATE 'DROP DATABASE LINK CARCH.' || r.db_link;
--      DBMS_OUTPUT.PUT_LINE('Dropped DATABASE LINK CARCH.' || r.db_link);
--    EXCEPTION
--      WHEN OTHERS THEN
--        DBMS_OUTPUT.PUT_LINE('Could not drop DATABASE LINK ' ||
--                             r.db_link || ': ' || SQLERRM);
--    END;
--  END LOOP;
END;
/

PROMPT CARCH objects dropped.

PROMPT
PROMPT ============================================================
PROMPT Section 2: Revolving CLIENT1 grants
PROMPT ============================================================

BEGIN
  FOR r IN (
    SELECT owner, table_name, grantee, privilege
      FROM dba_tab_privs
     WHERE owner = 'CLIENT1'
       AND table_name IN ('ORDERS_ARCH_SRC', 'ORDERS_SUBPART_SRC', 'ORDERS_DAILY_INT_SRC')
       AND grantee IN ('CAGENT1', 'CARCH')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'REVOKE ' || r.privilege || ' ON CLIENT1.' ||
                        r.table_name || ' FROM ' || r.grantee;
      DBMS_OUTPUT.PUT_LINE('Revoked ' || r.privilege || ' ON CLIENT1.' ||
                           r.table_name || ' FROM ' || r.grantee);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not revoke: ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT CLIENT1 grants revoked.

PROMPT
PROMPT ============================================================
PROMPT Section 2b: Revoking CLIENT2 grants
PROMPT ============================================================

BEGIN
  FOR r IN (
    SELECT owner, table_name, grantee, privilege
      FROM dba_tab_privs
     WHERE owner = 'CLIENT2'
       AND table_name IN ('ORDERS_ARCH_SRC', 'ORDERS_SUBPART_SRC', 'ORDERS_DAILY_INT_SRC')
       AND grantee IN ('CAGENT1', 'CARCH')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'REVOKE ' || r.privilege || ' ON CLIENT2.' ||
                        r.table_name || ' FROM ' || r.grantee;
      DBMS_OUTPUT.PUT_LINE('Revoked ' || r.privilege || ' ON CLIENT2.' ||
                           r.table_name || ' FROM ' || r.grantee);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not revoke: ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT CLIENT2 grants revoked.

PROMPT
PROMPT ============================================================
PROMPT Section 3: Dropping CLIENT1 (source) objects
PROMPT ============================================================

BEGIN
  FOR r IN (
    SELECT table_name
      FROM dba_tables
     WHERE owner = 'CLIENT1'
       AND table_name IN ('ORDERS_ARCH_SRC', 'ORDERS_SUBPART_SRC', 'ORDERS_DAILY_INT_SRC')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE CLIENT1.' || r.table_name || ' PURGE';
      DBMS_OUTPUT.PUT_LINE('Dropped TABLE CLIENT1.' || r.table_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop TABLE ' ||
                             r.table_name || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT CLIENT1 objects dropped.

PROMPT
PROMPT ============================================================
PROMPT Section 3b: Dropping CLIENT2 (source) objects
PROMPT ============================================================

BEGIN
  FOR r IN (
    SELECT table_name
      FROM dba_tables
     WHERE owner = 'CLIENT2'
       AND table_name IN ('ORDERS_ARCH_SRC', 'ORDERS_SUBPART_SRC', 'ORDERS_DAILY_INT_SRC')
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE CLIENT2.' || r.table_name || ' PURGE';
      DBMS_OUTPUT.PUT_LINE('Dropped TABLE CLIENT2.' || r.table_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop TABLE ' ||
                             r.table_name || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT CLIENT2 objects dropped.

PROMPT
PROMPT ============================================================
PROMPT Section 4: Revoking CAGENT1 grants
PROMPT ============================================================

BEGIN
  FOR r IN (
    SELECT owner, table_name, grantee, privilege
      FROM dba_tab_privs
     WHERE owner = 'CAGENT1'
       AND grantee = 'CARCH'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'REVOKE ' || r.privilege || ' ON ' || r.owner || '.' ||
                        r.table_name || ' FROM ' || r.grantee;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
END;
/

BEGIN
  FOR r IN (
    SELECT grantee
      FROM dba_sys_privs
     WHERE grantee = 'CAGENT1'
       AND privilege = 'DROP ANY TABLE'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'REVOKE DROP ANY TABLE FROM CAGENT1';
      DBMS_OUTPUT.PUT_LINE('Revoked DROP ANY TABLE FROM CAGENT1');
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not revoke DROP ANY TABLE: ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT CAGENT1 grants revoked.

PROMPT
PROMPT ============================================================
PROMPT Section 5: Dropping CAGENT1 (layer 1 agent) objects
PROMPT ============================================================

BEGIN
  -- package body + spec
  FOR r IN (
    SELECT object_name, object_type
      FROM dba_objects
     WHERE owner = 'CAGENT1'
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND object_name = 'PKG_ARCHIVE_AGENT'
     ORDER BY object_type DESC
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' CAGENT1.' || r.object_name;
      DBMS_OUTPUT.PUT_LINE('Dropped ' || r.object_type || ' CAGENT1.' || r.object_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop ' || r.object_type || ' ' ||
                             r.object_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- view
  FOR r IN (
    SELECT view_name
      FROM dba_views
     WHERE owner = 'CAGENT1'
       AND view_name = 'ARCHIVE_PARTITION_INFO_VW'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP VIEW CAGENT1.' || r.view_name;
      DBMS_OUTPUT.PUT_LINE('Dropped VIEW CAGENT1.' || r.view_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop VIEW ' ||
                             r.view_name || ': ' || SQLERRM);
    END;
  END LOOP;

  -- types (tab first, then obj)
  FOR r IN (
    SELECT object_name
      FROM dba_objects
     WHERE owner = 'CAGENT1'
       AND object_type = 'TYPE'
       AND object_name IN (
         'ARCHIVE_PARTITION_INFO_TAB',
         'ARCHIVE_PARTITION_INFO_OBJ'
       )
     ORDER BY object_name DESC
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TYPE CAGENT1.' || r.object_name;
      DBMS_OUTPUT.PUT_LINE('Dropped TYPE CAGENT1.' || r.object_name);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not drop TYPE ' ||
                             r.object_name || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT CAGENT1 objects dropped.

PROMPT
PROMPT ============================================================
PROMPT All Central Layer 2 Archive objects have been dropped.
PROMPT Check drop_all_schemas.log for details.
PROMPT ============================================================

PROMPT
PROMPT ============================================================
PROMPT Remaining objects per schema:
PROMPT ============================================================
BEGIN
  FOR r IN (
    SELECT owner, object_type, COUNT(*) AS cnt
      FROM dba_objects
     WHERE owner IN ('CARCH','CAGENT1','CLIENT1','CLIENT2')
       AND object_name NOT LIKE 'SYS_P%'
       AND object_name NOT LIKE 'TMP$%'
     GROUP BY owner, object_type
     ORDER BY owner, object_type
  ) LOOP
    DBMS_OUTPUT.PUT_LINE('  ' || RPAD(r.owner, 10) || RPAD(r.object_type, 20) || r.cnt);
  END LOOP;

  FOR r IN (
    SELECT 'CARCH' AS owner, COUNT(*) AS cnt FROM dba_sequences WHERE sequence_owner = 'CARCH'
      AND sequence_name NOT LIKE 'ISEQ$$_%'
  ) LOOP
    IF r.cnt > 0 THEN
      DBMS_OUTPUT.PUT_LINE('  SEQUENCE     ' || r.cnt || ' remaining in CARCH');
    END IF;
  END LOOP;
END;
/

SELECT 'CARCH: ' || COUNT(*) || ' objects remaining' AS summary FROM dba_objects
 WHERE owner = 'CARCH'
   AND object_name NOT LIKE 'SYS_P%'
   AND object_name NOT LIKE 'TMP$%'
UNION ALL
SELECT 'CAGENT1: ' || COUNT(*) || ' objects remaining' FROM dba_objects
 WHERE owner = 'CAGENT1'
   AND object_name NOT LIKE 'SYS_P%'
   AND object_name NOT LIKE 'TMP$%'
UNION ALL
SELECT 'CLIENT1: ' || COUNT(*) || ' objects remaining' FROM dba_objects
 WHERE owner = 'CLIENT1'
   AND object_name NOT LIKE 'SYS_P%'
   AND object_name NOT LIKE 'TMP$%'
UNION ALL
SELECT 'CLIENT2: ' || COUNT(*) || ' objects remaining' FROM dba_objects
 WHERE owner = 'CLIENT2'
   AND object_name NOT LIKE 'SYS_P%'
   AND object_name NOT LIKE 'TMP$%';

SPOOL OFF

purge dba_recyclebin;

--set serveroutput on
--DECLARE
--  v_result CLOB;
--BEGIN
--  DBMS_SPACE.SHRINK_TABLESPACE(
--    ts_name       => 'USERS',
--    shrink_mode   => DBMS_SPACE.TS_MODE_SHRINK,
--    shrink_result => v_result
--  );
--  -- Opcjonalnie wyświetlamy raport z wykonanej operacji
--  DBMS_OUTPUT.PUT_LINE(v_result);
--END;
--/

commit;

select owner, object_name from dba_objects
where owner in ('CARCH', 'CAGENT1', 'CLIENT1', 'CLIENT2');
