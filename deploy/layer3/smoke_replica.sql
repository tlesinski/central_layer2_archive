SET DEFINE ON
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

SELECT * FROM dual@&1;

BEGIN
  PKG_REPLICA_RUNNER.prc_run
  (
    p_execute         => 'Y',
    p_stop_after_step => 'PURGE',
    p_purge_execute   => 'N'
  );
END;
/

SELECT COUNT(*) AS target_rows
  FROM TBL_REPLICA_ORDERS_SRC;

SELECT COUNT(*) AS quality_failures
  FROM TBL_REPLICA_PARTITIONS
 WHERE source_db_link = UPPER('&1')
   AND replica_status = 'Y'
   AND quality_status <> 'Y';

SELECT COUNT(*) AS invalid_source_links
  FROM TBL_REPLICA_TABLES
 WHERE source_db_link IS NULL
    OR UPPER(TRIM(source_db_link)) IN ('LOCAL', 'NONE')
    OR NOT EXISTS (
         SELECT 1
           FROM USER_DB_LINKS l
          WHERE l.DB_LINK = UPPER(TRIM(TBL_REPLICA_TABLES.source_db_link))
       );

DECLARE
  l_quality_failures     PLS_INTEGER;
  l_invalid_source_links PLS_INTEGER;
  l_invalid_run_links    PLS_INTEGER;
  l_invalid_objects      PLS_INTEGER;
  l_target_rows          PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_quality_failures
    FROM TBL_REPLICA_PARTITIONS
   WHERE source_db_link = UPPER('&1')
     AND replica_status = 'Y'
     AND quality_status <> 'Y';

  SELECT COUNT(*)
    INTO l_invalid_source_links
    FROM TBL_REPLICA_TABLES t
   WHERE t.source_db_link IS NULL
      OR UPPER(TRIM(t.source_db_link)) IN ('LOCAL', 'NONE')
      OR NOT EXISTS (
           SELECT 1
             FROM USER_DB_LINKS l
            WHERE l.DB_LINK = UPPER(TRIM(t.source_db_link))
         );

  SELECT COUNT(*)
    INTO l_invalid_run_links
    FROM TBL_REPLICA_RUNS r
   WHERE r.source_db_link IS NULL
      OR UPPER(TRIM(r.source_db_link)) IN ('LOCAL', 'NONE')
      OR NOT EXISTS (
           SELECT 1
             FROM USER_DB_LINKS l
            WHERE l.DB_LINK = UPPER(TRIM(r.source_db_link))
         );

  SELECT COUNT(*)
    INTO l_invalid_objects
    FROM USER_OBJECTS
   WHERE status <> 'VALID';

  SELECT COUNT(*)
    INTO l_target_rows
    FROM TBL_REPLICA_ORDERS_SRC;

  IF l_quality_failures <> 0 THEN
    RAISE_APPLICATION_ERROR(-20062, 'REPLICA smoke quality failures: ' || l_quality_failures);
  ELSIF l_invalid_source_links <> 0 THEN
    RAISE_APPLICATION_ERROR(-20063, 'REPLICA smoke invalid source DB links: ' || l_invalid_source_links);
  ELSIF l_invalid_run_links <> 0 THEN
    RAISE_APPLICATION_ERROR(-20066, 'REPLICA smoke invalid run DB links: ' || l_invalid_run_links);
  ELSIF l_invalid_objects <> 0 THEN
    RAISE_APPLICATION_ERROR(-20064, 'REPLICA smoke invalid objects: ' || l_invalid_objects);
  ELSIF l_target_rows = 0 THEN
    RAISE_APPLICATION_ERROR(-20065, 'REPLICA smoke target is empty');
  END IF;

  DBMS_OUTPUT.PUT_LINE('REPLICA_SMOKE_OK target_rows=' || l_target_rows);
END;
/
