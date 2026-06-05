PROMPT CLIENT 003 - AGENT controlled row counts

CONNECT &&ACTIVE_AGENT_SCHEMA/"&&ACTIVE_AGENT_PASSWORD"@&&ACTIVE_AGENT_CONNECT

DECLARE
  PROCEDURE assert_agent_count
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL
  ) IS
    l_sql VARCHAR2(4000);
    l_direct_count NUMBER;
    l_agent_count NUMBER;
  BEGIN
    l_sql := 'SELECT COUNT(*) FROM ' ||
             DBMS_ASSERT.SIMPLE_SQL_NAME(p_owner) || '.' ||
             DBMS_ASSERT.SIMPLE_SQL_NAME(p_table_name);

    IF p_subpartition_name IS NULL THEN
      l_sql := l_sql || ' PARTITION (' || DBMS_ASSERT.SIMPLE_SQL_NAME(p_partition_name) || ')';
    ELSE
      l_sql := l_sql || ' SUBPARTITION (' || DBMS_ASSERT.SIMPLE_SQL_NAME(p_subpartition_name) || ')';
    END IF;

    EXECUTE IMMEDIATE l_sql INTO l_direct_count;
    l_agent_count := PKG_AGENT_ARCHIVE.fn_get_row_count
                     (
                       p_owner,
                       p_table_name,
                       p_partition_name,
                       p_subpartition_name
                     );

    IF l_direct_count != l_agent_count THEN
      RAISE_APPLICATION_ERROR
      (
        -20530,
        p_owner || '.' || p_table_name || '.' || p_partition_name ||
        NVL2(p_subpartition_name, '.' || p_subpartition_name, '') ||
        ' direct count=' || l_direct_count || ', agent count=' || l_agent_count
      );
    END IF;
  END;

  FUNCTION first_subpartition
  (
    p_owner          IN VARCHAR2,
    p_table_name     IN VARCHAR2,
    p_partition_name IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_name VARCHAR2(128);
  BEGIN
    SELECT subpartition_name
      INTO l_name
      FROM all_tab_subpartitions
     WHERE table_owner = UPPER(p_owner)
       AND table_name = UPPER(p_table_name)
       AND partition_name = UPPER(p_partition_name)
       AND ROWNUM = 1;

    RETURN l_name;
  END;
BEGIN
  assert_agent_count(UPPER('&&CLIENT1_SCHEMA'), 'ORDERS_ARCH_SRC', 'P202401');
  assert_agent_count(UPPER('&&CLIENT2_SCHEMA'), 'ORDERS_ARCH_SRC', 'P202401');
  assert_agent_count(UPPER('&&CLIENT1_SCHEMA'), 'ORDERS_DAILY_INT_SRC', 'P20240501');
  assert_agent_count(UPPER('&&CLIENT2_SCHEMA'), 'ORDERS_DAILY_INT_SRC', 'P20240501');

  assert_agent_count
  (
    UPPER('&&CLIENT1_SCHEMA'),
    'ORDERS_SUBPART_SRC',
    'P202401',
    first_subpartition(UPPER('&&CLIENT1_SCHEMA'), 'ORDERS_SUBPART_SRC', 'P202401')
  );

  assert_agent_count
  (
    UPPER('&&CLIENT2_SCHEMA'),
    'ORDERS_SUBPART_SRC',
    'P202401',
    first_subpartition(UPPER('&&CLIENT2_SCHEMA'), 'ORDERS_SUBPART_SRC', 'P202401')
  );
END;
/

PROMPT CLIENT 003 completed
