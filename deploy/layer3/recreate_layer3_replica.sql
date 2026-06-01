SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Recreating Central Layer 3 Replica core objects

BEGIN
  FOR r IN (
    SELECT object_name, object_type
      FROM user_objects
     WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
       AND object_name IN
       (
        'PKG_REPLICA_RUNNER',
          'PKG_REPLICA_PURGE',
          'PKG_REPLICA_QUALITY',
          'PKG_REPLICA_REPLICATE',
          'PKG_REPLICA_PARTITION',
          'PKG_REPLICA_DISCOVERY',
          'PKG_REPLICA_LOG',
          'PKG_SQL',
          'PKG_TL_LOGGING'
       )
     ORDER BY object_type DESC
  ) LOOP
    EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' ' || r.object_name;
  END LOOP;

  FOR r IN (
    SELECT view_name
      FROM user_views
     WHERE view_name LIKE 'TW\_REPLICA\_%' ESCAPE '\'
     ORDER BY CASE view_name
                WHEN 'TW_REPLICA_PURGE_PARTITIONS_VW' THEN 1
                WHEN 'TW_REPLICA_QUALITY_PARTITIONS_VW' THEN 2
                WHEN 'TW_REPLICA_REPLICATE_PARTITIONS_VW' THEN 3
                WHEN 'TW_REPLICA_DISCOVERY_PARTITIONS_VW' THEN 4
                WHEN 'TW_REPLICA_SOURCE_PARTITIONS_VW' THEN 5
                ELSE 9
              END
  ) LOOP
    EXECUTE IMMEDIATE 'DROP VIEW ' || r.view_name;
  END LOOP;

  FOR r IN (
    SELECT table_name
      FROM user_tables
     WHERE table_name IN
       (
         'TW_REPLICA_PARTITIONS',
         'TW_REPLICA_RUNS',
         'TW_REPLICA_TABLES',
         'MD_PROCESS_LOG'
       )
     ORDER BY CASE table_name
                WHEN 'TW_REPLICA_PARTITIONS' THEN 1
                WHEN 'TW_REPLICA_RUNS' THEN 2
                WHEN 'TW_REPLICA_TABLES' THEN 3
                WHEN 'MD_PROCESS_LOG' THEN 4
                ELSE 9
              END
  ) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' PURGE';
  END LOOP;

  FOR r IN (
    SELECT sequence_name
      FROM user_sequences
      WHERE sequence_name IN ('MD_PROCESS_LOG_SEQ', 'STG_TMP_REPLICA_SEQ')
  ) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.sequence_name;
  END LOOP;

  FOR r IN (
    SELECT object_name
      FROM user_objects
     WHERE object_type = 'FUNCTION'
       AND object_name = 'FN_ARCHIVE_HIGH_VALUE_DATE'
  ) LOOP
    EXECUTE IMMEDIATE 'DROP FUNCTION ' || r.object_name;
  END LOOP;

  FOR r IN (
    SELECT synonym_name
      FROM user_synonyms
     WHERE synonym_name IN
       (
         'TW_ARCHIVE_TABLES',
         'TW_ARCHIVE_PARTITIONS',
         'ORDERS_ARCH_SRC_L2',
         'ORDERS_SUBPART_SRC_L2'
       )
  ) LOOP
    EXECUTE IMMEDIATE 'DROP SYNONYM ' || r.synonym_name;
  END LOOP;
END;
/

@deploy/layer3/install_layer3_replica.sql

PROMPT Central Layer 3 Replica core recreate completed
