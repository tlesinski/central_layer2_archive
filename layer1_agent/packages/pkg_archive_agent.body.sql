CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_AGENT
AS
  /*
    Package      : PKG_ARCHIVE_AGENT
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Layer 1 archive agent - exposes partition info, row count,
                   cleanup unit, and health check operations

    Prerequisite : ARCHIVE_PARTITION_INFO_OBJ, ARCHIVE_PARTITION_INFO_TAB

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_normalize_execute
  (
    p_execute IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN
      RETURN 'Y';
    END IF;

    RETURN 'N';
  END fn_normalize_execute;

  FUNCTION fn_assert_simple_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_name)));
  END fn_assert_simple_name;

  FUNCTION fn_assert_qualified_table
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN fn_assert_simple_name(p_owner) || '.' || fn_assert_simple_name(p_table_name);
  END fn_assert_qualified_table;

  FUNCTION fn_get_partition_info
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  RETURN ARCHIVE_PARTITION_INFO_TAB PIPELINED
  IS
    l_partition_high_value    LONG;
    l_subpartition_high_value LONG;
    l_row                     ARCHIVE_PARTITION_INFO_OBJ :=
                                ARCHIVE_PARTITION_INFO_OBJ(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
    l_cursor                  SYS_REFCURSOR;
    l_sql                     VARCHAR2(32767);
    l_owner                   VARCHAR2(128);
    l_table_name              VARCHAR2(128);
  BEGIN
    IF p_owner IS NULL OR p_table_name IS NULL THEN
      raise_application_error(-20001, 'Owner and table name are required');
    END IF;

    l_owner := fn_assert_simple_name(p_owner);
    l_table_name := fn_assert_simple_name(p_table_name);

    l_sql := q'[
      SELECT p.table_owner,
             p.table_name,
             p.partition_name,
             s.subpartition_name,
             p.high_value,
             s.high_value,
             p.partition_position,
             s.subpartition_position
        FROM all_tab_partitions p
        LEFT JOIN all_tab_subpartitions s
          ON p.table_owner = s.table_owner
         AND p.table_name = s.table_name
         AND p.partition_name = s.partition_name
       WHERE p.table_owner = :owner
         AND p.table_name = :table_name
       ORDER BY p.partition_position, s.subpartition_position
    ]';

    OPEN l_cursor FOR l_sql USING l_owner, l_table_name;

    LOOP
      FETCH l_cursor INTO l_row.SCHEMA_NAME,
                          l_row.TABLE_NAME,
                          l_row.PARTITION_NAME,
                          l_row.SUBPARTITION_NAME,
                          l_partition_high_value,
                          l_subpartition_high_value,
                          l_row.PARTITION_POSITION,
                          l_row.SUBPARTITION_POSITION;
      EXIT WHEN l_cursor%NOTFOUND;

      l_row.PARTITION_HIGH_VALUE := DBMS_LOB.SUBSTR(TO_CLOB(l_partition_high_value), 4000, 1);
      l_row.SUBPARTITION_HIGH_VALUE := DBMS_LOB.SUBSTR(TO_CLOB(l_subpartition_high_value), 4000, 1);

      PIPE ROW(l_row);
    END LOOP;

    CLOSE l_cursor;
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      IF l_cursor%ISOPEN THEN
        CLOSE l_cursor;
      END IF;

      RAISE;
  END fn_get_partition_info;

  FUNCTION fn_get_row_count
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL
  )
  RETURN NUMBER
  IS
    l_sql        VARCHAR2(32767);
    l_row_count  NUMBER;
    l_table_name VARCHAR2(300);
  BEGIN
    IF p_owner IS NULL OR p_table_name IS NULL OR p_partition_name IS NULL THEN
      raise_application_error(-20002, 'Owner, table name, and partition name are required');
    END IF;

    l_table_name := fn_assert_qualified_table(p_owner, p_table_name);

    IF p_subpartition_name IS NOT NULL THEN
      l_sql := 'SELECT COUNT(*) FROM ' || l_table_name ||
               ' SUBPARTITION (' || fn_assert_simple_name(p_subpartition_name) || ')';
    ELSE
      l_sql := 'SELECT COUNT(*) FROM ' || l_table_name ||
               ' PARTITION (' || fn_assert_simple_name(p_partition_name) || ')';
    END IF;

    EXECUTE IMMEDIATE l_sql INTO l_row_count;

    RETURN l_row_count;
  END fn_get_row_count;

  PROCEDURE prc_cleanup_unit
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL,
    p_mode              IN VARCHAR2 DEFAULT 'TRUNCATE',
    p_execute           IN VARCHAR2 DEFAULT 'N'
  )
  IS
    l_sql        VARCHAR2(32767);
    l_table_name VARCHAR2(300);
    l_mode       VARCHAR2(20);
  BEGIN
    IF p_owner IS NULL OR p_table_name IS NULL OR p_partition_name IS NULL THEN
      raise_application_error(-20003, 'Owner, table name, and partition name are required');
    END IF;

    l_mode := UPPER(NVL(TRIM(p_mode), 'TRUNCATE'));

    IF l_mode NOT IN ('TRUNCATE', 'DROP', 'DELETE') THEN
      raise_application_error(-20004, 'Unsupported cleanup mode: ' || p_mode);
    END IF;

    l_table_name := fn_assert_qualified_table(p_owner, p_table_name);

    IF l_mode = 'DELETE' THEN
      IF p_subpartition_name IS NOT NULL THEN
        l_sql := 'DELETE FROM ' || l_table_name ||
                 ' SUBPARTITION (' || fn_assert_simple_name(p_subpartition_name) || ')';
      ELSE
        l_sql := 'DELETE FROM ' || l_table_name ||
                 ' PARTITION (' || fn_assert_simple_name(p_partition_name) || ')';
      END IF;
    ELSIF l_mode = 'TRUNCATE' THEN
      IF p_subpartition_name IS NOT NULL THEN
        l_sql := 'ALTER TABLE ' || l_table_name ||
                 ' TRUNCATE SUBPARTITION ' || fn_assert_simple_name(p_subpartition_name) ||
                 ' UPDATE GLOBAL INDEXES';
      ELSE
        l_sql := 'ALTER TABLE ' || l_table_name ||
                 ' TRUNCATE PARTITION ' || fn_assert_simple_name(p_partition_name) ||
                 ' UPDATE GLOBAL INDEXES';
      END IF;
    ELSIF p_subpartition_name IS NOT NULL THEN
      l_sql := 'ALTER TABLE ' || l_table_name || ' ' || l_mode ||
               ' SUBPARTITION ' || fn_assert_simple_name(p_subpartition_name) ||
               ' UPDATE GLOBAL INDEXES';
    ELSE
      l_sql := 'ALTER TABLE ' || l_table_name || ' ' || l_mode ||
               ' PARTITION ' || fn_assert_simple_name(p_partition_name) ||
               ' UPDATE GLOBAL INDEXES';
    END IF;

    DBMS_OUTPUT.PUT_LINE(l_sql);

    IF fn_normalize_execute(p_execute) = 'Y' THEN
      EXECUTE IMMEDIATE l_sql;
    END IF;
  END prc_cleanup_unit;

  FUNCTION fn_health_check
  RETURN VARCHAR2
  IS
  BEGIN
    RETURN 'OK:' || SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA');
  END fn_health_check;
END PKG_ARCHIVE_AGENT;
/
