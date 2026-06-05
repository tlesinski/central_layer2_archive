PROMPT CLIENT 002 - AGENT health and metadata visibility

CONNECT &&ACTIVE_AGENT_SCHEMA/"&&ACTIVE_AGENT_PASSWORD"@&&ACTIVE_AGENT_CONNECT

DECLARE
  l_health VARCHAR2(4000);
  l_count NUMBER;
BEGIN
  l_health := PKG_AGENT_ARCHIVE.fn_health_check;
  IF l_health NOT LIKE 'OK:%' THEN
    RAISE_APPLICATION_ERROR(-20520, 'AGENT health check failed: ' || l_health);
  END IF;

  SELECT COUNT(DISTINCT schema_name || '.' || table_name)
    INTO l_count
    FROM VW_AGENT_PARTITION_INFO
   WHERE schema_name IN (UPPER('&&CLIENT1_SCHEMA'), UPPER('&&CLIENT2_SCHEMA'))
     AND table_name IN ('ORDERS_ARCH_SRC', 'ORDERS_SUBPART_SRC', 'ORDERS_DAILY_INT_SRC');

  IF l_count != 6 THEN
    RAISE_APPLICATION_ERROR(-20521, 'AGENT should see 6 seeded client tables, got ' || l_count);
  END IF;
END;
/

PROMPT CLIENT 002 completed
