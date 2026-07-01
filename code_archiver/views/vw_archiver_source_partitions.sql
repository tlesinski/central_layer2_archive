CREATE OR REPLACE VIEW VW_ARCHIVER_SOURCE_PARTITIONS
AS
WITH cfg AS (
  SELECT source_db_link,
         source_owner,
         source_table_name,
         target_owner,
         target_table_name,
         partition_method,
         subpartition_method
    FROM TBL_ARCHIVER_TABLES
   WHERE enabled_flag = 'Y'
),
src AS (
  SELECT c.source_db_link,
         c.source_owner,
         c.source_table_name,
         c.target_owner,
         c.target_table_name,
         c.partition_method,
         c.subpartition_method,
         CASE
           WHEN x.subpartition_name IS NULL THEN 'PARTITION'
           ELSE 'SUBPARTITION'
         END AS archive_unit_type,
         x.partition_name AS source_partition_name,
         NVL(x.subpartition_name, '#') AS source_subpartition_name,
         x.partition_name AS partition_name,
         NVL(x.subpartition_name, '#') AS subpartition_name,
         x.partition_high_value,
          NVL(x.subpartition_high_value, '#') AS subpartition_high_value,
          x.prev_partition_high_value,
          x.partition_position,
         NVL(x.subpartition_position, 0) AS subpartition_position,
         x.partition_method AS source_partition_method,
         x.subpartition_method AS source_subpartition_method,
         x.partition_key_column,
         x.partition_key_data_type,
         x.subpartition_key_column,
         x.subpartition_key_data_type,
         x.partition_key_count,
         x.subpartition_key_count
    FROM cfg c,
         XMLTABLE(
           '/ROWSET/ROW'
           PASSING DBMS_XMLGEN.GETXMLTYPE(
             'SELECT * FROM ' ||
             'VW_AGENT_PARTITION_INFO' ||
             '@' || DBMS_ASSERT.SIMPLE_SQL_NAME(c.source_db_link) ||
             ' WHERE schema_name = ''' || REPLACE(UPPER(c.source_owner), '''', '''''') || '''' ||
             ' AND table_name = ''' || REPLACE(UPPER(c.source_table_name), '''', '''''') || ''''
           )
           COLUMNS
             schema_name              VARCHAR2(128)  PATH 'SCHEMA_NAME',
             table_name               VARCHAR2(128)  PATH 'TABLE_NAME',
             partition_name           VARCHAR2(128)  PATH 'PARTITION_NAME',
             subpartition_name        VARCHAR2(128)  PATH 'SUBPARTITION_NAME',
              partition_high_value     VARCHAR2(4000) PATH 'PARTITION_HIGH_VALUE',
              subpartition_high_value  VARCHAR2(4000) PATH 'SUBPARTITION_HIGH_VALUE',
              prev_partition_high_value VARCHAR2(4000) PATH 'PREV_PARTITION_HIGH_VALUE',
              partition_position       NUMBER         PATH 'PARTITION_POSITION',
               subpartition_position    NUMBER         PATH 'SUBPARTITION_POSITION',
               partition_method         VARCHAR2(20)   PATH 'PARTITION_METHOD',
               subpartition_method      VARCHAR2(20)   PATH 'SUBPARTITION_METHOD',
               partition_key_column     VARCHAR2(128)  PATH 'PARTITION_KEY_COLUMN',
               partition_key_data_type  VARCHAR2(128)  PATH 'PARTITION_KEY_DATA_TYPE',
               subpartition_key_column  VARCHAR2(128)  PATH 'SUBPARTITION_KEY_COLUMN',
               subpartition_key_data_type VARCHAR2(128) PATH 'SUBPARTITION_KEY_DATA_TYPE',
               partition_key_count      NUMBER         PATH 'PARTITION_KEY_COUNT',
               subpartition_key_count   NUMBER         PATH 'SUBPARTITION_KEY_COUNT'
           ) x
)
SELECT source_db_link,
       source_owner,
       source_table_name,
       target_owner,
       target_table_name,
       partition_method,
       subpartition_method,
       archive_unit_type,
       source_partition_name,
       source_subpartition_name,
       partition_name,
       subpartition_name,
       partition_high_value,
       subpartition_high_value,
       prev_partition_high_value,
       partition_position,
       subpartition_position,
       source_partition_method,
       source_subpartition_method,
       partition_key_column,
       partition_key_data_type,
       subpartition_key_column,
       subpartition_key_data_type,
       partition_key_count,
       subpartition_key_count
  FROM src;
/
