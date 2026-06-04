SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Running standalone AGENT smoke test

SELECT PKG_AGENT_ARCHIVE.fn_health_check AS agent_health
  FROM dual;

SELECT COUNT(*) AS metadata_rows
  FROM VW_AGENT_PARTITION_INFO
 WHERE schema_name = 'CLIENT1'
   AND table_name = 'ORDERS_ARCH_SRC';

SELECT PKG_AGENT_ARCHIVE.fn_get_row_count
       ('CLIENT1', 'ORDERS_ARCH_SRC', 'P202401', NULL) AS p202401_rows
  FROM dual;

BEGIN
  PKG_AGENT_ARCHIVE.prc_cleanup_unit
  (
    p_owner          => 'CLIENT1',
    p_table_name     => 'ORDERS_ARCH_SRC',
    p_partition_name => 'P202401',
    p_mode           => 'TRUNCATE',
    p_execute        => 'N'
  );
END;
/

SELECT COUNT(*) AS p202401_rows_after_preview
  FROM CLIENT1.ORDERS_ARCH_SRC PARTITION (P202401);

PROMPT Standalone AGENT smoke test completed
