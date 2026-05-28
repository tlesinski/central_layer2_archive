CREATE OR REPLACE VIEW TW_ARCHIVE_IMPORT_PARTITIONS_VW
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
       p.partition_position,
       p.subpartition_position,
       (
         SELECT MAX(pp.partition_high_value) KEEP (DENSE_RANK LAST ORDER BY pp.partition_position)
           FROM tw_archive_partitions pp
          WHERE pp.source_db_link = p.source_db_link
            AND pp.source_owner = p.source_owner
            AND pp.source_table_name = p.source_table_name
            AND pp.partition_position < p.partition_position
       ) AS prev_partition_high_value
  FROM tw_archive_partitions p
  JOIN tw_archive_tables t
    ON t.source_db_link = p.source_db_link
   AND t.source_owner = p.source_owner
   AND t.source_table_name = p.source_table_name
   AND t.enabled_flag = 'Y'
 WHERE p.archive_status = 'N';
/
