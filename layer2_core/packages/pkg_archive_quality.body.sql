CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_QUALITY
AS
  FUNCTION normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION qualified_agent_function(p_agent_schema IN VARCHAR2, p_source_db_link IN VARCHAR2) RETURN VARCHAR2 IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_agent_schema) || '.PKG_ARCHIVE_AGENT.GET_ROW_COUNT';
    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;
    RETURN l_name;
  END;

  FUNCTION create_run(p_source_db_link IN VARCHAR2, p_source_owner IN VARCHAR2, p_source_table IN VARCHAR2, p_execute IN VARCHAR2)
  RETURN NUMBER
  IS
  BEGIN
    RETURN PKG_ARCHIVE_LOG.create_run('QUALITY', p_source_db_link, p_source_owner, p_source_table, p_execute);
  END;

  PROCEDURE finish_run(p_run_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    PKG_ARCHIVE_LOG.finish_run(p_run_id, p_status, p_error_message);
  END;

  PROCEDURE check_one_table
  (
    p_source_db_link IN VARCHAR2,
    p_agent_schema   IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  IS
    l_run_id         NUMBER;
    l_log_id         NUMBER;
    l_execute_flag   VARCHAR2(1);
    l_agent_function VARCHAR2(400);
    l_sql            VARCHAR2(32767);
    l_source_rows    NUMBER;
    l_units          NUMBER := 0;
    l_ok             NUMBER := 0;
    l_failed         NUMBER := 0;
    l_quality_status VARCHAR2(1);
  BEGIN
    l_execute_flag := normalize_execute(p_execute);
    l_run_id := create_run(p_source_db_link, p_source_owner, p_source_table, p_execute);
    l_log_id := PKG_ARCHIVE_LOG.get_log_id(l_run_id);
    l_agent_function := qualified_agent_function(p_agent_schema, p_source_db_link);
    l_sql := 'SELECT ' || l_agent_function || '(:1, :2, :3, :4) FROM dual';

    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, PARTITION_NAME, SUBPARTITION_NAME,
             PARTITION_HIGH_VALUE, SUBPARTITION_HIGH_VALUE, TARGET_ROW_COUNT
        FROM TW_ARCHIVE_PARTITIONS
       WHERE SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_source_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_source_table)
         AND ARCHIVE_STATUS = 'Y'
         AND QUALITY_STATUS = 'N'
       ORDER BY PARTITION_POSITION, SUBPARTITION_POSITION
    ) LOOP
      l_units := l_units + 1;

      l_source_rows := PKG_SQL.fn_run_into_sql_in_bind
      (
        p_log_id     => l_log_id,
        p_sql        => l_sql,
        p_array_bind => SYS.ODCIVARCHAR2LIST
                        (
                          UPPER(p_source_owner),
                          UPPER(p_source_table),
                          r.PARTITION_NAME,
                          CASE WHEN r.SUBPARTITION_NAME = '#' THEN NULL ELSE r.SUBPARTITION_NAME END
                        ),
        p_execute    => 'Y'
      );

      IF l_source_rows = r.TARGET_ROW_COUNT THEN
        l_quality_status := 'Y';
        l_ok := l_ok + 1;
      ELSE
        l_quality_status := 'N';
        l_failed := l_failed + 1;
      END IF;

      DBMS_OUTPUT.PUT_LINE('QUALITY ' || UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' ||
                           UPPER(p_source_table) || ' ' || r.PARTITION_NAME ||
                           CASE WHEN r.SUBPARTITION_NAME <> '#' THEN '.' || r.SUBPARTITION_NAME ELSE NULL END ||
                           ' source=' || NVL(TO_CHAR(l_source_rows), 'NULL') ||
                           ' target=' || NVL(TO_CHAR(r.TARGET_ROW_COUNT), 'NULL') ||
                           ' status=' || l_quality_status || ' execute=' || l_execute_flag);

      IF l_execute_flag = 'Y' THEN
        UPDATE TW_ARCHIVE_PARTITIONS
           SET SOURCE_ROW_COUNT = l_source_rows,
               QUALITY_STATUS = l_quality_status,
               LAST_RUN_ID = l_run_id,
               ERROR_MESSAGE = CASE
                                 WHEN l_quality_status = 'Y' THEN NULL
                                 ELSE 'Source row count does not match target row count'
                               END,
               UPDATED_AT = SYSTIMESTAMP
         WHERE SOURCE_DB_LINK = r.SOURCE_DB_LINK
           AND SOURCE_OWNER = r.SOURCE_OWNER
           AND SOURCE_TABLE_NAME = r.SOURCE_TABLE_NAME
           AND PARTITION_HIGH_VALUE = r.PARTITION_HIGH_VALUE
           AND SUBPARTITION_HIGH_VALUE = r.SUBPARTITION_HIGH_VALUE;
      END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('QUALITY_SUMMARY ' || UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' ||
                         UPPER(p_source_table) || ' units=' || l_units || ' ok=' || l_ok ||
                         ' failed=' || l_failed || ' execute=' || l_execute_flag);
    finish_run(l_run_id, CASE WHEN l_failed > 0 THEN 'WARNING' ELSE 'SUCCESS' END);
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN finish_run(l_run_id, 'ERROR', SQLERRM); END IF;
      RAISE;
  END;

  PROCEDURE check_table(p_source_db_link IN VARCHAR2, p_owner IN VARCHAR2, p_table_name IN VARCHAR2, p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_AGENT_SCHEMA, SOURCE_OWNER, SOURCE_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
         AND SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_table_name)
    ) LOOP
      check_one_table(r.SOURCE_DB_LINK, r.SOURCE_AGENT_SCHEMA, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, p_execute);
    END LOOP;
  END;

  PROCEDURE check_all(p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_AGENT_SCHEMA, SOURCE_OWNER, SOURCE_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
       ORDER BY SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME
    ) LOOP
      check_one_table(r.SOURCE_DB_LINK, r.SOURCE_AGENT_SCHEMA, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, p_execute);
    END LOOP;
  END;
END PKG_ARCHIVE_QUALITY;
/
