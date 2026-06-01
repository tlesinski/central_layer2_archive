CREATE OR REPLACE VIEW TW_REPLICA_DISCOVERY_PARTITIONS_VW
AS
SELECT s.source_db_link,
       s.source_owner,
       s.source_table_name,
       s.target_owner,
       s.target_table_name,
       s.days_online,
       s.base_date,
       s.cutoff_date,
       s.archive_unit_type,
       s.source_partition_name,
       s.source_subpartition_name,
       s.partition_name,
       s.subpartition_name,
       s.partition_high_value,
       s.subpartition_high_value,
       s.prev_partition_high_value,
       s.partition_high_value_date
  FROM tw_replica_source_partitions_vw s
 WHERE NOT EXISTS (
       SELECT 1
         FROM tw_replica_partitions p
        WHERE p.source_db_link = s.source_db_link
          AND p.source_owner = s.source_owner
          AND p.source_table_name = s.source_table_name
          AND p.partition_high_value = s.partition_high_value
          AND p.subpartition_high_value = s.subpartition_high_value
       );
/
