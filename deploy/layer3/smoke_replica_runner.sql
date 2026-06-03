SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100

PROMPT Running Layer 3 replica runner smoke test

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
