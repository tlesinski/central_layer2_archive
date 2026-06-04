SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100

PROMPT Running Layer 3 replica runner smoke test

PROMPT Verifying Layer 3 DB link configuration

SELECT * FROM dual@CARCH_LOOPBACK_LINK;

DECLARE
  l_bad_links NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO l_bad_links
    FROM TW_REPLICA_TABLES
   WHERE SOURCE_DB_LINK IS NULL
      OR UPPER(TRIM(SOURCE_DB_LINK)) IN ('LOCAL', 'NONE');

  DBMS_OUTPUT.PUT_LINE('Invalid replica source DB links: ' || l_bad_links);
  IF l_bad_links != 0 THEN
    RAISE_APPLICATION_ERROR(-20310, 'TW_REPLICA_TABLES contains non-DB-link SOURCE_DB_LINK values');
  END IF;
END;
/

BEGIN
  PKG_REPLICA_RUNNER.prc_run
  (
    p_execute         => 'Y',
    p_stop_after_step => 'QUALITY',
    p_purge_execute   => 'N'
  );
END;
/

SELECT COUNT(*) AS discovery_candidates
  FROM tw_replica_discovery_partitions_vw;

SELECT COUNT(*) AS replicate_candidates
  FROM tw_replica_replicate_partitions_vw;

SELECT COUNT(*) AS quality_candidates
  FROM tw_replica_quality_partitions_vw;

PROMPT Layer 3 replica runner smoke test completed
