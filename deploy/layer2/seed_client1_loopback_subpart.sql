SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Seeding CLIENT1_LOOPBACK_LINK subpartitioned archive table configuration

MERGE INTO TW_ARCHIVE_TABLES dst
USING (
  SELECT 'CLIENT1_LOOPBACK_LINK' AS source_db_link,
         'CLIENT1' AS source_owner,
         'ORDERS_SUBPART_SRC' AS source_table_name,
         'CAGENT1' AS source_agent_schema,
         'CARCH' AS target_owner,
         'ORDERS_SUBPART_SRC' AS target_table_name,
         'TRUNCATE' AS truncate_mode,
         90 AS retention_days,
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
  dst.retention_days = src.retention_days,
  dst.enabled_flag = src.enabled_flag,
  dst.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT
  (source_db_link, source_owner, source_table_name, source_agent_schema,
   target_owner, target_table_name, truncate_mode, retention_days, enabled_flag)
VALUES
  (src.source_db_link, src.source_owner, src.source_table_name, src.source_agent_schema,
   src.target_owner, src.target_table_name, src.truncate_mode, src.retention_days, src.enabled_flag);

MERGE INTO TW_ARCHIVE_PARTITIONS dst
USING (
  SELECT 'CLIENT1_LOOPBACK_LINK' AS source_db_link,
         'CLIENT1' AS source_owner,
         'ORDERS_SUBPART_SRC' AS source_table_name,
         'CARCH' AS target_owner,
         'ORDERS_SUBPART_SRC' AS target_table_name,
         'SUBPARTITION' AS archive_unit_type,
         p.partition_name,
         s.subpartition_name,
         p.partition_high_value,
         s.subpartition_high_value,
         p.partition_position,
         s.subpartition_position
    FROM XMLTABLE(
           '/ROWSET/ROW'
           PASSING DBMS_XMLGEN.GETXMLTYPE(
             'SELECT table_name, partition_name, high_value, partition_position ' ||
             'FROM user_tab_partitions ' ||
             'WHERE table_name = ''ORDERS_SUBPART_SRC'' ' ||
             'AND partition_name = ''P_ERROR'''
           )
           COLUMNS
             partition_name       VARCHAR2(128)  PATH 'PARTITION_NAME',
             partition_high_value VARCHAR2(4000) PATH 'HIGH_VALUE',
             partition_position   NUMBER         PATH 'PARTITION_POSITION'
         ) p
    JOIN XMLTABLE(
           '/ROWSET/ROW'
           PASSING DBMS_XMLGEN.GETXMLTYPE(
             'SELECT table_name, partition_name, subpartition_name, high_value, subpartition_position ' ||
             'FROM user_tab_subpartitions ' ||
             'WHERE table_name = ''ORDERS_SUBPART_SRC'' ' ||
             'AND partition_name = ''P_ERROR'''
           )
           COLUMNS
             partition_name          VARCHAR2(128)  PATH 'PARTITION_NAME',
             subpartition_name       VARCHAR2(128)  PATH 'SUBPARTITION_NAME',
             subpartition_high_value VARCHAR2(4000) PATH 'HIGH_VALUE',
             subpartition_position   NUMBER         PATH 'SUBPARTITION_POSITION'
         ) s
      ON s.partition_name = p.partition_name
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
  dst.partition_position = src.partition_position,
  dst.subpartition_position = src.subpartition_position,
  dst.archive_status = 'Y',
  dst.quality_status = 'Y',
  dst.truncate_status = 'Y',
  dst.source_row_count = 0,
  dst.target_row_count = 0,
  dst.error_message = NULL,
  dst.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT
  (source_db_link, source_owner, source_table_name, target_owner, target_table_name,
   archive_unit_type, partition_name, subpartition_name, partition_high_value, subpartition_high_value,
   partition_position, subpartition_position, archive_status, quality_status,
   truncate_status, source_row_count, target_row_count)
VALUES
  (src.source_db_link, src.source_owner, src.source_table_name, src.target_owner, src.target_table_name,
   src.archive_unit_type, src.partition_name, src.subpartition_name, src.partition_high_value, src.subpartition_high_value,
   src.partition_position, src.subpartition_position, 'Y', 'Y',
   'Y', 0, 0);

COMMIT;

PROMPT CLIENT1_LOOPBACK_LINK subpartitioned archive table configuration seeded
