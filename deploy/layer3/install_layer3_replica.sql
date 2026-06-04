SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Installing standalone REPLICA core objects

@layer3_replica/sequences/replica_process_log_seq.sql
@layer3_replica/sequences/replica_stg_tmp_seq.sql
@layer3_replica/tables/tbl_replica_process_log.sql
@layer3_replica/functions/fn_replica_high_value_date.sql
@layer3_replica/packages/pkg_replica_tl_logging.spec.sql
@layer3_replica/packages/pkg_replica_tl_logging.body.sql
@layer3_replica/packages/pkg_replica_sql.spec.sql
@layer3_replica/packages/pkg_replica_sql.body.sql
@layer3_replica/tables/tbl_replica_tables.sql
@layer3_replica/tables/tbl_replica_runs.sql
@layer3_replica/tables/tbl_replica_partitions.sql
@layer3_replica/views/vw_replica_source_partitions.sql
@layer3_replica/views/vw_replica_discovery_partitions.sql
@layer3_replica/views/vw_replica_replicate_partitions.sql
@layer3_replica/views/vw_replica_quality_partitions.sql
@layer3_replica/views/vw_replica_purge_partitions.sql
@layer3_replica/packages/pkg_replica_log.spec.sql
@layer3_replica/packages/pkg_replica_log.body.sql
@layer3_replica/packages/pkg_replica_discovery.spec.sql
@layer3_replica/packages/pkg_replica_discovery.body.sql
@layer3_replica/packages/pkg_replica_partition.spec.sql
@layer3_replica/packages/pkg_replica_partition.body.sql
@layer3_replica/packages/pkg_replica_replicate.spec.sql
@layer3_replica/packages/pkg_replica_replicate.body.sql
@layer3_replica/packages/pkg_replica_quality.spec.sql
@layer3_replica/packages/pkg_replica_quality.body.sql
@layer3_replica/packages/pkg_replica_purge.spec.sql
@layer3_replica/packages/pkg_replica_purge.body.sql
@layer3_replica/packages/pkg_replica_runner.spec.sql
@layer3_replica/packages/pkg_replica_runner.body.sql

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
