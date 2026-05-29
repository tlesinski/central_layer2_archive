SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Seeding CLIENT2 loopback archive table configuration

MERGE INTO TW_ARCHIVE_TABLES dst
USING (
  SELECT 'CLIENT1_LOOPBACK_LINK' AS source_db_link,
         'CLIENT2' AS source_owner,
         'ORDERS_ARCH_SRC' AS source_table_name,
         'CAGENT1' AS source_agent_schema,
         'CARCH' AS target_owner,
         'ORDERS_ARCH_SRC_2' AS target_table_name,
         'TRUNCATE' AS truncate_mode,
         4 AS parallel_degree,
         'USERS' AS tablespace_name,
          NULL AS preserve_rule,
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
  dst.preserve_rule = src.preserve_rule,
  dst.enabled_flag = src.enabled_flag,
  dst.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT
  (source_db_link, source_owner, source_table_name, source_agent_schema,
   target_owner, target_table_name, truncate_mode, parallel_degree, tablespace_name,
   preserve_rule, enabled_flag)
VALUES
  (src.source_db_link, src.source_owner, src.source_table_name, src.source_agent_schema,
   src.target_owner, src.target_table_name, src.truncate_mode, src.parallel_degree, src.tablespace_name,
   src.preserve_rule, src.enabled_flag);

MERGE INTO TW_ARCHIVE_PARTITIONS dst
USING (
  SELECT 'CLIENT1_LOOPBACK_LINK' AS source_db_link,
         'CLIENT2' AS source_owner,
         'ORDERS_ARCH_SRC' AS source_table_name,
         'CARCH' AS target_owner,
         'ORDERS_ARCH_SRC_2' AS target_table_name,
         'PARTITION' AS archive_unit_type,
         'P_ERROR' AS source_partition_name,
         '#' AS source_subpartition_name,
         'P_ERROR' AS partition_name,
         '#' AS subpartition_name,
         'TO_DATE('' 1800-01-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')' AS partition_high_value,
          '#' AS subpartition_high_value,
          NULL AS prev_partition_high_value
    FROM dual
) src
ON (
  dst.source_db_link = src.source_db_link
  AND dst.source_owner = src.source_owner
  AND dst.source_table_name = src.source_table_name
  AND dst.partition_high_value = src.partition_high_value
  AND dst.subpartition_high_value = src.subpartition_high_value
)
WHEN MATCHED THEN UPDATE SET
  dst.target_owner = src.target_owner,
  dst.target_table_name = src.target_table_name,
  dst.archive_unit_type = src.archive_unit_type,
  dst.source_partition_name = src.source_partition_name,
  dst.source_subpartition_name = src.source_subpartition_name,
  dst.prev_partition_high_value = src.prev_partition_high_value,
  dst.archive_status = 'Y',
  dst.quality_status = 'Y',
  dst.truncate_status = 'Y',
  dst.source_row_count = 0,
  dst.target_row_count = 0,
  dst.error_message = NULL,
  dst.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT
  (source_db_link, source_owner, source_table_name, target_owner, target_table_name,
   archive_unit_type, source_partition_name, source_subpartition_name, partition_name, subpartition_name,
   partition_high_value, subpartition_high_value,
   prev_partition_high_value, archive_status, quality_status,
   truncate_status, source_row_count, target_row_count)
VALUES
  (src.source_db_link, src.source_owner, src.source_table_name, src.target_owner, src.target_table_name,
   src.archive_unit_type, src.source_partition_name, src.source_subpartition_name, src.partition_name, src.subpartition_name,
   src.partition_high_value, src.subpartition_high_value,
   src.prev_partition_high_value, 'Y', 'Y',
   'Y', 0, 0);

COMMIT;

PROMPT CLIENT2 loopback archive table configuration seeded
