SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100

PROMPT Running Layer 3 replica purge preview smoke test

BEGIN
  PKG_REPLICA_PURGE.prc_purge
  (
    p_execute => 'N'
  );
END;
/

COLUMN SOURCE_TABLE_NAME FORMAT A24
COLUMN ARCHIVE_UNIT_TYPE FORMAT A14
COLUMN REPLICA_STATUS FORMAT A6
COLUMN QUALITY_STATUS FORMAT A6
COLUMN PURGE_STATUS FORMAT A6

SELECT COUNT(*) AS purge_candidates
  FROM tw_replica_purge_partitions_vw;

SELECT source_table_name,
       archive_unit_type,
       replica_status,
       quality_status,
       purge_status,
       COUNT(*) AS cnt
  FROM tw_replica_partitions
 GROUP BY source_table_name,
          archive_unit_type,
          replica_status,
          quality_status,
          purge_status
 ORDER BY source_table_name,
          archive_unit_type,
          replica_status,
          quality_status,
          purge_status;

PROMPT Layer 3 replica purge preview smoke test completed
