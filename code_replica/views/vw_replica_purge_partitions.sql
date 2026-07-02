CREATE OR REPLACE VIEW VW_REPLICA_PURGE_PARTITIONS
AS
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
       t.partition_method,
       t.subpartition_method,
       FN_REPLICA_EXPR_CALC(p.partition_high_value, p.prev_partition_high_value,
         p.subpartition_high_value, t.replicate_expression, 'FLAG') AS replicate_flag,
       FN_REPLICA_EXPR_CALC(p.partition_high_value, p.prev_partition_high_value,
         p.subpartition_high_value, t.replicate_expression, 'VALUE') AS replicate_value
  FROM TBL_REPLICA_PARTITIONS p
  JOIN TBL_REPLICA_TABLES t
    ON t.source_db_link = p.source_db_link
   AND t.source_owner = p.source_owner
   AND t.source_table_name = p.source_table_name
   AND t.enabled_flag = 'Y'
 WHERE p.replica_status = 'Y'
   AND p.quality_status = 'Y'
   AND p.purge_status = 'N'
   AND FN_REPLICA_EXPR_CALC(p.partition_high_value, p.prev_partition_high_value,
         p.subpartition_high_value, t.replicate_expression, 'FLAG') = 'N';
/
