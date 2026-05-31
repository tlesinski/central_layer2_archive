CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_QUALITY
AS
  /*
    Package      : PKG_ARCHIVE_QUALITY
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Quality check - compare source and target row counts,
                   set QUALITY_STATUS

    Prerequisite : PKG_SQL, PKG_ARCHIVE_LOG, PKG_ARCHIVE_AGENT,
                   TW_ARCHIVE_QUALITY_PARTITIONS_VW

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-28   Tomasz Lesinski    Add process summary logging
     1.2        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
  */
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

  FUNCTION fn_qualified_agent_function(p_agent_schema IN VARCHAR2, p_source_db_link IN VARCHAR2) RETURN VARCHAR2 IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_agent_schema) || '.PKG_ARCHIVE_AGENT.FN_GET_ROW_COUNT';
    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;
    RETURN l_name;
  END;

  PROCEDURE prc_quality
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
    l_agent_function  VARCHAR2(400);
    l_source_rows     NUMBER;
    l_units           NUMBER := 0;
    l_tables          NUMBER := 0;
    l_ok              NUMBER := 0;
    l_failed          NUMBER := 0;
    l_quality_status  VARCHAR2(1);
    l_summary         CLOB := NULL;
    l_table_summary   CLOB;
    l_partition_columns VARCHAR2(1000) :=
      'NOTE|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|ARCHIVE_STATUS|QUALITY_STATUS|TRUNCATE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('QUALITY', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVE_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started QUALITY with parameters:' || CHR(10) ||
                   '  p_execute           => ' || l_execute_flag || CHR(10) ||
                   '  p_target_owner      => ' || NVL(l_target_owner, '<ALL>') || CHR(10) ||
                   '  p_target_table_name => ' || NVL(l_target_table, '<ALL>')
    );

    l_sql :=
      'SELECT COUNT(*) ' ||
      '  FROM TW_ARCHIVE_QUALITY_PARTITIONS_VW ' ||
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
        FROM TW_ARCHIVE_QUALITY_PARTITIONS_VW
       WHERE (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
       ORDER BY source_db_link, source_owner, source_table_name
    ) LOOP
      l_tables := l_tables + 1;
      l_table_summary := NULL;
      l_agent_function := fn_qualified_agent_function(t.source_agent_schema, t.source_db_link);
      l_sql := 'SELECT ' || l_agent_function || '(:1, :2, :3, :4) FROM dual';

      FOR r IN (
        SELECT p.*
          FROM TW_ARCHIVE_QUALITY_PARTITIONS_VW p
         WHERE p.source_db_link = t.source_db_link
           AND p.source_owner = t.source_owner
           AND p.source_table_name = t.source_table_name
           AND p.target_owner = t.target_owner
           AND p.target_table_name = t.target_table_name
          ORDER BY p.partition_high_value, p.subpartition_high_value
      ) LOOP
        l_units := l_units + 1;

        l_source_rows := PKG_SQL.fn_run_into_sql_in_bind
        (
          p_log_id     => l_log_id,
          p_sql        => l_sql,
          p_array_bind => SYS.ODCIVARCHAR2LIST
                          (
                            r.SOURCE_OWNER,
                            r.SOURCE_TABLE_NAME,
                            r.SOURCE_PARTITION_NAME,
                            CASE WHEN r.SOURCE_SUBPARTITION_NAME = '#' THEN NULL ELSE r.SOURCE_SUBPARTITION_NAME END
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

        DBMS_OUTPUT.PUT_LINE('QUALITY ' || r.SOURCE_DB_LINK || '.' || r.SOURCE_OWNER || '.' ||
                             r.SOURCE_TABLE_NAME || ' source_name=' || r.SOURCE_PARTITION_NAME ||
                             CASE WHEN r.SOURCE_SUBPARTITION_NAME <> '#' THEN '.' || r.SOURCE_SUBPARTITION_NAME ELSE NULL END ||
                             ' target_name=' || r.PARTITION_NAME ||
                             CASE WHEN r.SUBPARTITION_NAME <> '#' THEN '.' || r.SUBPARTITION_NAME ELSE NULL END ||
                             ' source_rows=' || NVL(TO_CHAR(l_source_rows), 'NULL') ||
                             ' target_rows=' || NVL(TO_CHAR(r.TARGET_ROW_COUNT), 'NULL') ||
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

          COMMIT;
        END IF;

        l_table_summary := l_table_summary ||
          TO_CLOB(PKG_ARCHIVE_LOG.fn_summary_cell('target=' || r.target_owner || '.' || r.target_table_name ||
                                          ' ' || r.partition_name ||
                                          CASE WHEN r.archive_unit_type = 'SUBPARTITION' THEN '.' || r.subpartition_name END ||
                                          ', execute=' || l_execute_flag)) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_partition_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_subpartition_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.partition_high_value) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.subpartition_high_value) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.archive_status) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(l_quality_status) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.truncate_status) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(TO_CHAR(l_source_rows)) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(TO_CHAR(r.target_row_count)) || CHR(10);
      END LOOP; -- FOR r

      IF l_table_summary IS NOT NULL THEN
        l_summary := l_summary ||
          '=== TABLE: ' || t.source_db_link || '.' || t.source_owner || '.' || t.source_table_name || ' ===' || CHR(10) || CHR(10) ||
          PKG_SQL.fn_format_table(
            p_columns => 'SOURCE_DB_LINK|TABLE_OWNER|TABLE_NAME',
            p_rows    => PKG_ARCHIVE_LOG.fn_summary_cell(t.source_db_link) || '|' ||
                         PKG_ARCHIVE_LOG.fn_summary_cell(t.source_owner) || '|' ||
                         PKG_ARCHIVE_LOG.fn_summary_cell(t.source_table_name) || CHR(10)
          ) || CHR(10) ||
          PKG_SQL.fn_format_table(
            p_columns    => l_partition_columns,
            p_rows       => l_table_summary
          ) || CHR(10);
      END IF;
    END LOOP; -- FOR t

    DBMS_OUTPUT.PUT_LINE(
      'QUALITY tables=' || l_tables ||
      ' units=' || l_units ||
      ' found=' || l_rows_available ||
      ' ok=' || l_ok ||
      ' failed=' || l_failed ||
      ' target_owner=' || NVL(l_target_owner, '<ALL>') ||
      ' target_table=' || NVL(l_target_table, '<ALL>') ||
      ' execute=' || l_execute_flag
    );

    IF l_summary IS NOT NULL THEN
      PKG_ARCHIVE_LOG.prc_log_message(l_run_id, l_summary, 'SUMMARY');
    END IF;

    PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, CASE WHEN l_failed > 0 THEN 'WARNING' ELSE 'SUCCESS' END);
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVE_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END prc_quality;
END PKG_ARCHIVE_QUALITY;
/
