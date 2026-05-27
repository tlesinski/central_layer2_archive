SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Running CLIENT1_LOOPBACK_LINK full remote-path smoke flow

BEGIN
  PKG_ARCHIVE_DISCOVERY.discover_table
  (
    p_source_db_link => 'CLIENT1_LOOPBACK_LINK',
    p_owner          => 'CLIENT1',
    p_table_name     => 'ORDERS_ARCH_SRC',
    p_execute        => 'Y'
  );
END;
/

BEGIN
  PKG_ARCHIVE_IMPORT.import_table
  (
    p_source_db_link => 'CLIENT1_LOOPBACK_LINK',
    p_owner          => 'CLIENT1',
    p_table_name     => 'ORDERS_ARCH_SRC',
    p_execute        => 'Y'
  );
END;
/

BEGIN
  PKG_ARCHIVE_QUALITY.check_table
  (
    p_source_db_link => 'CLIENT1_LOOPBACK_LINK',
    p_owner          => 'CLIENT1',
    p_table_name     => 'ORDERS_ARCH_SRC',
    p_execute        => 'Y'
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
 ORDER BY p.PARTITION_POSITION, p.SUBPARTITION_POSITION;

PROMPT CLIENT1_LOOPBACK_LINK full remote-path smoke flow completed
