CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_DISCOVERY
AS
  FUNCTION normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION qualified_partition_view
  (
    p_agent_schema   IN VARCHAR2,
    p_source_db_link IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_agent_schema) || '.ARCHIVE_PARTITION_INFO_VW';

    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;

    RETURN l_name;
  END;

  FUNCTION qualified_table(p_owner IN VARCHAR2, p_table IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN PKG_SQL.fn_assert_simple_name(p_owner) || '.' || PKG_SQL.fn_assert_simple_name(p_table);
  END;

  FUNCTION sql_literal(p_value IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '''' || REPLACE(p_value, '''', '''''') || '''';
  END;

  FUNCTION normalize_high_value(p_high_value IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN REGEXP_REPLACE(UPPER(TRIM(p_high_value)), '[[:space:]]+', ' ');
  END;

  FUNCTION target_partition_exists
  (
    p_target_owner         IN VARCHAR2,
    p_target_table         IN VARCHAR2,
    p_partition_high_value IN VARCHAR2
  )
  RETURN BOOLEAN
  IS
    l_xml_sql VARCHAR2(32767);
  BEGIN
    l_xml_sql :=
      'SELECT high_value FROM all_tab_partitions ' ||
      'WHERE table_owner = ' || sql_literal(UPPER(p_target_owner)) ||
      ' AND table_name = ' || sql_literal(UPPER(p_target_table));

    FOR r IN (
      SELECT high_value
        FROM XMLTABLE(
               '/ROWSET/ROW'
               PASSING DBMS_XMLGEN.GETXMLTYPE(l_xml_sql)
               COLUMNS high_value VARCHAR2(4000) PATH 'HIGH_VALUE'
             )
    ) LOOP
      IF normalize_high_value(r.high_value) = normalize_high_value(p_partition_high_value) THEN
        RETURN TRUE;
      END IF;
    END LOOP;

    RETURN FALSE;
  END target_partition_exists;

  PROCEDURE sync_target_partitions
  (
    p_log_id           IN NUMBER,
    p_partition_view   IN VARCHAR2,
    p_source_owner     IN VARCHAR2,
    p_source_table     IN VARCHAR2,
    p_target_owner     IN VARCHAR2,
    p_target_table     IN VARCHAR2
  )
  IS
    TYPE t_cursor IS REF CURSOR;
    l_cursor               t_cursor;
    l_partition_name       VARCHAR2(128);
    l_partition_high_value VARCHAR2(4000);
    l_partition_position   NUMBER;
    l_select_sql           VARCHAR2(32767);
    l_add_sql              CLOB;
    l_rows                 NUMBER;
  BEGIN
    l_select_sql :=
      'SELECT partition_name, partition_high_value, partition_position ' ||
      'FROM ' || p_partition_view || ' ' ||
      'WHERE schema_name = :1 ' ||
      'AND table_name = :2 ' ||
      'AND UPPER(TRIM(partition_high_value)) <> ''MAXVALUE'' ' ||
      'ORDER BY partition_position';

    OPEN l_cursor FOR l_select_sql USING UPPER(p_source_owner), UPPER(p_source_table);
    LOOP
      FETCH l_cursor INTO l_partition_name, l_partition_high_value, l_partition_position;
      EXIT WHEN l_cursor%NOTFOUND;

      IF NOT target_partition_exists(p_target_owner, p_target_table, l_partition_high_value) THEN
        l_add_sql :=
          'ALTER TABLE ' || qualified_table(p_target_owner, p_target_table) ||
          ' ADD PARTITION ' || PKG_SQL.fn_assert_simple_name(l_partition_name) ||
          ' VALUES LESS THAN (' || l_partition_high_value || ')';

        l_rows := PKG_SQL.fn_run_sql(p_log_id, l_add_sql, 'Y');
      END IF;
    END LOOP;
    CLOSE l_cursor;
  EXCEPTION
    WHEN OTHERS THEN
      IF l_cursor%ISOPEN THEN
        CLOSE l_cursor;
      END IF;
      RAISE;
  END sync_target_partitions;

  FUNCTION create_run
  (
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  RETURN NUMBER
  IS
  BEGIN
    RETURN PKG_ARCHIVE_LOG.create_run('DISCOVER', p_source_db_link, p_source_owner, p_source_table, p_execute);
  END;

  PROCEDURE finish_run(p_run_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    PKG_ARCHIVE_LOG.finish_run(p_run_id, p_status, p_error_message);
  END;

  PROCEDURE discover_one
  (
    p_source_db_link     IN VARCHAR2,
    p_agent_schema       IN VARCHAR2,
    p_source_owner       IN VARCHAR2,
    p_source_table       IN VARCHAR2,
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_execute            IN VARCHAR2
  )
  IS
    l_run_id          NUMBER;
    l_partition_view  VARCHAR2(400);
    l_sql             CLOB;
    l_rows_discovered NUMBER := 0;
    l_rows_merged     NUMBER := 0;
    l_log_id          NUMBER;
  BEGIN
    l_run_id := create_run(p_source_db_link, p_source_owner, p_source_table, p_execute);
    l_log_id := PKG_ARCHIVE_LOG.get_log_id(l_run_id);
    l_partition_view := qualified_partition_view(p_agent_schema, p_source_db_link);

    l_sql := 'SELECT COUNT(*) FROM ' || l_partition_view ||
             ' WHERE schema_name = :1 AND table_name = :2';

    l_rows_discovered := PKG_SQL.fn_run_into_sql_in_bind
    (
      p_log_id     => l_log_id,
      p_sql        => l_sql,
      p_array_bind => SYS.ODCIVARCHAR2LIST(UPPER(p_source_owner), UPPER(p_source_table)),
      p_execute    => 'Y'
    );

    IF normalize_execute(p_execute) = 'Y' THEN
      sync_target_partitions
      (
        p_log_id         => l_log_id,
        p_partition_view => l_partition_view,
        p_source_owner   => p_source_owner,
        p_source_table   => p_source_table,
        p_target_owner   => p_target_owner,
        p_target_table   => p_target_table
      );

      l_sql := 'MERGE INTO TW_ARCHIVE_PARTITIONS dst ' ||
               'USING ( ' ||
               '  SELECT :1 AS source_db_link, ' ||
               '         :2 AS source_owner, ' ||
               '         :3 AS source_table_name, ' ||
               '         :4 AS target_owner, ' ||
               '         :5 AS target_table_name, ' ||
               '         CASE WHEN x.subpartition_name IS NULL THEN ''PARTITION'' ELSE ''SUBPARTITION'' END AS archive_unit_type, ' ||
               '         x.partition_name, ' ||
               '         NVL(x.subpartition_name, ''#'') AS subpartition_name, ' ||
               '         x.partition_high_value, ' ||
               '         NVL(x.subpartition_high_value, ''#'') AS subpartition_high_value, ' ||
               '         x.partition_position, ' ||
               '         x.subpartition_position ' ||
               '    FROM ' || l_partition_view || ' x ' ||
               '   WHERE x.schema_name = :6 ' ||
               '     AND x.table_name = :7 ' ||
               '     AND UPPER(TRIM(x.partition_high_value)) <> ''MAXVALUE'' ' ||
               ') src ' ||
               'ON (dst.source_db_link = src.source_db_link ' ||
               '    AND dst.source_owner = src.source_owner ' ||
               '    AND dst.source_table_name = src.source_table_name ' ||
               '    AND dst.partition_high_value = src.partition_high_value ' ||
               '    AND dst.subpartition_high_value = src.subpartition_high_value) ' ||
               'WHEN MATCHED THEN UPDATE SET ' ||
               '  dst.target_owner = src.target_owner, ' ||
               '  dst.target_table_name = src.target_table_name, ' ||
               '  dst.archive_unit_type = src.archive_unit_type, ' ||
               '  dst.partition_position = src.partition_position, ' ||
               '  dst.subpartition_position = src.subpartition_position, ' ||
               '  dst.last_run_id = :8, ' ||
               '  dst.error_message = NULL, ' ||
               '  dst.updated_at = SYSTIMESTAMP ' ||
               'WHEN NOT MATCHED THEN INSERT ' ||
               '  (source_db_link, source_owner, source_table_name, target_owner, target_table_name, ' ||
               '   archive_unit_type, partition_name, subpartition_name, partition_high_value, subpartition_high_value, ' ||
               '   partition_position, subpartition_position, archive_status, quality_status, truncate_status, last_run_id) ' ||
               'VALUES ' ||
               '  (src.source_db_link, src.source_owner, src.source_table_name, src.target_owner, src.target_table_name, ' ||
               '   src.archive_unit_type, src.partition_name, src.subpartition_name, src.partition_high_value, src.subpartition_high_value, ' ||
               '   src.partition_position, src.subpartition_position, ''N'', ''N'', ''N'', :9)';

      l_rows_merged := PKG_SQL.fn_run_sql_in_bind
      (
        p_log_id     => l_log_id,
        p_sql        => l_sql,
        p_array_bind => SYS.ODCIVARCHAR2LIST
                        (
                          UPPER(p_source_db_link),
                          UPPER(p_source_owner),
                          UPPER(p_source_table),
                          UPPER(p_target_owner),
                          UPPER(p_target_table),
                          UPPER(p_source_owner),
                          UPPER(p_source_table),
                          TO_CHAR(l_run_id),
                          TO_CHAR(l_run_id)
                        ),
        p_execute    => p_execute
      );
    END IF;

    DBMS_OUTPUT.PUT_LINE(
      'DISCOVER ' || UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' || UPPER(p_source_table) ||
      ' found=' || l_rows_discovered ||
      ' merged=' || l_rows_merged ||
      ' execute=' || normalize_execute(p_execute)
    );

    finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END;

  PROCEDURE discover_table
  (
    p_source_db_link IN VARCHAR2,
    p_owner          IN VARCHAR2,
    p_table_name     IN VARCHAR2,
    p_execute        IN VARCHAR2 DEFAULT 'N'
  )
  IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_AGENT_SCHEMA, SOURCE_OWNER, SOURCE_TABLE_NAME, TARGET_OWNER, TARGET_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
         AND SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_table_name)
    ) LOOP
      discover_one(r.SOURCE_DB_LINK, r.SOURCE_AGENT_SCHEMA, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, r.TARGET_OWNER, r.TARGET_TABLE_NAME, p_execute);
    END LOOP;
  END;

  PROCEDURE discover_all(p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_AGENT_SCHEMA, SOURCE_OWNER, SOURCE_TABLE_NAME, TARGET_OWNER, TARGET_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
       ORDER BY SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME
    ) LOOP
      discover_one(r.SOURCE_DB_LINK, r.SOURCE_AGENT_SCHEMA, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, r.TARGET_OWNER, r.TARGET_TABLE_NAME, p_execute);
    END LOOP;
  END;
END PKG_ARCHIVE_DISCOVERY;
/
