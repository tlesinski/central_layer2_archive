SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Installing standalone REPLICA core objects

@@code_replica/sequences/seq_replica_process_log.sql
@@code_replica/sequences/seq_replica_stg_tmp.sql
@@code_replica/tables/tbl_replica_process_log.sql
@@code_replica/functions/fn_replica_high_value_date.sql
@@code_replica/packages/pkg_replica_tl_logging.spec.sql
@@code_replica/packages/pkg_replica_tl_logging.body.sql
@@code_replica/packages/pkg_replica_sql.spec.sql
@@code_replica/packages/pkg_replica_sql.body.sql
@@code_replica/tables/tbl_replica_tables.sql
@@code_replica/tables/tbl_replica_runs.sql
@@code_replica/tables/tbl_replica_partitions.sql
@@code_replica/views/vw_replica_source_partitions.sql
@@code_replica/views/vw_replica_discovery_partitions.sql
@@code_replica/views/vw_replica_replicate_partitions.sql
@@code_replica/views/vw_replica_quality_partitions.sql
@@code_replica/views/vw_replica_purge_partitions.sql
@@code_replica/packages/pkg_replica_log.spec.sql
@@code_replica/packages/pkg_replica_log.body.sql
@@code_replica/packages/pkg_replica_discovery.spec.sql
@@code_replica/packages/pkg_replica_discovery.body.sql
@@code_replica/packages/pkg_replica_partition.spec.sql
@@code_replica/packages/pkg_replica_partition.body.sql
@@code_replica/packages/pkg_replica_replicate.spec.sql
@@code_replica/packages/pkg_replica_replicate.body.sql
@@code_replica/packages/pkg_replica_quality.spec.sql
@@code_replica/packages/pkg_replica_quality.body.sql
@@code_replica/packages/pkg_replica_purge.spec.sql
@@code_replica/packages/pkg_replica_purge.body.sql
@@code_replica/packages/pkg_replica_runner.spec.sql
@@code_replica/packages/pkg_replica_runner.body.sql

SHOW ERRORS PACKAGE PKG_REPLICA_TL_LOGGING
SHOW ERRORS PACKAGE BODY PKG_REPLICA_TL_LOGGING
SHOW ERRORS PACKAGE PKG_REPLICA_SQL
SHOW ERRORS PACKAGE BODY PKG_REPLICA_SQL
SHOW ERRORS PACKAGE PKG_REPLICA_LOG
SHOW ERRORS PACKAGE BODY PKG_REPLICA_LOG
SHOW ERRORS PACKAGE PKG_REPLICA_DISCOVERY
SHOW ERRORS PACKAGE BODY PKG_REPLICA_DISCOVERY
SHOW ERRORS PACKAGE PKG_REPLICA_PARTITION
SHOW ERRORS PACKAGE BODY PKG_REPLICA_PARTITION
SHOW ERRORS PACKAGE PKG_REPLICA_REPLICATE
SHOW ERRORS PACKAGE BODY PKG_REPLICA_REPLICATE
SHOW ERRORS PACKAGE PKG_REPLICA_QUALITY
SHOW ERRORS PACKAGE BODY PKG_REPLICA_QUALITY
SHOW ERRORS PACKAGE PKG_REPLICA_PURGE
SHOW ERRORS PACKAGE BODY PKG_REPLICA_PURGE
SHOW ERRORS PACKAGE PKG_REPLICA_RUNNER
SHOW ERRORS PACKAGE BODY PKG_REPLICA_RUNNER

PROMPT Standalone REPLICA core install completed
