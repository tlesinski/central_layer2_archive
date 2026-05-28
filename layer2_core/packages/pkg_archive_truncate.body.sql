CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_TRUNCATE
AS
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_normalize_name(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_name IS NULL OR TRIM(p_name) IS NULL THEN
      RETURN NULL;
    END IF;

    RETURN PKG_SQL.fn_assert_simple_name(p_name);
  END;

  FUNCTION fn_qualified_agent_procedure(p_agent_schema IN VARCHAR2, p_source_db_link IN VARCHAR2) RETURN VARCHAR2 IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_agent_schema) || '.PKG_ARCHIVE_AGENT.PRC_CLEANUP_UNIT';
    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;
    RETURN l_name;
  END;

  PROCEDURE prc_truncate
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_run_id          NUMBER;
    l_log_id          NUMBER;
    l_execute_flag    VARCHAR2(1);
    l_target_owner    VARCHAR2(128);
    l_target_table    VARCHAR2(128);
    l_sql             CLOB;
    l_rows_available  NUMBER := 0;
    l_agent_procedure VARCHAR2(400);
    l_units           NUMBER := 0;
    l_truncated       NUMBER := 0;
    l_tables          NUMBER := 0;
    l_sql_rows        NUMBER;
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('TRUNCATE', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVE_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Truncate filter: target_owner=' || NVL(l_target_owner, '<ALL>') ||
                   ', target_table_name=' || NVL(l_target_table, '<ALL>')
    );

    l_sql :=
      'SELECT COUNT(*) ' ||
      '  FROM TW_ARCHIVE_TRUNCATE_PARTITIONS_VW ' ||
      ' WHERE (:1 IS NULL OR target_owner = :1) ' ||
      '   AND (:2 IS NULL OR target_table_name = :2)';

    l_rows_available := PKG_SQL.fn_run_into_sql_in_bind
    (
      p_log_id     => l_log_id,
      p_sql        => l_sql,
      p_array_bind => SYS.ODCIVARCHAR2LIST(l_target_owner, l_target_table),
      p_execute    => 'Y'
    );

    FOR t IN (
      SELECT DISTINCT source_db_link,
             source_agent_schema,
             source_owner,
             source_table_name,
             target_owner,
             target_table_name
        FROM TW_ARCHIVE_TRUNCATE_PARTITIONS_VW
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_tables := l_tables + 1;
      l_agent_procedure := fn_qualified_agent_procedure(t.source_agent_schema, t.source_db_link);
      l_sql := 'BEGIN ' || l_agent_procedure || '(:1, :2, :3, :4, :5, :6); END;';

      FOR r IN (
        SELECT p.*
          FROM TW_ARCHIVE_TRUNCATE_PARTITIONS_VW p
         WHERE p.source_db_link = t.source_db_link
           AND p.source_owner = t.source_owner
           AND p.source_table_name = t.source_table_name
           AND p.target_owner = t.target_owner
           AND p.target_table_name = t.target_table_name
         ORDER BY p.partition_position, p.subpartition_position
      ) LOOP
        l_units := l_units + 1;
        DBMS_OUTPUT.PUT_LINE('TRUNCATE ' || r.SOURCE_DB_LINK || '.' || r.SOURCE_OWNER || '.' ||
                             r.SOURCE_TABLE_NAME || ' source=' || r.SOURCE_PARTITION_NAME ||
                             CASE WHEN r.SOURCE_SUBPARTITION_NAME <> '#' THEN '.' || r.SOURCE_SUBPARTITION_NAME ELSE NULL END ||
                             ' target=' || r.PARTITION_NAME ||
                             CASE WHEN r.SUBPARTITION_NAME <> '#' THEN '.' || r.SUBPARTITION_NAME ELSE NULL END ||
                             ' cutoff=' || TO_CHAR(r.CUTOFF_DATE, 'YYYY-MM-DD') ||
                             ' execute=' || l_execute_flag);

        l_sql_rows := PKG_SQL.fn_run_sql_in_bind
        (
          p_log_id     => l_log_id,
          p_sql        => l_sql,
          p_array_bind => SYS.ODCIVARCHAR2LIST
                          (
                            r.SOURCE_OWNER,
                            r.SOURCE_TABLE_NAME,
                            r.SOURCE_PARTITION_NAME,
                            CASE WHEN r.SOURCE_SUBPARTITION_NAME = '#' THEN NULL ELSE r.SOURCE_SUBPARTITION_NAME END,
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
          COMMIT;
        END IF;
      END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(
      'TRUNCATE tables=' || l_tables ||
      ' units=' || l_units ||
      ' found=' || l_rows_available ||
      ' truncated=' || l_truncated ||
      ' target_owner=' || NVL(l_target_owner, '<ALL>') ||
      ' target_table=' || NVL(l_target_table, '<ALL>') ||
      ' execute=' || l_execute_flag
    );

    PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVE_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_truncate;
END PKG_ARCHIVE_TRUNCATE;
/
