SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

INSERT INTO TBL_REPLICA_TABLES
(
  source_db_link, source_owner, source_table_name, target_owner, target_table_name,
  parallel_degree, tablespace_name, days_online, enabled_flag
)
VALUES
(
  'DIST_ARCHIVER_LINK', 'PMGR_D_ARCHIVER', 'TBL_ARCHIVER_ORDERS_SRC',
  'PMGR_D_REPLICA', 'TBL_REPLICA_ORDERS_SRC', 4, 'USERS', 365, 'Y'
);

INSERT INTO TBL_REPLICA_PARTITIONS
(
  source_db_link, source_owner, source_table_name, target_owner, target_table_name,
  archive_unit_type, source_partition_name, source_subpartition_name,
  partition_name, subpartition_name, partition_high_value, subpartition_high_value,
  replica_status, quality_status, purge_status, source_row_count, target_row_count
)
VALUES
(
  'DIST_ARCHIVER_LINK', 'PMGR_D_ARCHIVER', 'TBL_ARCHIVER_ORDERS_SRC',
  'PMGR_D_REPLICA', 'TBL_REPLICA_ORDERS_SRC',
  'PARTITION', 'P_ERROR', '#', 'P_ERROR', '#',
  'TO_DATE('' 1800-01-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')',
  '#', 'Y', 'Y', 'Y', 0, 0
);

COMMIT;
