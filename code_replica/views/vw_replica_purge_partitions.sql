CREATE OR REPLACE VIEW VW_REPLICA_PURGE_PARTITIONS
AS
WITH base_dates AS (
  SELECT source_db_link,
         source_owner,
         source_table_name,
         MAX(partition_high_value_date) AS base_date
    FROM vw_replica_source_partitions
   GROUP BY source_db_link, source_owner, source_table_name
)
SELECT p.source_db_link,
       p.source_owner,
       p.source_table_name,
       p.target_owner,
       p.target_table_name,
       p.archive_unit_type,
       p.source_partition_name,
       p.source_subpartition_name,
       p.partition_name,
       p.subpartition_name,
       p.partition_high_value,
       p.subpartition_high_value,
       p.prev_partition_high_value,
       p.replica_status,
       p.quality_status,
       p.purge_status,
       p.source_row_count,
       p.target_row_count,
       t.days_online,
       b.base_date,
       b.base_date - t.days_online AS cutoff_date,
       FN_REPLICA_HIGH_VALUE_DATE(p.partition_high_value) AS partition_high_value_date
  FROM tbl_replica_partitions p
  JOIN tbl_replica_tables t
    ON t.source_db_link = p.source_db_link
   AND t.source_owner = p.source_owner
   AND t.source_table_name = p.source_table_name
   AND t.enabled_flag = 'Y'
  JOIN base_dates b
    ON b.source_db_link = p.source_db_link
   AND b.source_owner = p.source_owner
   AND b.source_table_name = p.source_table_name
 WHERE p.replica_status = 'Y'
   AND p.quality_status = 'Y'
   AND p.purge_status = 'N'
   AND FN_REPLICA_HIGH_VALUE_DATE(p.partition_high_value) <= b.base_date - t.days_online;
/
