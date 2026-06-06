CREATE OR REPLACE FORCE VIEW VW_ARCHIVER_TRUNCATE_PARTITIONS
AS
WITH w_preserve_data as 
(
  SELECT /*+ materialize */ target_owner, target_table_name, preserve_rule, B.COLUMN_VALUE preserve_date
    FROM TBL_ARCHIVER_TABLES A 
    LEFT JOIN LATERAL(SELECT * FROM TABLE(FN_ARCHIVER_VALIDATE_PRESERVE(A.preserve_rule))) B ON(1=1)
) ,
candidate_partitions AS (
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
       p.archive_status,
       p.quality_status,
       p.truncate_status,
       p.source_row_count,
       p.target_row_count,
       preserve_rule,
       FN_ARCHIVER_HIGH_VALUE_DATE(t.LAST_BUSINESS_DATE) LAST_BUSINESS_DATE_calc,
       DAYS_ONLINE,
       FN_ARCHIVER_HIGH_VALUE_DATE(t.LAST_BUSINESS_DATE)- DAYS_ONLINE AS cutoff_date,
       FN_ARCHIVER_HIGH_VALUE_DATE(p.partition_high_value) AS partition_high_value_date,
       FN_ARCHIVER_HIGH_VALUE_DATE(p.prev_partition_high_value) AS prev_partition_high_value_date
  FROM TBL_ARCHIVER_PARTITIONS p
  JOIN TBL_ARCHIVER_TABLES t
    ON t.source_db_link = p.source_db_link
   AND t.source_owner = p.source_owner
   AND t.source_table_name = p.source_table_name
   AND t.enabled_flag = 'Y'
 WHERE p.archive_status = 'Y'
   AND p.quality_status = 'Y'
   AND p.truncate_status = 'N'
)
SELECT source_db_link,
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
       preserve_rule,
       LAST_BUSINESS_DATE_calc,
       DAYS_ONLINE,
       cutoff_date,
       partition_high_value_date,
       prev_partition_high_value_date,
       (SELECT MAX(preserve_date) 
          FROM w_preserve_data P 
         WHERE P.target_owner=C.target_owner 
           AND P.target_table_name=C.target_table_name 
           AND partition_high_value_date > preserve_date 
           AND prev_partition_high_value_date <= preserve_date) preserve_date
  FROM candidate_partitions c 
 WHERE partition_high_value_date <= cutoff_date
 /
