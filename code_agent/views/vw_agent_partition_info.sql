CREATE OR REPLACE VIEW VW_AGENT_PARTITION_INFO
AS
WITH w_table_metadata AS
(
  SELECT a.source_owner,
         a.source_table_name,
         pt.partitioning_type AS partition_method,
         NULLIF(pt.subpartitioning_type, 'NONE') AS subpartition_method,
         pk.column_name AS partition_key_column,
         pc.data_type AS partition_key_data_type,
         spk.column_name AS subpartition_key_column,
         spc.data_type AS subpartition_key_data_type,
         (SELECT COUNT(*)
            FROM all_part_key_columns x
           WHERE x.owner = a.source_owner
             AND x.name = a.source_table_name
             AND x.object_type = 'TABLE') AS partition_key_count,
         (SELECT COUNT(*)
            FROM all_subpart_key_columns x
           WHERE x.owner = a.source_owner
             AND x.name = a.source_table_name
             AND x.object_type = 'TABLE') AS subpartition_key_count
    FROM TBL_AGENT_CLIENT_TABLES a
    JOIN all_part_tables pt
      ON pt.owner = a.source_owner
     AND pt.table_name = a.source_table_name
    JOIN all_part_key_columns pk
      ON pk.owner = a.source_owner
     AND pk.name = a.source_table_name
     AND pk.object_type = 'TABLE'
     AND pk.column_position = 1
    JOIN all_tab_columns pc
      ON pc.owner = pk.owner
     AND pc.table_name = pk.name
     AND pc.column_name = pk.column_name
    LEFT JOIN all_subpart_key_columns spk
      ON spk.owner = a.source_owner
     AND spk.name = a.source_table_name
     AND spk.object_type = 'TABLE'
     AND spk.column_position = 1
    LEFT JOIN all_tab_columns spc
      ON spc.owner = spk.owner
     AND spc.table_name = spk.name
     AND spc.column_name = spk.column_name
),
w_raw AS
(
  SELECT m.*,
         p.schema_name,
         p.table_name,
         p.partition_name,
         p.subpartition_name,
         p.partition_high_value,
         p.subpartition_high_value,
         p.partition_position,
         p.subpartition_position
    FROM w_table_metadata m,
         LATERAL
         (
           SELECT *
             FROM TABLE(PKG_AGENT_ARCHIVE.fn_get_partition_info(m.source_owner, m.source_table_name))
         ) p
),
w_partitions AS
(
  SELECT DISTINCT schema_name,
         table_name,
         partition_method,
         partition_name,
         partition_position,
         partition_high_value
    FROM w_raw
),
w_partitions_with_prev AS
(
  SELECT schema_name,
         table_name,
         partition_name,
         partition_position,
         partition_high_value,
         CASE partition_method
           WHEN 'RANGE' THEN LAG(partition_high_value) OVER
             (PARTITION BY schema_name, table_name ORDER BY partition_position)
         END AS prev_partition_high_value
    FROM w_partitions
)
SELECT r.schema_name,
       r.table_name,
       r.partition_name,
       r.subpartition_name,
       r.partition_high_value,
       p.prev_partition_high_value,
       r.subpartition_high_value,
       r.partition_position,
       r.subpartition_position,
       r.partition_method,
       r.subpartition_method,
       r.partition_key_column,
       r.partition_key_data_type,
       r.subpartition_key_column,
       r.subpartition_key_data_type,
       r.partition_key_count,
       r.subpartition_key_count
  FROM w_raw r
  JOIN w_partitions_with_prev p
    ON p.schema_name = r.schema_name
   AND p.table_name = r.table_name
   AND p.partition_name = r.partition_name;
/
