CREATE OR REPLACE VIEW VW_ARCHIVER_SOFT_VALIDATION
AS
WITH unit_keys AS (
  SELECT source_db_link, source_owner, source_table_name,
         partition_high_value, subpartition_high_value
    FROM VW_ARCHIVER_SOURCE_PARTITIONS
  UNION
  SELECT source_db_link, source_owner, source_table_name,
         partition_high_value, subpartition_high_value
    FROM VW_ARCHIVER_TARGET_PARTITIONS
  UNION
  SELECT source_db_link, source_owner, source_table_name,
         partition_high_value, subpartition_high_value
    FROM TBL_ARCHIVER_PARTITIONS
),
joined_units AS (
  SELECT k.source_db_link, k.source_owner, k.source_table_name,
         COALESCE(s.target_owner, t.target_owner, m.target_owner) AS target_owner,
         COALESCE(s.target_table_name, t.target_table_name, m.target_table_name) AS target_table_name,
         COALESCE(s.archive_unit_type, t.archive_unit_type, m.archive_unit_type) AS archive_unit_type,
         k.partition_high_value, k.subpartition_high_value,
         COALESCE(s.prev_partition_high_value, t.prev_partition_high_value, m.prev_partition_high_value) AS prev_partition_high_value,
         s.source_partition_name AS current_source_partition_name,
         s.source_subpartition_name AS current_source_subpartition_name,
         t.target_partition_name AS current_target_partition_name,
         t.target_subpartition_name AS current_target_subpartition_name,
         m.source_partition_name AS metadata_source_partition_name,
         m.source_subpartition_name AS metadata_source_subpartition_name,
         m.partition_name AS metadata_target_partition_name,
         m.subpartition_name AS metadata_target_subpartition_name,
         m.archive_status, m.quality_status, m.truncate_status,
         CASE WHEN s.source_db_link IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS source_presence_status,
         CASE WHEN t.source_db_link IS NULL THEN 'MISSING' ELSE 'PRESENT' END AS target_presence_status,
         CASE WHEN s.source_db_link IS NULL OR t.source_db_link IS NULL THEN 'NOT_COMPARABLE'
              WHEN s.source_partition_name = t.target_partition_name
               AND s.source_subpartition_name = t.target_subpartition_name THEN 'MATCH'
              ELSE 'MISMATCH' END AS source_target_name_status,
         CASE WHEN s.source_db_link IS NULL OR m.source_db_link IS NULL THEN 'NOT_COMPARABLE'
              WHEN s.source_partition_name = m.source_partition_name
               AND s.source_subpartition_name = m.source_subpartition_name THEN 'MATCH'
              ELSE 'MISMATCH' END AS source_metadata_name_status,
         CASE WHEN t.source_db_link IS NULL OR m.source_db_link IS NULL THEN 'NOT_COMPARABLE'
              WHEN t.target_partition_name = m.partition_name
               AND t.target_subpartition_name = m.subpartition_name THEN 'MATCH'
              ELSE 'MISMATCH' END AS target_metadata_name_status
    FROM unit_keys k
    LEFT JOIN VW_ARCHIVER_SOURCE_PARTITIONS s
      ON s.source_db_link = k.source_db_link AND s.source_owner = k.source_owner
     AND s.source_table_name = k.source_table_name
     AND s.partition_high_value = k.partition_high_value
     AND s.subpartition_high_value = k.subpartition_high_value
    LEFT JOIN VW_ARCHIVER_TARGET_PARTITIONS t
      ON t.source_db_link = k.source_db_link AND t.source_owner = k.source_owner
     AND t.source_table_name = k.source_table_name
     AND t.partition_high_value = k.partition_high_value
     AND t.subpartition_high_value = k.subpartition_high_value
    LEFT JOIN TBL_ARCHIVER_PARTITIONS m
      ON m.source_db_link = k.source_db_link AND m.source_owner = k.source_owner
     AND m.source_table_name = k.source_table_name
     AND m.partition_high_value = k.partition_high_value
     AND m.subpartition_high_value = k.subpartition_high_value
)
SELECT j.*,
       CASE
         WHEN source_presence_status = 'MISSING' OR target_presence_status = 'MISSING' THEN 'MISSING'
         WHEN source_target_name_status = 'MISMATCH'
           OR source_metadata_name_status = 'MISMATCH'
           OR target_metadata_name_status = 'MISMATCH' THEN 'MISMATCH'
         ELSE 'MATCH'
       END AS validation_status
  FROM joined_units j;
/
