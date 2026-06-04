SET DEFINE ON
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

DECLARE
  l_db_link_count PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_db_link_count
    FROM USER_DB_LINKS
   WHERE DB_LINK = UPPER('&1');

  IF l_db_link_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20061, 'Configured REPLICA source DB link does not exist: &1');
  END IF;
END;
/

MERGE INTO TBL_REPLICA_TABLES dst
USING (
  SELECT UPPER('&1') AS source_db_link,
         UPPER('&&APPLICATION_SCHEMA') AS source_owner,
         'TBL_ARCHIVER_ORDERS_SRC' AS source_table_name,
         UPPER('&&APPLICATION_SCHEMA') AS target_owner,
         'TBL_REPLICA_ORDERS_SRC' AS target_table_name,
         4 AS parallel_degree,
         UPPER('&&DEFAULT_TABLESPACE') AS tablespace_name,
         365 AS days_online,
         'Y' AS enabled_flag
    FROM dual
) src
ON (
  dst.source_db_link = src.source_db_link
  AND dst.source_owner = src.source_owner
  AND dst.source_table_name = src.source_table_name
)
WHEN MATCHED THEN UPDATE SET
  dst.target_owner = src.target_owner,
  dst.target_table_name = src.target_table_name,
  dst.parallel_degree = src.parallel_degree,
  dst.tablespace_name = src.tablespace_name,
  dst.days_online = src.days_online,
  dst.enabled_flag = src.enabled_flag,
  dst.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT
  (source_db_link, source_owner, source_table_name, target_owner, target_table_name,
   parallel_degree, tablespace_name, days_online, enabled_flag)
VALUES
  (src.source_db_link, src.source_owner, src.source_table_name, src.target_owner, src.target_table_name,
   src.parallel_degree, src.tablespace_name, src.days_online, src.enabled_flag);

INSERT INTO TBL_REPLICA_PARTITIONS
(
  source_db_link, source_owner, source_table_name, target_owner, target_table_name,
  archive_unit_type, source_partition_name, source_subpartition_name,
  partition_name, subpartition_name, partition_high_value, subpartition_high_value,
  replica_status, quality_status, purge_status, source_row_count, target_row_count
)
SELECT UPPER('&1'), UPPER('&&APPLICATION_SCHEMA'), 'TBL_ARCHIVER_ORDERS_SRC',
       UPPER('&&APPLICATION_SCHEMA'), 'TBL_REPLICA_ORDERS_SRC',
       'PARTITION', 'P_ERROR', '#', 'P_ERROR', '#',
       'TO_DATE('' 1800-01-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')',
       '#', 'Y', 'Y', 'Y', 0, 0
  FROM dual
 WHERE NOT EXISTS (
   SELECT 1
     FROM TBL_REPLICA_PARTITIONS
    WHERE source_db_link = UPPER('&1')
      AND source_owner = UPPER('&&APPLICATION_SCHEMA')
      AND source_table_name = 'TBL_ARCHIVER_ORDERS_SRC'
      AND partition_name = 'P_ERROR'
 );

COMMIT;
