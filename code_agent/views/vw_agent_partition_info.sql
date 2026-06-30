  CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_AGENT_PARTITION_INFO" 
  ("SCHEMA_NAME", "TABLE_NAME", "PARTITION_NAME", "SUBPARTITION_NAME", "PARTITION_HIGH_VALUE", "PREV_PARTITION_HIGH_VALUE", "SUBPARTITION_HIGH_VALUE", "PARTITION_POSITION", "SUBPARTITION_POSITION") AS 
with w_table_list
as
(
  select SOURCE_OWNER, SOURCE_TABLE_NAME
    from tbl_agent_client_tables
),
w_raw as (
  select b.*
    from w_table_list a,
         lateral
         (
           select *
             from TABLE(PKG_AGENT_ARCHIVE.fn_get_partition_info(a.SOURCE_OWNER, a.SOURCE_TABLE_NAME))
         ) b
),
w_partitions as (
  select distinct SCHEMA_NAME, TABLE_NAME, PARTITION_NAME,
         PARTITION_POSITION, PARTITION_HIGH_VALUE
    from w_raw
),
w_partitions_with_prev as (
  select SCHEMA_NAME, TABLE_NAME, PARTITION_NAME,
         PARTITION_POSITION, PARTITION_HIGH_VALUE,
         lag(PARTITION_HIGH_VALUE, 1) over (
           partition by SCHEMA_NAME, TABLE_NAME
           order by PARTITION_POSITION
         ) as PREV_PARTITION_HIGH_VALUE
    from w_partitions
)
select r.SCHEMA_NAME, r.TABLE_NAME, r.PARTITION_NAME,
       r.SUBPARTITION_NAME,
       r.PARTITION_HIGH_VALUE,
       p.PREV_PARTITION_HIGH_VALUE,
       r.SUBPARTITION_HIGH_VALUE,
       r.PARTITION_POSITION,
       r.SUBPARTITION_POSITION
  from w_raw r
  join w_partitions_with_prev p
    on r.SCHEMA_NAME = p.SCHEMA_NAME
   and r.TABLE_NAME = p.TABLE_NAME
   and r.PARTITION_NAME = p.PARTITION_NAME;