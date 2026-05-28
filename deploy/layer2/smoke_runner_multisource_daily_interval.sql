SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Running multisource daily interval runner smoke test (CLIENT1 + CLIENT2)

PROMPT
PROMPT ============================================================
PROMPT Step 1: Runner for CLIENT1 -> ORDERS_DAILY_INT_SRC
PROMPT ============================================================

BEGIN
  PKG_ARCHIVE_RUNNER.prc_run_table
  (
    p_source_db_link     => 'CLIENT1_LOOPBACK_LINK',
    p_owner           => 'CLIENT1',
    p_table_name      => 'ORDERS_DAILY_INT_SRC',
    p_execute         => 'Y',
    p_stop_after_step => 'QUALITY',
    p_truncate_execute => 'N'
  );
END;
/

PROMPT
PROMPT ============================================================
PROMPT Step 2: Runner for CLIENT2 -> ORDERS_DAILY_INT_SRC_2
PROMPT ============================================================

BEGIN
  PKG_ARCHIVE_RUNNER.prc_run_table
  (
    p_source_db_link     => 'CLIENT1_LOOPBACK_LINK',
    p_owner           => 'CLIENT2',
    p_table_name      => 'ORDERS_DAILY_INT_SRC',
    p_execute         => 'Y',
    p_stop_after_step => 'QUALITY',
    p_truncate_execute => 'N'
  );
END;
/

PROMPT
PROMPT ============================================================
PROMPT Verification: CLIENT1 target should have 96 rows
PROMPT ============================================================

SELECT COUNT(*) AS TARGET1_DAILYINT_ROWS FROM ORDERS_DAILY_INT_SRC;

PROMPT
PROMPT ============================================================
PROMPT Verification: CLIENT2 target should have 96 rows
PROMPT ============================================================

SELECT COUNT(*) AS TARGET2_DAILYINT_ROWS FROM ORDERS_DAILY_INT_SRC_2;

PROMPT
PROMPT ============================================================
PROMPT Verification: partition metadata
PROMPT ============================================================

COLUMN SOURCE_OWNER FORMAT A12
COLUMN SOURCE_TABLE_NAME FORMAT A22
COLUMN TARGET_TABLE_NAME FORMAT A22
COLUMN PARTITION_NAME FORMAT A14
COLUMN ARCHIVE_UNIT_TYPE FORMAT A14
COLUMN ARCHIVE_STATUS FORMAT A5
COLUMN SOURCE_ROW_COUNT FORMAT 999999
COLUMN TARGET_ROW_COUNT FORMAT 999999

SELECT p.SOURCE_OWNER,
       p.SOURCE_TABLE_NAME,
       p.TARGET_TABLE_NAME,
       p.PARTITION_NAME,
       p.ARCHIVE_UNIT_TYPE,
       p.ARCHIVE_STATUS,
       p.SOURCE_ROW_COUNT,
       p.TARGET_ROW_COUNT,
       p.QUALITY_STATUS,
       p.TRUNCATE_STATUS
  FROM TW_ARCHIVE_PARTITIONS p
 WHERE p.SOURCE_DB_LINK = 'CLIENT1_LOOPBACK_LINK'
   AND p.SOURCE_TABLE_NAME LIKE '%DAILY%'
 ORDER BY p.SOURCE_OWNER, p.PARTITION_POSITION, p.SUBPARTITION_POSITION;

PROMPT
PROMPT Multisource daily interval runner smoke test completed
