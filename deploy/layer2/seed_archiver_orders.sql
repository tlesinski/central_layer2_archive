SET DEFINE ON
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

MERGE INTO TBL_ARCHIVER_TABLES dst
USING (
  SELECT UPPER('&1') AS source_db_link,
         'CLIENT1' AS source_owner,
         'ORDERS_ARCH_SRC' AS source_table_name,
         UPPER('&&APPLICATION_SCHEMA') AS source_agent_schema,
         UPPER('&&APPLICATION_SCHEMA') AS target_owner,
         'TBL_ARCHIVER_ORDERS_SRC' AS target_table_name,
         'TRUNCATE' AS truncate_mode,
         4 AS parallel_degree,
         UPPER('&&DEFAULT_TABLESPACE') AS tablespace_name,
         'DATE ''2026-06-01''' AS last_business_date,
         30 AS days_online,
         'Y' AS enabled_flag
    FROM dual
) src
ON (
  dst.source_db_link = src.source_db_link
  AND dst.source_owner = src.source_owner
  AND dst.source_table_name = src.source_table_name
)
WHEN MATCHED THEN UPDATE SET
  dst.source_agent_schema = src.source_agent_schema,
  dst.target_owner = src.target_owner,
  dst.target_table_name = src.target_table_name,
  dst.truncate_mode = src.truncate_mode,
  dst.parallel_degree = src.parallel_degree,
  dst.tablespace_name = src.tablespace_name,
  dst.last_business_date = src.last_business_date,
  dst.days_online = src.days_online,
  dst.preserve_rule = NULL,
  dst.enabled_flag = src.enabled_flag,
  dst.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT
  (source_db_link, source_owner, source_table_name, source_agent_schema,
   target_owner, target_table_name, truncate_mode, parallel_degree,
   tablespace_name, last_business_date, days_online, enabled_flag)
VALUES
  (src.source_db_link, src.source_owner, src.source_table_name, src.source_agent_schema,
   src.target_owner, src.target_table_name, src.truncate_mode, src.parallel_degree,
   src.tablespace_name, src.last_business_date, src.days_online, src.enabled_flag);

INSERT INTO TBL_ARCHIVER_PARTITIONS
(
  source_db_link, source_owner, source_table_name, target_owner, target_table_name,
  archive_unit_type, source_partition_name, source_subpartition_name,
  partition_name, subpartition_name, partition_high_value, subpartition_high_value,
  archive_status, quality_status, truncate_status, source_row_count, target_row_count
)
SELECT UPPER('&1'), 'CLIENT1', 'ORDERS_ARCH_SRC', UPPER('&&APPLICATION_SCHEMA'), 'TBL_ARCHIVER_ORDERS_SRC',
       'PARTITION', 'P_ERROR', '#', 'P_ERROR', '#',
       'TO_DATE('' 1800-01-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')',
       '#', 'Y', 'Y', 'Y', 0, 0
  FROM dual
 WHERE NOT EXISTS (
   SELECT 1
     FROM TBL_ARCHIVER_PARTITIONS
    WHERE source_db_link = UPPER('&1')
      AND source_owner = 'CLIENT1'
      AND source_table_name = 'ORDERS_ARCH_SRC'
      AND partition_name = 'P_ERROR'
 );

COMMIT;
