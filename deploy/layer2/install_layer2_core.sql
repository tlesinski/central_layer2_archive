SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Installing Central Layer 2 Archive core objects

@@../../layer2_core/sequences/md_process_log_seq.sql
@@../../layer2_core/tables/md_process_log.sql
@@../../layer2_core/tables/tw_archive_tables.sql
@@../../layer2_core/tables/tw_archive_runs.sql
@@../../layer2_core/tables/tw_archive_partitions.sql
@@../../layer2_core/packages/pkg_tl_logging.spec.sql
@@../../layer2_core/packages/pkg_tl_logging.body.sql
@@../../layer2_core/packages/pkg_sql.spec.sql
@@../../layer2_core/packages/pkg_sql.body.sql
@@../../layer2_core/packages/pkg_archive_log.spec.sql
@@../../layer2_core/packages/pkg_archive_log.body.sql
@@../../layer2_core/packages/pkg_archive_partition.spec.sql
@@../../layer2_core/packages/pkg_archive_partition.body.sql
@@../../layer2_core/packages/pkg_archive_discovery.spec.sql
@@../../layer2_core/packages/pkg_archive_discovery.body.sql
@@../../layer2_core/packages/pkg_archive_import.spec.sql
@@../../layer2_core/packages/pkg_archive_import.body.sql
@@../../layer2_core/packages/pkg_archive_quality.spec.sql
@@../../layer2_core/packages/pkg_archive_quality.body.sql
@@../../layer2_core/packages/pkg_archive_truncate.spec.sql
@@../../layer2_core/packages/pkg_archive_truncate.body.sql
@@../../layer2_core/packages/pkg_archive_runner.spec.sql
@@../../layer2_core/packages/pkg_archive_runner.body.sql

SHOW ERRORS PACKAGE PKG_TL_LOGGING
SHOW ERRORS PACKAGE BODY PKG_TL_LOGGING
SHOW ERRORS PACKAGE PKG_SQL
SHOW ERRORS PACKAGE BODY PKG_SQL
SHOW ERRORS PACKAGE PKG_ARCHIVE_LOG
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_LOG
SHOW ERRORS PACKAGE PKG_ARCHIVE_PARTITION
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_PARTITION
SHOW ERRORS PACKAGE PKG_ARCHIVE_DISCOVERY
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_DISCOVERY
SHOW ERRORS PACKAGE PKG_ARCHIVE_IMPORT
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_IMPORT
SHOW ERRORS PACKAGE PKG_ARCHIVE_QUALITY
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_QUALITY
SHOW ERRORS PACKAGE PKG_ARCHIVE_TRUNCATE
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_TRUNCATE
SHOW ERRORS PACKAGE PKG_ARCHIVE_RUNNER
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_RUNNER

PROMPT Central Layer 2 Archive core install completed
