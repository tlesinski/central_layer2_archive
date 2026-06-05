SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Installing standalone ARCHIVER core objects

@@code_archiver/sequences/seq_archiver_process_log.sql
@@code_archiver/sequences/seq_archiver_stg_tmp.sql
@@code_archiver/tables/tbl_archiver_process_log.sql
@@code_archiver/tables/tbl_archiver_tables.sql
@@code_archiver/tables/tbl_archiver_runs.sql
@@code_archiver/tables/tbl_archiver_partitions.sql
@@code_archiver/functions/fn_archiver_high_value_date.sql
@@code_archiver/functions/fn_archiver_calculate_retention.sql
@@code_archiver/functions/fn_archiver_validate_preserve.sql
@@code_archiver/triggers/trg_archiver_tables_retention_calc.sql
@@code_archiver/triggers/trg_archiver_tables_preserve_calc.sql
@@code_archiver/views/vw_archiver_source_partitions.sql
@@code_archiver/views/vw_archiver_discovery_partitions.sql
@@code_archiver/views/vw_archiver_import_partitions.sql
@@code_archiver/views/vw_archiver_quality_partitions.sql
@@code_archiver/views/vw_archiver_truncate_partitions.sql
@@code_archiver/packages/pkg_archiver_tl_logging.spec.sql
@@code_archiver/packages/pkg_archiver_tl_logging.body.sql
@@code_archiver/packages/pkg_archiver_sql.spec.sql
@@code_archiver/packages/pkg_archiver_sql.body.sql
@@code_archiver/packages/pkg_archiver_log.spec.sql
@@code_archiver/packages/pkg_archiver_log.body.sql
@@code_archiver/packages/pkg_archiver_partition.spec.sql
@@code_archiver/packages/pkg_archiver_partition.body.sql
@@code_archiver/packages/pkg_archiver_discovery.spec.sql
@@code_archiver/packages/pkg_archiver_discovery.body.sql
@@code_archiver/packages/pkg_archiver_import.spec.sql
@@code_archiver/packages/pkg_archiver_import.body.sql
@@code_archiver/packages/pkg_archiver_quality.spec.sql
@@code_archiver/packages/pkg_archiver_quality.body.sql
@@code_archiver/packages/pkg_archiver_truncate.spec.sql
@@code_archiver/packages/pkg_archiver_truncate.body.sql
@@code_archiver/packages/pkg_archiver_runner.spec.sql
@@code_archiver/packages/pkg_archiver_runner.body.sql

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
