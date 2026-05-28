SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Running CLIENT1_LOOPBACK_LINK subpartition exchange runner smoke test

BEGIN
  PKG_ARCHIVE_RUNNER.prc_run_table
  (
    p_source_db_link     => 'CLIENT1_LOOPBACK_LINK',
    p_owner              => 'CLIENT1',
    p_table_name         => 'ORDERS_SUBPART_SRC',
    p_execute            => 'Y',
    p_stop_after_step    => 'QUALITY',
    p_truncate_execute   => 'N'
  );
END;
/

SELECT p.SOURCE_DB_LINK,
       p.PARTITION_NAME,
       p.SUBPARTITION_NAME,
       p.ARCHIVE_STATUS,
       p.SOURCE_ROW_COUNT,
       p.TARGET_ROW_COUNT,
       p.QUALITY_STATUS,
       p.TRUNCATE_STATUS
  FROM TW_ARCHIVE_PARTITIONS p
 WHERE p.SOURCE_DB_LINK = 'CLIENT1_LOOPBACK_LINK'
   AND p.SOURCE_TABLE_NAME = 'ORDERS_SUBPART_SRC'
 ORDER BY p.PARTITION_POSITION, p.SUBPARTITION_POSITION;

SELECT COUNT(*) AS TARGET_ROWS
  FROM ORDERS_SUBPART_SRC;

SELECT table_name
  FROM user_tables
 WHERE table_name LIKE 'STG\_%' ESCAPE '\';

PROMPT CLIENT1_LOOPBACK_LINK subpartition exchange runner smoke test completed
