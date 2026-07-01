CREATE OR REPLACE VIEW VW_ARCHIVER_DISCOVERY_PARTITIONS
AS
SELECT s.source_db_link,
       s.source_owner,
       s.source_table_name,
       s.target_owner,
       s.target_table_name,
       s.partition_method,
       s.subpartition_method,
       s.archive_unit_type,
       s.source_partition_name,
       s.source_subpartition_name,
       s.partition_name,
       s.subpartition_name,
       s.partition_high_value,
       s.subpartition_high_value,
       s.prev_partition_high_value,
       s.partition_position,
       s.subpartition_position,
       s.source_partition_method,
       s.source_subpartition_method,
       s.partition_key_column,
       s.partition_key_data_type,
       s.subpartition_key_column,
       s.subpartition_key_data_type,
       s.partition_key_count,
       s.subpartition_key_count
  FROM VW_ARCHIVER_SOURCE_PARTITIONS s
 WHERE NOT EXISTS (
       SELECT 1
         FROM TBL_ARCHIVER_PARTITIONS p
        WHERE p.source_db_link = s.source_db_link
          AND p.source_owner = s.source_owner
          AND p.source_table_name = s.source_table_name
          AND p.partition_high_value = s.partition_high_value
          AND p.subpartition_high_value = s.subpartition_high_value
       );
/
