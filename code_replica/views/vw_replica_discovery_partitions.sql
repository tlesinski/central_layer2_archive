CREATE OR REPLACE VIEW VW_REPLICA_DISCOVERY_PARTITIONS
AS
SELECT s.*
  FROM VW_REPLICA_SOURCE_PARTITIONS s
 WHERE NOT EXISTS
       (
         SELECT 1
           FROM TBL_REPLICA_PARTITIONS p
          WHERE p.source_db_link = s.source_db_link
            AND p.source_owner = s.source_owner
            AND p.source_table_name = s.source_table_name
            AND p.partition_high_value = s.partition_high_value
            AND p.subpartition_high_value = s.subpartition_high_value
       );
/
