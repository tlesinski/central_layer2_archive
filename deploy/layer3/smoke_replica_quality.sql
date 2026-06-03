SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100

PROMPT Running Layer 3 replica quality smoke test

BEGIN
  PKG_REPLICA_QUALITY.prc_quality
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

SELECT source_table_name,
       archive_unit_type,
       replica_status,
       quality_status,
       purge_status,
       COUNT(*) AS cnt,
       SUM(NVL(source_row_count, 0)) AS source_rows,
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

SELECT COUNT(*) AS quality_candidates
  FROM tw_replica_quality_partitions_vw;

PROMPT Layer 3 replica quality smoke test completed
