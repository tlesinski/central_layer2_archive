SET DEFINE ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

@deploy/config/distributed_topology.local.sql

CONNECT PMGR_D_AGENT1/"DistAgent1Dev2026_42"@localhost:1521/freepdb1
SET SERVEROUTPUT ON
SELECT PKG_AGENT_ARCHIVE.fn_health_check AS agent1_health FROM dual;

CONNECT PMGR_D_AGENT2/"DistAgent2Dev2026_42"@localhost:1521/freepdb1
SET SERVEROUTPUT ON
SELECT PKG_AGENT_ARCHIVE.fn_health_check AS agent2_health FROM dual;

CONNECT &&DISTRIBUTED_ARCHIVER_SCHEMA/"&&DISTRIBUTED_ARCHIVER_PASSWORD"@&&DISTRIBUTED_ARCHIVER_CONNECT
SET SERVEROUTPUT ON
BEGIN
  PKG_ARCHIVER_RUNNER.prc_run_all
  (
    p_execute          => 'Y',
    p_stop_after_step  => 'TRUNCATE',
    p_truncate_execute => 'N'
  );
END;
/

SELECT source_db_link, COUNT(*) configured_tables
  FROM TBL_ARCHIVER_TABLES
 GROUP BY source_db_link
 ORDER BY source_db_link;

SELECT (SELECT COUNT(*) FROM TBL_ARCHIVER_ORDERS_SRC) agent1_rows,
       (SELECT COUNT(*) FROM TBL_ARCHIVER_ORDERS_SRC_2) agent2_rows
  FROM dual;

CONNECT &&DISTRIBUTED_REPLICA_SCHEMA/"&&DISTRIBUTED_REPLICA_PASSWORD"@&&DISTRIBUTED_REPLICA_CONNECT
SET SERVEROUTPUT ON
BEGIN
  PKG_REPLICA_RUNNER.prc_run
  (
    p_execute         => 'Y',
    p_stop_after_step => 'PURGE',
    p_purge_execute   => 'N'
  );
END;
/

DECLARE
  l_archiver_invalid PLS_INTEGER;
  l_replica_invalid  PLS_INTEGER;
  l_replica_rows     PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO l_replica_invalid FROM USER_OBJECTS WHERE status <> 'VALID';
  SELECT COUNT(*) INTO l_replica_rows FROM TBL_REPLICA_ORDERS_SRC;
  SELECT COUNT(*) INTO l_archiver_invalid
    FROM ALL_OBJECTS@DIST_ARCHIVER_LINK
   WHERE owner = 'PMGR_D_ARCHIVER'
     AND status <> 'VALID';

  IF l_archiver_invalid <> 0 OR l_replica_invalid <> 0 OR l_replica_rows <> 149 THEN
    RAISE_APPLICATION_ERROR(
      -20081,
      'Distributed smoke failed: archiver_invalid=' || l_archiver_invalid ||
      ' replica_invalid=' || l_replica_invalid || ' replica_rows=' || l_replica_rows
    );
  END IF;

  DBMS_OUTPUT.PUT_LINE('DISTRIBUTED_SMOKE_OK replica_rows=' || l_replica_rows);
END;
/
