SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Running CLIENT1_LOOPBACK_LINK full remote-path smoke flow

BEGIN
  PKG_ARCHIVE_DISCOVERY.prc_discover(p_execute => 'Y');
END;
/

BEGIN
  PKG_ARCHIVE_IMPORT.prc_import
  (
    p_execute           => 'Y',
    p_target_owner      => 'CARCH',
    p_target_table_name => 'ORDERS_ARCH_SRC'
  );
END;
/

BEGIN
  PKG_ARCHIVE_QUALITY.prc_quality
  (
    p_execute           => 'Y',
    p_target_owner      => 'CARCH',
    p_target_table_name => 'ORDERS_ARCH_SRC'
  );
END;
/

SELECT p.SOURCE_DB_LINK,
       p.PARTITION_NAME,
       p.ARCHIVE_STATUS,
       p.SOURCE_ROW_COUNT,
       p.TARGET_ROW_COUNT,
       p.QUALITY_STATUS,
       p.TRUNCATE_STATUS
  FROM TW_ARCHIVE_PARTITIONS p
 WHERE p.SOURCE_DB_LINK = 'CLIENT1_LOOPBACK_LINK'
 ORDER BY p.PARTITION_HIGH_VALUE, p.SUBPARTITION_HIGH_VALUE;

PROMPT CLIENT1_LOOPBACK_LINK full remote-path smoke flow completed
