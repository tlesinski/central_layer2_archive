SET DEFINE ON
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

BEGIN
  PKG_ARCHIVER_RUNNER.prc_run_table
  (
    p_source_db_link      => UPPER('&1'),
    p_owner               => 'CLIENT1',
    p_table_name          => 'ORDERS_ARCH_SRC',
    p_execute             => 'Y',
    p_stop_after_step     => 'TRUNCATE',
    p_truncate_execute    => 'N'
  );
END;
/

SELECT COUNT(*) AS target_rows
  FROM TBL_ARCHIVER_ORDERS_SRC;

SELECT COUNT(*) AS quality_failures
  FROM TBL_ARCHIVER_PARTITIONS
 WHERE source_db_link = UPPER('&1')
   AND archive_status = 'Y'
   AND quality_status <> 'Y';

SELECT COUNT(*) AS source_rows_after_preview
  FROM CLIENT1.ORDERS_ARCH_SRC@&1;
