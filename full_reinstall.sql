SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT ============================================================
PROMPT Full reinstall of Central Layer 2 Archive
PROMPT
PROMPT Prerequisites:
PROMPT   - Users CARCH, CAGENT1, CLIENT1 must exist
PROMPT   - Run deploy/drop_all_schemas.sql first for a clean slate
PROMPT   - This script connects as SYS for most steps, then as CARCH
PROMPT     for DB link creation (uses CarchDev2026_42 convention)
PROMPT   - CLIENT2 is created automatically if not present
PROMPT ============================================================

SPOOL full_reinstall.log

PROMPT
PROMPT ============================================================
PROMPT Step 0: Creating CLIENT2 user if not exists
PROMPT ============================================================

DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM dba_users WHERE username = 'CLIENT2';
  IF l_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER CLIENT2 IDENTIFIED BY CLIENT2' ||
                      ' DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS';
    EXECUTE IMMEDIATE 'GRANT CONNECT TO CLIENT2';
    EXECUTE IMMEDIATE 'GRANT CREATE TABLE TO CLIENT2';
    EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO CLIENT2';
    DBMS_OUTPUT.PUT_LINE('CLIENT2 user created');
  ELSE
    DBMS_OUTPUT.PUT_LINE('CLIENT2 user already exists');
  END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT Step 1: Installing CLIENT1 source tables
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CLIENT1;

@deploy/client1/install_client1_test_source.sql
@deploy/client1/install_client1_subpart_test_source.sql
@deploy/client1/install_client1_daily_interval_test_source.sql

PROMPT
PROMPT ============================================================
PROMPT Step 1b: Installing CLIENT2 source tables
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CLIENT2;

@deploy/client2/install_client2_test_source.sql
@deploy/client2/install_client2_subpart_test_source.sql
@deploy/client2/install_client2_daily_interval_test_source.sql

PROMPT
PROMPT ============================================================
PROMPT Step 2: Granting CLIENT1 access to CAGENT1 and CARCH
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CLIENT1;

@deploy/client1/grant_client1_to_cagent1.sql
@deploy/client1/grant_client1_subpart_to_cagent1.sql
@deploy/client1/grant_client1_daily_interval_to_cagent1.sql
@deploy/client1/grant_cleanup_admin_to_cagent1.sql

PROMPT
PROMPT ============================================================
PROMPT Step 2b: Granting CLIENT2 access to CAGENT1 and CARCH
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CLIENT2;

@deploy/client2/grant_client2_to_cagent1.sql
@deploy/client2/grant_client2_subpart_to_cagent1.sql
@deploy/client2/grant_client2_daily_interval_to_cagent1.sql

PROMPT
PROMPT ============================================================
PROMPT Step 3: Installing CAGENT1 layer 1 agent
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CAGENT1;

@layer1_agent/types/archive_partition_info_obj.sql
@layer1_agent/types/archive_partition_info_tab.sql
@layer1_agent/views/archive_partition_info_vw.sql
@layer1_agent/packages/pkg_archive_agent.spec.sql
@layer1_agent/packages/pkg_archive_agent.body.sql

SHOW ERRORS PACKAGE PKG_ARCHIVE_AGENT
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_AGENT

PROMPT
PROMPT ============================================================
PROMPT Step 4: Granting CAGENT1 agent access to CARCH
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CAGENT1;

GRANT EXECUTE ON ARCHIVE_PARTITION_INFO_OBJ TO CARCH;
GRANT EXECUTE ON ARCHIVE_PARTITION_INFO_TAB TO CARCH;
GRANT EXECUTE ON PKG_ARCHIVE_AGENT TO CARCH;
GRANT SELECT ON ARCHIVE_PARTITION_INFO_VW TO CARCH;

PROMPT
PROMPT ============================================================
PROMPT Step 5: Installing CARCH layer 2 core
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CARCH;

@layer2_core/sequences/md_process_log_seq.sql
@deploy/layer2/sequences/stg_tmp_arch_seq.sql
@layer2_core/tables/md_process_log.sql
@layer2_core/tables/tw_archive_tables.sql
@layer2_core/tables/tw_archive_runs.sql
@layer2_core/tables/tw_archive_partitions.sql
@layer2_core/functions/fn_archive_high_value_date.sql
@deploy/test_support/dat.spec.sql
@deploy/test_support/dat.body.sql
@layer2_core/views/tw_archive_source_partitions_vw.sql
@layer2_core/views/tw_archive_discovery_partitions_vw.sql
@layer2_core/views/tw_archive_import_partitions_vw.sql
@layer2_core/views/tw_archive_quality_partitions_vw.sql
@layer2_core/views/tw_archive_truncate_partitions_vw.sql
@layer2_core/packages/pkg_tl_logging.spec.sql
@layer2_core/packages/pkg_tl_logging.body.sql
@layer2_core/packages/pkg_sql.spec.sql
@layer2_core/packages/pkg_sql.body.sql
@layer2_core/packages/pkg_archive_log.spec.sql
@layer2_core/packages/pkg_archive_log.body.sql
@layer2_core/packages/pkg_archive_partition.spec.sql
@layer2_core/packages/pkg_archive_partition.body.sql
@layer2_core/packages/pkg_archive_discovery.spec.sql
@layer2_core/packages/pkg_archive_discovery.body.sql
@layer2_core/packages/pkg_archive_import.spec.sql
@layer2_core/packages/pkg_archive_import.body.sql
@layer2_core/packages/pkg_archive_quality.spec.sql
@layer2_core/packages/pkg_archive_quality.body.sql
@layer2_core/packages/pkg_archive_truncate.spec.sql
@layer2_core/packages/pkg_archive_truncate.body.sql
@layer2_core/packages/pkg_archive_runner.spec.sql
@layer2_core/packages/pkg_archive_runner.body.sql

SHOW ERRORS PACKAGE PKG_TL_LOGGING
SHOW ERRORS PACKAGE BODY PKG_TL_LOGGING
SHOW ERRORS FUNCTION FN_ARCHIVE_HIGH_VALUE_DATE
SHOW ERRORS VIEW TW_ARCHIVE_SOURCE_PARTITIONS_VW
SHOW ERRORS VIEW TW_ARCHIVE_DISCOVERY_PARTITIONS_VW
SHOW ERRORS VIEW TW_ARCHIVE_IMPORT_PARTITIONS_VW
SHOW ERRORS VIEW TW_ARCHIVE_QUALITY_PARTITIONS_VW
SHOW ERRORS VIEW TW_ARCHIVE_TRUNCATE_PARTITIONS_VW
SHOW ERRORS PACKAGE PKG_SQL
SHOW ERRORS PACKAGE BODY PKG_SQL
SHOW ERRORS PACKAGE DAT
SHOW ERRORS PACKAGE BODY DAT
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

PROMPT
PROMPT ============================================================
PROMPT Step 6: Granting CREATE DATABASE LINK to CARCH
PROMPT ============================================================

GRANT CREATE DATABASE LINK TO CARCH;

PROMPT
PROMPT ============================================================
PROMPT Step 7: Creating CLIENT1 loopback DB link (as CARCH)
PROMPT ============================================================

CONNECT CARCH/CarchDev2026_42@localhost:1521/freepdb1

SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

BEGIN
  EXECUTE IMMEDIATE 'DROP DATABASE LINK CLIENT1_LOOPBACK_LINK';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2024 THEN
      RAISE;
    END IF;
END;
/

CREATE DATABASE LINK CLIENT1_LOOPBACK_LINK
  CONNECT TO CAGENT1 IDENTIFIED BY "Cagent1Dev2026_42"
  USING '//localhost:1521/FREEPDB1';

SELECT * FROM dual@CLIENT1_LOOPBACK_LINK;

PROMPT ============================================================
PROMPT Reconnecting as SYS
PROMPT ============================================================

CONNECT SYS/r14@localhost:1521/freepdb1 AS SYSDBA

SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT
PROMPT ============================================================
PROMPT Step 8: Installing target archive tables
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CARCH;

@deploy/layer2/install_orders_archive_target.sql
@deploy/layer2/install_orders_subpart_archive_target.sql
@deploy/layer2/install_orders_daily_interval_archive_target.sql
@deploy/layer2/install_orders_archive_target2.sql
@deploy/layer2/install_orders_subpart_archive_target2.sql
@deploy/layer2/install_orders_daily_interval_archive_target2.sql

PROMPT
PROMPT ============================================================
PROMPT Step 9: Seeding metadata configuration
PROMPT ============================================================

ALTER SESSION SET CURRENT_SCHEMA = CARCH;

@deploy/layer2/seed_client1_loopback.sql
@deploy/layer2/seed_client1_loopback_subpart.sql
@deploy/layer2/seed_client1_loopback_daily_interval.sql
@deploy/layer2/seed_client2_loopback.sql
@deploy/layer2/seed_client2_loopback_subpart.sql
@deploy/layer2/seed_client2_loopback_daily_interval.sql

PROMPT
PROMPT ============================================================
PROMPT Full reinstall completed.
PROMPT Check full_reinstall.log for details.
PROMPT ============================================================

SPOOL OFF
