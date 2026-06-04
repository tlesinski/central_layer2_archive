SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Installing Central Layer 3 Replica core objects

@layer2_core/sequences/md_process_log_seq.sql
@layer3_replica/sequences/stg_tmp_replica_seq.sql
@layer2_core/tables/md_process_log.sql
@layer2_core/packages/pkg_tl_logging.spec.sql
@layer2_core/packages/pkg_tl_logging.body.sql
@layer2_core/functions/fn_archive_high_value_date.sql
@layer2_core/packages/pkg_sql.spec.sql
@layer2_core/packages/pkg_sql.body.sql
@deploy/layer3/create_carch_loopback_link.sql
@deploy/layer3/create_carch_synonyms.sql
@layer3_replica/tables/tw_replica_tables.sql
@layer3_replica/tables/tw_replica_runs.sql
@layer3_replica/tables/tw_replica_partitions.sql
@layer3_replica/views/tw_replica_source_partitions_vw.sql
@layer3_replica/views/tw_replica_discovery_partitions_vw.sql
@layer3_replica/views/tw_replica_replicate_partitions_vw.sql
@layer3_replica/views/tw_replica_quality_partitions_vw.sql
@layer3_replica/views/tw_replica_purge_partitions_vw.sql
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

SHOW ERRORS PACKAGE PKG_TL_LOGGING
SHOW ERRORS PACKAGE BODY PKG_TL_LOGGING
SHOW ERRORS FUNCTION FN_ARCHIVE_HIGH_VALUE_DATE
SHOW ERRORS PACKAGE PKG_SQL
SHOW ERRORS PACKAGE BODY PKG_SQL
SHOW ERRORS VIEW TW_REPLICA_SOURCE_PARTITIONS_VW
SHOW ERRORS VIEW TW_REPLICA_DISCOVERY_PARTITIONS_VW
SHOW ERRORS VIEW TW_REPLICA_REPLICATE_PARTITIONS_VW
SHOW ERRORS VIEW TW_REPLICA_QUALITY_PARTITIONS_VW
SHOW ERRORS VIEW TW_REPLICA_PURGE_PARTITIONS_VW
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

PROMPT Central Layer 3 Replica core install completed
