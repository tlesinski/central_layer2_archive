CREATE OR REPLACE VIEW VW_ARCHIVER_IMPORT_PARTITIONS
AS
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
       t.LAST_BUSINESS_DATE,
       FN_ARCHIVER_HIGH_VALUE_DATE(t.LAST_BUSINESS_DATE) eod_date_calc,
       FN_ARCHIVER_HIGH_VALUE_DATE(partition_high_value) partition_high_date
  FROM TBL_ARCHIVER_PARTITIONS p
  JOIN TBL_ARCHIVER_TABLES t
    ON t.source_db_link = p.source_db_link
   AND t.source_owner = p.source_owner
   AND t.source_table_name = p.source_table_name
   AND t.enabled_flag = 'Y'
 WHERE p.archive_status = 'N'
   AND FN_ARCHIVER_HIGH_VALUE_DATE(partition_high_value) < FN_ARCHIVER_HIGH_VALUE_DATE(t.LAST_BUSINESS_DATE);
/
