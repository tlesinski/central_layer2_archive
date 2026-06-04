CREATE OR REPLACE VIEW VW_AGENT_PARTITION_INFO
AS
SELECT p.table_owner AS schema_name,
       p.table_name,
       p.partition_name,
       s.subpartition_name,
       EXTRACTVALUE
       (
         DBMS_XMLGEN.GETXMLTYPE
         (
           'select high_value from all_tab_partitions where table_owner = ''' ||
           REPLACE(p.table_owner, '''', '''''') ||
           ''' and table_name = ''' ||
           REPLACE(p.table_name, '''', '''''') ||
           ''' and partition_name = ''' ||
           REPLACE(p.partition_name, '''', '''''') || ''''
         ),
         '/ROWSET/ROW/HIGH_VALUE'
       ) AS partition_high_value,
       EXTRACTVALUE
       (
         DBMS_XMLGEN.GETXMLTYPE
         (
           'select high_value from all_tab_partitions where table_owner = ''' ||
           p.table_owner ||
           ''' and table_name = ''' ||
           p.table_name ||
           ''' and partition_position = '||(p.partition_position-1)
         ),
         '/ROWSET/ROW/HIGH_VALUE'
       ) AS prev_partition_high_value,
       CASE
         WHEN s.subpartition_name IS NULL THEN NULL
         ELSE EXTRACTVALUE
              (
                DBMS_XMLGEN.GETXMLTYPE
                (
                  'select high_value from all_tab_subpartitions where table_owner = ''' ||
                  REPLACE(s.table_owner, '''', '''''') ||
                  ''' and table_name = ''' ||
                  REPLACE(s.table_name, '''', '''''') ||
                  ''' and partition_name = ''' ||
                  REPLACE(s.partition_name, '''', '''''') ||
                  ''' and subpartition_name = ''' ||
                  REPLACE(s.subpartition_name, '''', '''''') || ''''
                ),
                '/ROWSET/ROW/HIGH_VALUE'
              )
       END AS subpartition_high_value,
       p.partition_position,
       s.subpartition_position
  FROM all_tab_partitions p
  LEFT JOIN all_tab_subpartitions s
    ON p.table_owner = s.table_owner
   AND p.table_name = s.table_name
   AND p.partition_name = s.partition_name;
