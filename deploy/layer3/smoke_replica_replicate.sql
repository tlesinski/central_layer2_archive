SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100

PROMPT Running Layer 3 replica replicate smoke test

BEGIN
  PKG_REPLICA_REPLICATE.prc_replicate
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

PROMPT
PROMPT ============================================================
PROMPT Replica metadata counts after replicate
PROMPT ============================================================

SELECT source_table_name,
       archive_unit_type,
       replica_status,
       quality_status,
       purge_status,
       COUNT(*) AS cnt,
       SUM(NVL(target_row_count, 0)) AS target_rows
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
PROMPT Remaining replicate candidates should be 0
PROMPT ============================================================

SELECT COUNT(*) AS replicate_candidates
  FROM tw_replica_replicate_partitions_vw;

PROMPT
PROMPT ============================================================
PROMPT Target row counts
PROMPT ============================================================

SELECT 'ORDERS_ARCH_SRC' AS table_name,
       COUNT(*) AS target_rows
  FROM orders_arch_src
UNION ALL
SELECT 'ORDERS_SUBPART_SRC',
       COUNT(*)
  FROM orders_subpart_src;

PROMPT Layer 3 replica replicate smoke test completed
