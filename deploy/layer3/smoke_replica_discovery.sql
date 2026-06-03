SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100

PROMPT Running Layer 3 replica discovery smoke test

BEGIN
  PKG_REPLICA_DISCOVERY.prc_discover
  (
    p_execute => 'Y'
  );
END;
/

COLUMN SOURCE_TABLE_NAME FORMAT A24
COLUMN ARCHIVE_UNIT_TYPE FORMAT A14
COLUMN REPLICA_STATUS FORMAT A6
COLUMN QUALITY_STATUS FORMAT A6
COLUMN PURGE_STATUS FORMAT A6
COLUMN SOURCE_PARTITION_NAME FORMAT A16
COLUMN SOURCE_SUBPARTITION_NAME FORMAT A24
COLUMN PARTITION_NAME FORMAT A16
COLUMN SUBPARTITION_NAME FORMAT A24

PROMPT
PROMPT ============================================================
PROMPT Replica metadata counts
PROMPT ============================================================

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

PROMPT
PROMPT ============================================================
PROMPT Remaining discovery candidates should be 0
PROMPT ============================================================

SELECT COUNT(*) AS discovery_candidates
  FROM tw_replica_discovery_partitions_vw;

PROMPT
PROMPT ============================================================
PROMPT Replicate candidates after discovery
PROMPT ============================================================

SELECT source_table_name,
       archive_unit_type,
       COUNT(*) AS replicate_candidates
  FROM tw_replica_replicate_partitions_vw
 GROUP BY source_table_name,
          archive_unit_type
 ORDER BY source_table_name,
          archive_unit_type;

PROMPT
PROMPT ============================================================
PROMPT Sample replica metadata
PROMPT ============================================================

SELECT source_table_name,
       archive_unit_type,
       source_partition_name,
       source_subpartition_name,
       partition_name,
       subpartition_name,
       replica_status,
       quality_status,
       purge_status
  FROM tw_replica_partitions
 ORDER BY source_table_name,
          partition_high_value,
          subpartition_high_value
 FETCH FIRST 30 ROWS ONLY;

PROMPT Layer 3 replica discovery smoke test completed
