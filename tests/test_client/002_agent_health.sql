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
     AND table_name IN
         ('ORDERS_ARCH_SRC', 'ORDERS_SUBPART_SRC', 'ORDERS_DAILY_INT_SRC',
          'ORDERS_LIST_DATE_SRC', 'ORDERS_LIST_NUMBER_SRC', 'ORDERS_LIST_VARCHAR_SRC');

  IF l_count != 9 THEN
    RAISE_APPLICATION_ERROR(-20521, 'AGENT should see 9 seeded client tables, got ' || l_count);
  END IF;

  SELECT COUNT(DISTINCT table_name)
    INTO l_count
    FROM VW_AGENT_PARTITION_INFO
   WHERE schema_name = UPPER('&&CLIENT1_SCHEMA')
     AND
     (
       (table_name = 'ORDERS_LIST_DATE_SRC'
        AND partition_method = 'LIST'
        AND subpartition_method IS NULL
        AND partition_key_data_type = 'DATE')
       OR
       (table_name = 'ORDERS_LIST_NUMBER_SRC'
        AND partition_method = 'LIST'
        AND subpartition_method IS NULL
        AND partition_key_data_type = 'NUMBER')
       OR
       (table_name = 'ORDERS_LIST_VARCHAR_SRC'
        AND partition_method = 'LIST'
        AND subpartition_method = 'LIST'
        AND partition_key_data_type = 'VARCHAR2'
        AND subpartition_key_data_type = 'VARCHAR2')
     );

  IF l_count != 3 THEN
    RAISE_APPLICATION_ERROR(-20522, 'AGENT LIST method/type metadata is incomplete');
  END IF;
END;
/

PROMPT CLIENT 002 completed
