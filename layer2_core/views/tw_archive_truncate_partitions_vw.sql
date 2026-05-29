CREATE OR REPLACE FORCE VIEW TW_ARCHIVE_TRUNCATE_PARTITIONS_VW
AS
WITH candidate_partitions AS (
SELECT p.source_db_link,
       t.source_agent_schema,
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
       p.archive_status,
       p.quality_status,
       p.truncate_status,
       p.source_row_count,
       p.target_row_count,
       FN_ARCHIVE_HIGH_VALUE_DATE(t.LAST_BUSINESS_DATE) LAST_BUSINESS_DATE_calc,
       DAYS_ONLINE,
       FN_ARCHIVE_HIGH_VALUE_DATE(t.LAST_BUSINESS_DATE)- DAYS_ONLINE AS cutoff_date,
       FN_ARCHIVE_HIGH_VALUE_DATE(p.partition_high_value) AS partition_high_value_date
  FROM tw_archive_partitions p
  JOIN tw_archive_tables t
    ON t.source_db_link = p.source_db_link
   AND t.source_owner = p.source_owner
   AND t.source_table_name = p.source_table_name
   AND t.enabled_flag = 'Y'
   AND t.truncate_mode = 'TRUNCATE'
 WHERE p.archive_status = 'Y'
   AND p.quality_status = 'Y'
   AND p.truncate_status = 'N'
)
SELECT source_db_link,
       source_agent_schema,
       source_owner,
       source_table_name,
       target_owner,
       target_table_name,
       archive_unit_type,
       source_partition_name,
       source_subpartition_name,
       partition_name,
       subpartition_name,
       partition_high_value,
       subpartition_high_value,
       prev_partition_high_value,
       archive_status,
       quality_status,
       truncate_status,
       source_row_count,
       target_row_count,
       LAST_BUSINESS_DATE_calc,
       DAYS_ONLINE,
       cutoff_date,
       partition_high_value_date
  FROM candidate_partitions
 WHERE partition_high_value_date <= cutoff_date;
/
