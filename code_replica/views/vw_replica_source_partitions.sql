CREATE OR REPLACE VIEW VW_REPLICA_SOURCE_PARTITIONS
AS
WITH l2_units AS (
  SELECT rt.source_db_link,
         rt.source_owner,
         rt.source_table_name,
         rt.target_owner,
         rt.target_table_name,
         rt.days_online,
         rt.enabled_flag,
         p.archive_unit_type,
         p.partition_name AS source_partition_name,
         p.subpartition_name AS source_subpartition_name,
         p.partition_name,
         p.subpartition_name,
         p.partition_high_value,
         p.subpartition_high_value,
         p.prev_partition_high_value,
         FN_REPLICA_HIGH_VALUE_DATE(p.partition_high_value) AS partition_high_value_date
    FROM tbl_replica_tables rt
    JOIN REPLICA_ARCHIVER_PARTITIONS_SRC p
      ON p.target_owner = rt.source_owner
     AND p.target_table_name = rt.source_table_name
     AND p.archive_status = 'Y'
     AND p.quality_status = 'Y'
   WHERE rt.enabled_flag = 'Y'
     AND UPPER(TRIM(p.partition_high_value)) <> 'MAXVALUE'
),
base_dates AS (
  SELECT source_db_link,
         source_owner,
         source_table_name,
         MAX(partition_high_value_date) AS base_date
    FROM l2_units
   GROUP BY source_db_link, source_owner, source_table_name
)
SELECT u.source_db_link,
       u.source_owner,
       u.source_table_name,
       u.target_owner,
       u.target_table_name,
       u.days_online,
       b.base_date,
       b.base_date - u.days_online AS cutoff_date,
       u.archive_unit_type,
       u.source_partition_name,
       u.source_subpartition_name,
       u.partition_name,
       u.subpartition_name,
       u.partition_high_value,
       u.subpartition_high_value,
       u.prev_partition_high_value,
       u.partition_high_value_date
  FROM l2_units u
  JOIN base_dates b
    ON b.source_db_link = u.source_db_link
   AND b.source_owner = u.source_owner
   AND b.source_table_name = u.source_table_name;
/
