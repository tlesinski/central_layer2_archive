PROMPT CLIENT 001 - source tables

CONNECT &&CLIENT1_SCHEMA/"&&CLIENT1_PASSWORD"@&&SOURCE_SYS_CONNECT

DECLARE
  l_count NUMBER;

  PROCEDURE assert_eq(p_name IN VARCHAR2, p_actual IN NUMBER, p_expected IN NUMBER) IS
  BEGIN
    IF p_actual != p_expected THEN
      RAISE_APPLICATION_ERROR(-20510, p_name || ' expected ' || p_expected || ', got ' || p_actual);
    END IF;
  END;

  PROCEDURE assert_table
  (
    p_table_name           IN VARCHAR2,
    p_rows                 IN NUMBER,
    p_partitioning_type    IN VARCHAR2,
    p_subpartitioning_type IN VARCHAR2
  ) IS
    l_rows NUMBER;
    l_partitioning_type VARCHAR2(30);
    l_subpartitioning_type VARCHAR2(30);
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.SIMPLE_SQL_NAME(p_table_name)
      INTO l_rows;

    SELECT partitioning_type, subpartitioning_type
      INTO l_partitioning_type, l_subpartitioning_type
      FROM user_part_tables
     WHERE table_name = UPPER(p_table_name);

    assert_eq(USER || '.' || p_table_name || ' rows', l_rows, p_rows);

    IF l_partitioning_type <> p_partitioning_type
       OR NVL(l_subpartitioning_type, 'NONE') <> p_subpartitioning_type THEN
      RAISE_APPLICATION_ERROR
      (
        -20511,
        USER || '.' || p_table_name || ' partitioning expected ' ||
        p_partitioning_type || '/' || p_subpartitioning_type || ', got ' ||
        l_partitioning_type || '/' || NVL(l_subpartitioning_type, 'NONE')
      );
    END IF;
  END;

BEGIN
  assert_table('ORDERS_ARCH_SRC', 430, 'RANGE', 'NONE');
  assert_table('ORDERS_SUBPART_SRC', 540, 'RANGE', 'LIST');
  assert_table('ORDERS_DAILY_INT_SRC', 96, 'RANGE', 'LIST');

  SELECT COUNT(*)
    INTO l_count
    FROM user_tab_partitions
   WHERE table_name = 'ORDERS_DAILY_INT_SRC'
     AND partition_name LIKE 'SYS\_P%' ESCAPE '\';
  assert_eq(USER || '.ORDERS_DAILY_INT_SRC SYS_P partitions', l_count, 0);

  SELECT COUNT(*)
    INTO l_count
    FROM user_tab_partitions
   WHERE table_name = 'ORDERS_DAILY_INT_SRC'
     AND partition_name IN ('P20240501', 'P20240502', 'P20240503', 'P20240504');
  assert_eq(USER || '.ORDERS_DAILY_INT_SRC PYYYYMMDD partitions', l_count, 4);
END;
/

CONNECT &&CLIENT2_SCHEMA/"&&CLIENT2_PASSWORD"@&&SOURCE_SYS_CONNECT

DECLARE
  l_count NUMBER;

  PROCEDURE assert_eq(p_name IN VARCHAR2, p_actual IN NUMBER, p_expected IN NUMBER) IS
  BEGIN
    IF p_actual != p_expected THEN
      RAISE_APPLICATION_ERROR(-20512, p_name || ' expected ' || p_expected || ', got ' || p_actual);
    END IF;
  END;

  PROCEDURE assert_table
  (
    p_table_name           IN VARCHAR2,
    p_rows                 IN NUMBER,
    p_partitioning_type    IN VARCHAR2,
    p_subpartitioning_type IN VARCHAR2
  ) IS
    l_rows NUMBER;
    l_partitioning_type VARCHAR2(30);
    l_subpartitioning_type VARCHAR2(30);
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.SIMPLE_SQL_NAME(p_table_name)
      INTO l_rows;

    SELECT partitioning_type, subpartitioning_type
      INTO l_partitioning_type, l_subpartitioning_type
      FROM user_part_tables
     WHERE table_name = UPPER(p_table_name);

    assert_eq(USER || '.' || p_table_name || ' rows', l_rows, p_rows);

    IF l_partitioning_type <> p_partitioning_type
       OR NVL(l_subpartitioning_type, 'NONE') <> p_subpartitioning_type THEN
      RAISE_APPLICATION_ERROR
      (
        -20513,
        USER || '.' || p_table_name || ' partitioning expected ' ||
        p_partitioning_type || '/' || p_subpartitioning_type || ', got ' ||
        l_partitioning_type || '/' || NVL(l_subpartitioning_type, 'NONE')
      );
    END IF;
  END;

BEGIN
  assert_table('ORDERS_ARCH_SRC', 250, 'RANGE', 'NONE');
  assert_table('ORDERS_SUBPART_SRC', 360, 'RANGE', 'LIST');
  assert_table('ORDERS_DAILY_INT_SRC', 96, 'RANGE', 'LIST');

  SELECT COUNT(*)
    INTO l_count
    FROM user_tab_partitions
   WHERE table_name = 'ORDERS_DAILY_INT_SRC'
     AND partition_name LIKE 'SYS\_P%' ESCAPE '\';
  assert_eq(USER || '.ORDERS_DAILY_INT_SRC SYS_P partitions', l_count, 0);

  SELECT COUNT(*)
    INTO l_count
    FROM user_tab_partitions
   WHERE table_name = 'ORDERS_DAILY_INT_SRC'
     AND partition_name IN ('P20240501', 'P20240502', 'P20240503', 'P20240504');
  assert_eq(USER || '.ORDERS_DAILY_INT_SRC PYYYYMMDD partitions', l_count, 4);
END;
/

PROMPT CLIENT 001 completed
