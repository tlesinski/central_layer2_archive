SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Installing standalone ARCHIVER core objects

@layer2_core/sequences/archiver_process_log_seq.sql
@layer2_core/sequences/archiver_stg_tmp_seq.sql
@layer2_core/tables/tbl_archiver_process_log.sql
@layer2_core/tables/tbl_archiver_tables.sql
@layer2_core/tables/tbl_archiver_runs.sql
@layer2_core/tables/tbl_archiver_partitions.sql
@layer2_core/functions/fn_archiver_high_value_date.sql
@layer2_core/functions/fn_archiver_calculate_retention.sql
@layer2_core/functions/fn_archiver_validate_preserve.sql
@layer2_core/triggers/trg_archiver_tables_retention_calc.sql
@layer2_core/triggers/trg_archiver_tables_preserve_calc.sql
@layer2_core/views/vw_archiver_source_partitions.sql
@layer2_core/views/vw_archiver_discovery_partitions.sql
@layer2_core/views/vw_archiver_import_partitions.sql
@layer2_core/views/vw_archiver_quality_partitions.sql
@layer2_core/views/vw_archiver_truncate_partitions.sql
@layer2_core/packages/pkg_archiver_tl_logging.spec.sql
@layer2_core/packages/pkg_archiver_tl_logging.body.sql
@layer2_core/packages/pkg_archiver_sql.spec.sql
@layer2_core/packages/pkg_archiver_sql.body.sql
@layer2_core/packages/pkg_archiver_log.spec.sql
@layer2_core/packages/pkg_archiver_log.body.sql
@layer2_core/packages/pkg_archiver_partition.spec.sql
@layer2_core/packages/pkg_archiver_partition.body.sql
@layer2_core/packages/pkg_archiver_discovery.spec.sql
@layer2_core/packages/pkg_archiver_discovery.body.sql
@layer2_core/packages/pkg_archiver_import.spec.sql
@layer2_core/packages/pkg_archiver_import.body.sql
@layer2_core/packages/pkg_archiver_quality.spec.sql
@layer2_core/packages/pkg_archiver_quality.body.sql
@layer2_core/packages/pkg_archiver_truncate.spec.sql
@layer2_core/packages/pkg_archiver_truncate.body.sql
@layer2_core/packages/pkg_archiver_runner.spec.sql
@layer2_core/packages/pkg_archiver_runner.body.sql

SHOW ERRORS PACKAGE PKG_ARCHIVER_TL_LOGGING
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_TL_LOGGING
SHOW ERRORS PACKAGE PKG_ARCHIVER_SQL
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_SQL
SHOW ERRORS PACKAGE PKG_ARCHIVER_LOG
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_LOG
SHOW ERRORS PACKAGE PKG_ARCHIVER_PARTITION
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_PARTITION
SHOW ERRORS PACKAGE PKG_ARCHIVER_DISCOVERY
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_DISCOVERY
SHOW ERRORS PACKAGE PKG_ARCHIVER_IMPORT
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_IMPORT
SHOW ERRORS PACKAGE PKG_ARCHIVER_QUALITY
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_QUALITY
SHOW ERRORS PACKAGE PKG_ARCHIVER_TRUNCATE
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_TRUNCATE
SHOW ERRORS PACKAGE PKG_ARCHIVER_RUNNER
SHOW ERRORS PACKAGE BODY PKG_ARCHIVER_RUNNER

PROMPT Standalone ARCHIVER core install completed
