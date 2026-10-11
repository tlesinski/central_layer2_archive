CREATE OR REPLACE PACKAGE BODY PKG_AGENT_ARCHIVE
AS
  /*
    Package      : PKG_AGENT_ARCHIVE
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Layer 1 archive agent - exposes partition info, row count,
                   cleanup unit, and health check operations

    Prerequisite : TYPE_AGENT_PARTITION_INFO_OBJ, TYPE_AGENT_PARTITION_INFO_TAB

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
    1.1        2026-10-11   Tomasz Lesinski    Use HIGH_VALUE-based FOR selectors
                                                for counts and source cleanup
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

  PROCEDURE prc_assert_allowed_table
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  IS
    l_owner      VARCHAR2(128);
    l_table_name VARCHAR2(128);
    l_count      PLS_INTEGER;
  BEGIN
    l_owner := fn_assert_simple_name(p_owner);
    l_table_name := fn_assert_simple_name(p_table_name);

    SELECT COUNT(*)
      INTO l_count
      FROM TBL_AGENT_CLIENT_TABLES
     WHERE SOURCE_OWNER = l_owner
       AND SOURCE_TABLE_NAME = l_table_name;

    IF l_count = 0 THEN
      RAISE_APPLICATION_ERROR
      (
        -20005,
        'AGENT access denied for table ' || l_owner || '.' || l_table_name
      );
    END IF;
  END prc_assert_allowed_table;

  FUNCTION fn_first_list_value
  (
    p_high_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_position PLS_INTEGER := 1;
    l_length   PLS_INTEGER := LENGTH(p_high_value);
    l_depth    PLS_INTEGER := 0;
    l_quoted   BOOLEAN := FALSE;
    l_char     VARCHAR2(1);
  BEGIN
    IF p_high_value IS NULL OR UPPER(TRIM(p_high_value)) = 'DEFAULT' THEN
      RAISE_APPLICATION_ERROR(-20006, 'A LIST HIGH_VALUE with an explicit value is required for FOR operations');
    END IF;

    WHILE l_position <= l_length LOOP
      l_char := SUBSTR(p_high_value, l_position, 1);

      IF l_quoted THEN
        IF l_char = '''' THEN
          IF SUBSTR(p_high_value, l_position + 1, 1) = '''' THEN
            l_position := l_position + 1;
          ELSE
            l_quoted := FALSE;
          END IF;
        END IF;
      ELSIF l_char = '''' THEN
        l_quoted := TRUE;
      ELSIF l_char = '(' THEN
        l_depth := l_depth + 1;
      ELSIF l_char = ')' THEN
        l_depth := l_depth - 1;
      ELSIF l_char = ',' AND l_depth = 0 THEN
        RETURN TRIM(SUBSTR(p_high_value, 1, l_position - 1));
      END IF;

      l_position := l_position + 1;
    END LOOP;

    RETURN TRIM(p_high_value);
  END fn_first_list_value;

  FUNCTION fn_unit_selector
  (
    p_owner                     IN VARCHAR2,
    p_table_name                IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2,
    p_subpartition_high_value   IN VARCHAR2,
    p_archive_unit_type         IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_partition_method    VARCHAR2(20);
    l_subpartition_method VARCHAR2(20);
    l_partition_key_count PLS_INTEGER;
    l_subpartition_key_count PLS_INTEGER;
    l_partition_value     VARCHAR2(4000);
    l_subpartition_value  VARCHAR2(4000);
    l_unit_type           VARCHAR2(20) := UPPER(TRIM(p_archive_unit_type));
  BEGIN
    SELECT partitioning_type,
           NULLIF(subpartitioning_type, 'NONE')
      INTO l_partition_method,
           l_subpartition_method
      FROM ALL_PART_TABLES
     WHERE owner = UPPER(p_owner)
       AND table_name = UPPER(p_table_name);

    SELECT COUNT(*)
      INTO l_partition_key_count
      FROM ALL_PART_KEY_COLUMNS
     WHERE owner = UPPER(p_owner)
       AND name = UPPER(p_table_name)
       AND object_type = 'TABLE';

    IF l_partition_key_count <> 1 THEN
      RAISE_APPLICATION_ERROR(-20006, 'FOR operations require a single-column partition key');
    END IF;

    IF l_partition_method = 'RANGE' THEN
      IF p_prev_partition_high_value IS NULL
         OR UPPER(TRIM(p_prev_partition_high_value)) = 'MINVALUE'
      THEN
        RAISE_APPLICATION_ERROR(-20006, 'RANGE FOR operation requires a finite previous HIGH_VALUE');
      END IF;
      l_partition_value := p_prev_partition_high_value;
    ELSIF l_partition_method = 'LIST' THEN
      l_partition_value := fn_first_list_value(p_partition_high_value);
    ELSE
      RAISE_APPLICATION_ERROR(-20006, 'Unsupported partition method for FOR operation: ' || l_partition_method);
    END IF;

    IF l_unit_type = 'PARTITION' THEN
      RETURN 'PARTITION FOR (' || l_partition_value || ')';
    ELSIF l_unit_type = 'SUBPARTITION' THEN
      IF NVL(l_subpartition_method, 'NONE') <> 'LIST'
         OR p_subpartition_high_value IS NULL
         OR TRIM(p_subpartition_high_value) = '#'
      THEN
        RAISE_APPLICATION_ERROR(-20006, 'SUBPARTITION FOR operation requires an explicit LIST subpartition value');
      END IF;

      SELECT COUNT(*)
        INTO l_subpartition_key_count
        FROM ALL_SUBPART_KEY_COLUMNS
       WHERE owner = UPPER(p_owner)
         AND name = UPPER(p_table_name)
         AND object_type = 'TABLE';

      IF l_subpartition_key_count <> 1 THEN
        RAISE_APPLICATION_ERROR(-20006, 'FOR operations require a single-column subpartition key');
      END IF;

      l_subpartition_value := fn_first_list_value(p_subpartition_high_value);
      RETURN 'SUBPARTITION FOR (' || l_partition_value || ', ' || l_subpartition_value || ')';
    END IF;

    RAISE_APPLICATION_ERROR(-20006, 'Unsupported archive unit type for FOR operation: ' || p_archive_unit_type);
  END fn_unit_selector;

  FUNCTION fn_get_partition_info
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  RETURN TYPE_AGENT_PARTITION_INFO_TAB PIPELINED
  IS
    l_partition_high_value    LONG;
    l_subpartition_high_value LONG;
    l_row                     TYPE_AGENT_PARTITION_INFO_OBJ :=
                                TYPE_AGENT_PARTITION_INFO_OBJ(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
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
    prc_assert_allowed_table(l_owner, l_table_name);

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
    p_owner                     IN VARCHAR2,
    p_table_name                IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value   IN VARCHAR2 DEFAULT NULL,
    p_archive_unit_type         IN VARCHAR2 DEFAULT 'PARTITION'
  )
  RETURN NUMBER
  IS
    l_sql             VARCHAR2(32767);
    l_row_count       NUMBER;
    l_table_name      VARCHAR2(300);
    l_unit_selector   VARCHAR2(10000);
  BEGIN
    IF p_owner IS NULL OR p_table_name IS NULL OR p_partition_high_value IS NULL THEN
      raise_application_error(-20002, 'Owner, table name, and partition HIGH_VALUE are required');
    END IF;

    prc_assert_allowed_table(p_owner, p_table_name);
    l_table_name := fn_assert_qualified_table(p_owner, p_table_name);
    l_unit_selector := fn_unit_selector
                       (
                         p_owner,
                         p_table_name,
                         p_partition_high_value,
                         p_prev_partition_high_value,
                         p_subpartition_high_value,
                         p_archive_unit_type
                       );
    l_sql := 'SELECT COUNT(*) FROM ' || l_table_name || ' ' || l_unit_selector;

    EXECUTE IMMEDIATE l_sql INTO l_row_count;

    RETURN l_row_count;
  END fn_get_row_count;

  PROCEDURE prc_cleanup_unit
  (
    p_owner                     IN VARCHAR2,
    p_table_name                IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value   IN VARCHAR2 DEFAULT NULL,
    p_archive_unit_type         IN VARCHAR2 DEFAULT 'PARTITION',
    p_mode                      IN VARCHAR2 DEFAULT 'TRUNCATE',
    p_execute                   IN VARCHAR2 DEFAULT 'N'
  )
  IS
    l_sql           VARCHAR2(32767);
    l_table_name    VARCHAR2(300);
    l_mode          VARCHAR2(20);
    l_unit_selector VARCHAR2(10000);
  BEGIN
    IF p_owner IS NULL OR p_table_name IS NULL OR p_partition_high_value IS NULL THEN
      raise_application_error(-20003, 'Owner, table name, and partition HIGH_VALUE are required');
    END IF;

    prc_assert_allowed_table(p_owner, p_table_name);
    l_mode := UPPER(NVL(TRIM(p_mode), 'TRUNCATE'));

    IF l_mode NOT IN ('TRUNCATE', 'DROP', 'DELETE') THEN
      raise_application_error(-20004, 'Unsupported cleanup mode: ' || p_mode);
    END IF;

    l_table_name := fn_assert_qualified_table(p_owner, p_table_name);
    l_unit_selector := fn_unit_selector
                       (
                         p_owner,
                         p_table_name,
                         p_partition_high_value,
                         p_prev_partition_high_value,
                         p_subpartition_high_value,
                         p_archive_unit_type
                       );

    IF l_mode = 'DELETE' THEN
      l_sql := 'DELETE FROM ' || l_table_name || ' ' || l_unit_selector;
    ELSIF l_mode = 'TRUNCATE' THEN
      l_sql := 'ALTER TABLE ' || l_table_name || ' TRUNCATE ' ||
               l_unit_selector || ' UPDATE GLOBAL INDEXES';
    ELSE
      l_sql := 'ALTER TABLE ' || l_table_name || ' ' || l_mode ||
               ' ' || l_unit_selector || ' UPDATE GLOBAL INDEXES';
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
END PKG_AGENT_ARCHIVE;
/
