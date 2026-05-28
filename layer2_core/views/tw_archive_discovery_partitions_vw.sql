CREATE OR REPLACE VIEW TW_ARCHIVE_DISCOVERY_PARTITIONS_VW
AS
SELECT s.source_db_link,
       s.source_agent_schema,
       s.source_owner,
       s.source_table_name,
       s.target_owner,
       s.target_table_name,
       s.archive_unit_type,
       s.source_partition_name,
       s.source_subpartition_name,
       s.partition_name,
       s.subpartition_name,
       s.partition_high_value,
       s.subpartition_high_value,
       s.partition_position,
       s.subpartition_position
  FROM tw_archive_source_partitions_vw s
 WHERE NOT EXISTS (
       SELECT 1
         FROM tw_archive_partitions p
        WHERE p.source_db_link = s.source_db_link
          AND p.source_owner = s.source_owner
          AND p.source_table_name = s.source_table_name
          AND p.partition_high_value = s.partition_high_value
          AND p.subpartition_high_value = s.subpartition_high_value
       );
/
