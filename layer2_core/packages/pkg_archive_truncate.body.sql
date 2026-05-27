CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_TRUNCATE
AS
  FUNCTION normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION qualified_agent_procedure(p_agent_schema IN VARCHAR2, p_source_db_link IN VARCHAR2) RETURN VARCHAR2 IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_agent_schema) || '.PKG_ARCHIVE_AGENT.CLEANUP_UNIT';
    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;
    RETURN l_name;
  END;

  FUNCTION create_run(p_source_db_link IN VARCHAR2, p_source_owner IN VARCHAR2, p_source_table IN VARCHAR2, p_execute IN VARCHAR2)
  RETURN NUMBER
  IS
  BEGIN
    RETURN PKG_ARCHIVE_LOG.create_run('TRUNCATE', p_source_db_link, p_source_owner, p_source_table, p_execute);
  END;

  FUNCTION high_value_to_date(p_high_value IN VARCHAR2) RETURN DATE IS
    l_date DATE;
  BEGIN
    IF p_high_value IS NULL OR UPPER(TRIM(p_high_value)) = 'MAXVALUE' THEN
      RETURN NULL;
    END IF;
    EXECUTE IMMEDIATE 'SELECT ' || p_high_value || ' FROM dual' INTO l_date;
    RETURN l_date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  PROCEDURE finish_run(p_run_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    PKG_ARCHIVE_LOG.finish_run(p_run_id, p_status, p_error_message);
  END;

  PROCEDURE truncate_one_table
  (
    p_source_db_link IN VARCHAR2,
    p_agent_schema   IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_retention_days IN NUMBER,
    p_execute        IN VARCHAR2
  )
  IS
    l_run_id          NUMBER;
    l_agent_procedure VARCHAR2(400);
    l_sql             VARCHAR2(32767);
    l_units           NUMBER := 0;
    l_truncated       NUMBER := 0;
    l_execute_flag    VARCHAR2(1);
    l_log_id          NUMBER;
    l_sql_rows        NUMBER;
    l_cutoff_date     DATE;
  BEGIN
    l_execute_flag := normalize_execute(p_execute);
    l_cutoff_date := TRUNC(SYSDATE) - NVL(p_retention_days, 0);
    l_run_id := create_run(p_source_db_link, p_source_owner, p_source_table, p_execute);
    l_log_id := PKG_ARCHIVE_LOG.get_log_id(l_run_id);
    l_agent_procedure := qualified_agent_procedure(p_agent_schema, p_source_db_link);
    l_sql := 'BEGIN ' || l_agent_procedure || '(:1, :2, :3, :4, :5, :6); END;';

    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, PARTITION_NAME, SUBPARTITION_NAME,
             PARTITION_HIGH_VALUE, SUBPARTITION_HIGH_VALUE
        FROM TW_ARCHIVE_PARTITIONS
       WHERE SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_source_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_source_table)
         AND ARCHIVE_STATUS = 'Y'
         AND QUALITY_STATUS = 'Y'
         AND TRUNCATE_STATUS = 'N'
       ORDER BY PARTITION_POSITION, SUBPARTITION_POSITION
    ) LOOP
      IF high_value_to_date(r.PARTITION_HIGH_VALUE) IS NULL
         OR high_value_to_date(r.PARTITION_HIGH_VALUE) > l_cutoff_date THEN
        CONTINUE;
      END IF;

      l_units := l_units + 1;
      DBMS_OUTPUT.PUT_LINE('TRUNCATE ' || UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' ||
                           UPPER(p_source_table) || ' ' || r.PARTITION_NAME ||
                           CASE WHEN r.SUBPARTITION_NAME <> '#' THEN '.' || r.SUBPARTITION_NAME ELSE NULL END ||
                           ' cutoff=' || TO_CHAR(l_cutoff_date, 'YYYY-MM-DD') ||
                           ' execute=' || l_execute_flag);

      l_sql_rows := PKG_SQL.fn_run_sql_in_bind
      (
        p_log_id     => l_log_id,
        p_sql        => l_sql,
        p_array_bind => SYS.ODCIVARCHAR2LIST
                        (
                          UPPER(p_source_owner),
                          UPPER(p_source_table),
                          r.PARTITION_NAME,
                          CASE WHEN r.SUBPARTITION_NAME = '#' THEN NULL ELSE r.SUBPARTITION_NAME END,
                          'TRUNCATE',
                          l_execute_flag
                        ),
        p_execute    => l_execute_flag
      );

      IF l_execute_flag = 'Y' THEN
        UPDATE TW_ARCHIVE_PARTITIONS
           SET TRUNCATE_STATUS = 'Y',
               LAST_RUN_ID = l_run_id,
               ERROR_MESSAGE = NULL,
               UPDATED_AT = SYSTIMESTAMP
         WHERE SOURCE_DB_LINK = r.SOURCE_DB_LINK
           AND SOURCE_OWNER = r.SOURCE_OWNER
           AND SOURCE_TABLE_NAME = r.SOURCE_TABLE_NAME
           AND PARTITION_HIGH_VALUE = r.PARTITION_HIGH_VALUE
           AND SUBPARTITION_HIGH_VALUE = r.SUBPARTITION_HIGH_VALUE;
        l_truncated := l_truncated + SQL%ROWCOUNT;
      END IF;
    END LOOP;

    IF l_execute_flag = 'Y' THEN COMMIT; END IF;
    DBMS_OUTPUT.PUT_LINE('TRUNCATE_SUMMARY ' || UPPER(p_source_db_link) || '.' || UPPER(p_source_owner) || '.' ||
                         UPPER(p_source_table) || ' units=' || l_units || ' truncated=' || l_truncated ||
                         ' execute=' || l_execute_flag);
    finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN finish_run(l_run_id, 'ERROR', SQLERRM); END IF;
      RAISE;
  END;

  PROCEDURE truncate_table(p_source_db_link IN VARCHAR2, p_owner IN VARCHAR2, p_table_name IN VARCHAR2, p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_AGENT_SCHEMA, SOURCE_OWNER, SOURCE_TABLE_NAME, RETENTION_DAYS, TRUNCATE_MODE
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
         AND SOURCE_DB_LINK = UPPER(p_source_db_link)
         AND SOURCE_OWNER = UPPER(p_owner)
         AND SOURCE_TABLE_NAME = UPPER(p_table_name)
    ) LOOP
      IF r.TRUNCATE_MODE = 'TRUNCATE' THEN
        truncate_one_table(r.SOURCE_DB_LINK, r.SOURCE_AGENT_SCHEMA, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, r.RETENTION_DAYS, p_execute);
      END IF;
    END LOOP;
  END;

  PROCEDURE truncate_all(p_execute IN VARCHAR2 DEFAULT 'N') IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_AGENT_SCHEMA, SOURCE_OWNER, SOURCE_TABLE_NAME, RETENTION_DAYS, TRUNCATE_MODE
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
       ORDER BY SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME
    ) LOOP
      IF r.TRUNCATE_MODE = 'TRUNCATE' THEN
        truncate_one_table(r.SOURCE_DB_LINK, r.SOURCE_AGENT_SCHEMA, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, r.RETENTION_DAYS, p_execute);
      END IF;
    END LOOP;
  END;
END PKG_ARCHIVE_TRUNCATE;
/
