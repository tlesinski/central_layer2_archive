CREATE OR REPLACE VIEW VW_REPLICA_SOURCE_PARTITIONS
AS
WITH cfg AS
(
  SELECT source_db_link,
         source_owner,
         source_table_name,
         target_owner,
         target_table_name,
         partition_method,
         subpartition_method,
         replicate_expression
    FROM TBL_REPLICA_TABLES
   WHERE enabled_flag = 'Y'
),
src AS
(
  SELECT c.source_db_link,
         c.source_owner,
         c.source_table_name,
         c.target_owner,
         c.target_table_name,
         c.partition_method,
         c.subpartition_method,
         c.replicate_expression,
         x.archive_unit_type,
         x.partition_name AS source_partition_name,
         NVL(x.subpartition_name, '#') AS source_subpartition_name,
         x.partition_name,
         NVL(x.subpartition_name, '#') AS subpartition_name,
         x.partition_high_value,
         NVL(x.subpartition_high_value, '#') AS subpartition_high_value,
         x.prev_partition_high_value
    FROM cfg c,
         XMLTABLE
         (
           '/ROWSET/ROW'
           PASSING DBMS_XMLGEN.GETXMLTYPE
           (
             'SELECT archive_unit_type, partition_name, subpartition_name, ' ||
             'partition_high_value, subpartition_high_value, prev_partition_high_value ' ||
             'FROM TBL_ARCHIVER_PARTITIONS@' ||
             DBMS_ASSERT.SIMPLE_SQL_NAME(c.source_db_link) ||
             ' WHERE target_owner = ''' || REPLACE(UPPER(c.source_owner), '''', '''''') || '''' ||
             ' AND target_table_name = ''' || REPLACE(UPPER(c.source_table_name), '''', '''''') || '''' ||
             ' AND archive_status = ''Y'' AND quality_status = ''Y'''
           )
           COLUMNS
             archive_unit_type         VARCHAR2(20)   PATH 'ARCHIVE_UNIT_TYPE',
             partition_name            VARCHAR2(128)  PATH 'PARTITION_NAME',
             subpartition_name         VARCHAR2(128)  PATH 'SUBPARTITION_NAME',
             partition_high_value      VARCHAR2(4000) PATH 'PARTITION_HIGH_VALUE',
             subpartition_high_value   VARCHAR2(4000) PATH 'SUBPARTITION_HIGH_VALUE',
             prev_partition_high_value VARCHAR2(4000) PATH 'PREV_PARTITION_HIGH_VALUE'
         ) x
)
SELECT source_db_link,
       source_owner,
       source_table_name,
       target_owner,
       target_table_name,
       partition_method,
       subpartition_method,
       replicate_expression,
       archive_unit_type,
       source_partition_name,
       source_subpartition_name,
       partition_name,
       subpartition_name,
       partition_high_value,
       subpartition_high_value,
       prev_partition_high_value
  FROM src;
/
