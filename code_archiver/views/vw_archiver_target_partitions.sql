CREATE OR REPLACE VIEW VW_ARCHIVER_TARGET_PARTITIONS
AS
WITH cfg AS (
  SELECT source_db_link, source_owner, source_table_name,
         target_owner, target_table_name, partition_method, subpartition_method
    FROM TBL_ARCHIVER_TABLES
   WHERE enabled_flag = 'Y'
),
raw_units AS (
  SELECT c.source_db_link, c.source_owner, c.source_table_name,
         c.target_owner, c.target_table_name,
         c.partition_method, c.subpartition_method,
         x.partition_name AS target_partition_name,
         NVL(x.subpartition_name, '#') AS target_subpartition_name,
         x.partition_high_value,
         NVL(x.subpartition_high_value, '#') AS subpartition_high_value,
         x.partition_position,
         NVL(x.subpartition_position, 0) AS subpartition_position,
         x.target_partition_method, x.target_subpartition_method,
         x.partition_key_column, x.partition_key_data_type,
         x.subpartition_key_column, x.subpartition_key_data_type,
         x.partition_key_count, x.subpartition_key_count
    FROM cfg c,
         XMLTABLE(
           '/ROWSET/ROW'
           PASSING DBMS_XMLGEN.GETXMLTYPE(
             'SELECT p.partition_name, s.subpartition_name, ' ||
             'p.high_value partition_high_value, s.high_value subpartition_high_value, ' ||
             'p.partition_position, s.subpartition_position, ' ||
             'pt.partitioning_type target_partition_method, ' ||
             'NULLIF(pt.subpartitioning_type, ''NONE'') target_subpartition_method, ' ||
             '(SELECT column_name FROM all_part_key_columns k WHERE k.owner=p.table_owner AND k.name=p.table_name AND k.object_type=''TABLE'' AND k.column_position=1) partition_key_column, ' ||
             '(SELECT data_type FROM all_tab_columns tc WHERE tc.owner=p.table_owner AND tc.table_name=p.table_name AND tc.column_name=(SELECT column_name FROM all_part_key_columns k WHERE k.owner=p.table_owner AND k.name=p.table_name AND k.object_type=''TABLE'' AND k.column_position=1)) partition_key_data_type, ' ||
             '(SELECT column_name FROM all_subpart_key_columns k WHERE k.owner=p.table_owner AND k.name=p.table_name AND k.object_type=''TABLE'' AND k.column_position=1) subpartition_key_column, ' ||
             '(SELECT data_type FROM all_tab_columns tc WHERE tc.owner=p.table_owner AND tc.table_name=p.table_name AND tc.column_name=(SELECT column_name FROM all_subpart_key_columns k WHERE k.owner=p.table_owner AND k.name=p.table_name AND k.object_type=''TABLE'' AND k.column_position=1)) subpartition_key_data_type, ' ||
             '(SELECT COUNT(*) FROM all_part_key_columns k WHERE k.owner=p.table_owner AND k.name=p.table_name AND k.object_type=''TABLE'') partition_key_count, ' ||
             '(SELECT COUNT(*) FROM all_subpart_key_columns k WHERE k.owner=p.table_owner AND k.name=p.table_name AND k.object_type=''TABLE'') subpartition_key_count ' ||
             'FROM all_tab_partitions p JOIN all_part_tables pt ON pt.owner=p.table_owner AND pt.table_name=p.table_name ' ||
             'LEFT JOIN all_tab_subpartitions s ON s.table_owner=p.table_owner AND s.table_name=p.table_name AND s.partition_name=p.partition_name ' ||
             'WHERE p.table_owner=''' || REPLACE(UPPER(c.target_owner), '''', '''''') || ''' ' ||
             'AND p.table_name=''' || REPLACE(UPPER(c.target_table_name), '''', '''''') || ''''
           )
           COLUMNS
             partition_name VARCHAR2(128) PATH 'PARTITION_NAME',
             subpartition_name VARCHAR2(128) PATH 'SUBPARTITION_NAME',
             partition_high_value VARCHAR2(4000) PATH 'PARTITION_HIGH_VALUE',
             subpartition_high_value VARCHAR2(4000) PATH 'SUBPARTITION_HIGH_VALUE',
             partition_position NUMBER PATH 'PARTITION_POSITION',
             subpartition_position NUMBER PATH 'SUBPARTITION_POSITION',
             target_partition_method VARCHAR2(20) PATH 'TARGET_PARTITION_METHOD',
             target_subpartition_method VARCHAR2(20) PATH 'TARGET_SUBPARTITION_METHOD',
             partition_key_column VARCHAR2(128) PATH 'PARTITION_KEY_COLUMN',
             partition_key_data_type VARCHAR2(128) PATH 'PARTITION_KEY_DATA_TYPE',
             subpartition_key_column VARCHAR2(128) PATH 'SUBPARTITION_KEY_COLUMN',
             subpartition_key_data_type VARCHAR2(128) PATH 'SUBPARTITION_KEY_DATA_TYPE',
             partition_key_count NUMBER PATH 'PARTITION_KEY_COUNT',
             subpartition_key_count NUMBER PATH 'SUBPARTITION_KEY_COUNT'
         ) x
),
partition_bounds AS (
  SELECT source_db_link, source_owner, source_table_name,
         partition_high_value,
         LAG(partition_high_value) OVER (
           PARTITION BY source_db_link, source_owner, source_table_name
           ORDER BY partition_position
         ) AS prev_partition_high_value
    FROM (
      SELECT DISTINCT source_db_link, source_owner, source_table_name,
             partition_high_value, partition_position
        FROM raw_units
    )
)
SELECT r.source_db_link, r.source_owner, r.source_table_name,
       r.target_owner, r.target_table_name,
       r.partition_method, r.subpartition_method,
       CASE WHEN r.target_subpartition_name = '#' THEN 'PARTITION' ELSE 'SUBPARTITION' END AS archive_unit_type,
       r.target_partition_name, r.target_subpartition_name,
       r.partition_high_value, r.subpartition_high_value,
       b.prev_partition_high_value,
       r.partition_position, r.subpartition_position,
       r.target_partition_method, r.target_subpartition_method,
       r.partition_key_column, r.partition_key_data_type,
       r.subpartition_key_column, r.subpartition_key_data_type,
       r.partition_key_count, r.subpartition_key_count
  FROM raw_units r
  JOIN partition_bounds b
    ON b.source_db_link = r.source_db_link
   AND b.source_owner = r.source_owner
   AND b.source_table_name = r.source_table_name
   AND b.partition_high_value = r.partition_high_value;
/
