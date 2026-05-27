SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Recreating Central Layer 2 Archive core objects

BEGIN
  FOR r IN (
    SELECT object_name, object_type
      FROM user_objects
     WHERE object_name IN (
       'PKG_ARCHIVE_RUNNER',
       'PKG_ARCHIVE_TRUNCATE',
       'PKG_ARCHIVE_CLEANUP',
       'PKG_ARCHIVE_QUALITY',
       'PKG_ARCHIVE_IMPORT',
       'PKG_ARCHIVE_SOURCE_COUNT',
       'PKG_ARCHIVE_PLAN',
       'PKG_ARCHIVE_DISCOVERY',
       'PKG_ARCHIVE_PARTITION',
       'PKG_ARCHIVE_LOG',
       'PKG_SQL',
       'PKG_TL_LOGGING'
     )
       AND object_type IN ('PACKAGE', 'PACKAGE BODY')
     ORDER BY CASE object_type WHEN 'PACKAGE BODY' THEN 1 ELSE 2 END
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' ' || r.object_name;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -4043 THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  FOR r IN (
    SELECT table_name
      FROM user_tables
     WHERE table_name IN (
       'TW_ARCHIVE_PARTITIONS',
       'TW_ARCHIVE_RUNS',
       'TW_ARCHIVE_TABLES',
       'TW_ARCHIVE_SOURCES',
       'MD_PROCESS_LOG',
       'ORDERS_ARCH_SRC',
       'ORDERS_SUBPART_SRC',
       'ORDERS_ARCHIVE',
       'ORDERS_SUBPART_ARCHIVE'
     )
     ORDER BY CASE table_name
                WHEN 'TW_ARCHIVE_PARTITIONS' THEN 1
                WHEN 'TW_ARCHIVE_RUNS' THEN 2
                WHEN 'TW_ARCHIVE_TABLES' THEN 3
                WHEN 'TW_ARCHIVE_SOURCES' THEN 4
                WHEN 'ORDERS_ARCH_SRC' THEN 5
                WHEN 'ORDERS_SUBPART_SRC' THEN 6
                WHEN 'ORDERS_ARCHIVE' THEN 7
                WHEN 'ORDERS_SUBPART_ARCHIVE' THEN 8
                ELSE 6
              END
  ) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' PURGE';
  END LOOP;

  FOR r IN (
    SELECT sequence_name
      FROM user_sequences
     WHERE sequence_name = 'MD_PROCESS_LOG_SEQ'
  ) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.sequence_name;
  END LOOP;
END;
/

@@install_layer2_core.sql

PROMPT Central Layer 2 Archive core objects recreated
