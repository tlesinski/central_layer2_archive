CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_TRUNCATE
AS
  /*
    Package      : PKG_ARCHIVE_TRUNCATE
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Source truncate - request source truncate through layer 1 agent
                   after quality success, respecting RETENTION_RULE

    Prerequisite : PKG_SQL, PKG_ARCHIVE_LOG, PKG_ARCHIVE_AGENT,
                   TW_ARCHIVE_TRUNCATE_PARTITIONS_VW

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
    1.1        2026-05-28   Tomasz Lesinski    Add process summary logging
    1.2        2026-05-29   Tomasz Lesinski    Abort on invalid RETENTION_RULE
    1.3        2026-05-29   Tomasz Lesinski    Abort on invalid PRESERVE_RULE
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
    l_summary         CLOB := NULL;
    l_bad_tables      NUMBER := 0;
    l_summary_columns VARCHAR2(1000) :=
      'SOURCE_DB_LINK|TABLE_OWNER|TABLE_NAME|SOURCE_PARTITION_NAME|SOURCE_SUBPARTITION_NAME|PARTITION_NAME|SUBPARTITION_NAME|LAST_BUSINESS_DATE|DAYS_ONLINE|CUTOFF_DATE|PARTITION_HIGH_VALUE|SUBPARTITION_HIGH_VALUE|ARCHIVE_STATUS|QUALITY_STATUS|TRUNCATE_STATUS|SOURCE_ROW_COUNT|TARGET_ROW_COUNT|NOTE';
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_target_owner := fn_normalize_name(p_target_owner);
    l_target_table := fn_normalize_name(p_target_table_name);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('TRUNCATE', NULL, NULL, NULL, l_execute_flag);
    l_log_id := PKG_ARCHIVE_LOG.fn_get_log_id(l_run_id);

    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started TRUNCATE with parameters:' || CHR(10) ||
                   '  p_execute           => ' || l_execute_flag || CHR(10) ||
                   '  p_target_owner      => ' || NVL(l_target_owner, '<ALL>') || CHR(10) ||
                   '  p_target_table_name => ' || NVL(l_target_table, '<ALL>')
    );

    -- FOR bad IN (
    --   SELECT source_db_link, source_owner, source_table_name, retention_rule, retention_calc
    --     FROM tw_archive_tables
    --    WHERE retention_calc LIKE 'ERROR:%'
    --      AND (l_target_owner IS NULL OR target_owner = l_target_owner)
    --      AND (l_target_table IS NULL OR target_table_name = l_target_table)
    -- ) LOOP
    --   PKG_ARCHIVE_LOG.prc_log_message
    --   (
    --     p_run_id  => l_run_id,
    --     p_log_msg => 'ERROR: table ' || bad.source_owner || '.' || bad.source_table_name ||
    --                  ' retention_rule "' || bad.retention_rule || '" - ' || bad.retention_calc
    --   );
    --   l_bad_tables := l_bad_tables + 1;
    -- END LOOP;

    FOR bad IN (
      SELECT source_db_link, source_owner, source_table_name, preserve_rule, preserve_calc
        FROM tw_archive_tables
       WHERE preserve_calc LIKE 'ERROR:%'
         AND (l_target_owner IS NULL OR target_owner = l_target_owner)
         AND (l_target_table IS NULL OR target_table_name = l_target_table)
    ) LOOP
      PKG_ARCHIVE_LOG.prc_log_message
      (
        p_run_id  => l_run_id,
        p_log_msg => 'ERROR: table ' || bad.source_owner || '.' || bad.source_table_name ||
                     ' preserve_rule "' || bad.preserve_rule || '" - ' || bad.preserve_calc
      );
      l_bad_tables := l_bad_tables + 1;
    END LOOP;

    IF l_bad_tables > 0 THEN
      PKG_ARCHIVE_LOG.prc_log_message
      (
        p_run_id  => l_run_id,
        p_log_msg => 'ERROR: ' || l_bad_tables || ' table(s) with invalid retention or preserve rule - aborting TRUNCATE'
      );
      PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'ERROR', l_bad_tables || ' table(s) with invalid retention or preserve rule');
      RAISE_APPLICATION_ERROR(-20001, l_bad_tables || ' table(s) with invalid retention or preserve rule. Fix before retrying.');
    END IF;

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
          ORDER BY p.partition_high_value, p.subpartition_high_value
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

        l_summary := l_summary ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_db_link) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_owner) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_table_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_partition_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.source_subpartition_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.partition_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.subpartition_name) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.last_business_date_calc) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.days_online) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.cutoff_date) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.partition_high_value) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.subpartition_high_value) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.archive_status) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(r.quality_status) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(CASE WHEN l_execute_flag = 'Y' THEN 'Y' ELSE 'N' END) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(TO_CHAR(r.source_row_count)) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell(TO_CHAR(r.target_row_count)) || '|' ||
          PKG_ARCHIVE_LOG.fn_summary_cell('source=' || r.source_owner || '.' || r.source_table_name ||
                                          ' ' || r.source_partition_name ||
                                          CASE WHEN r.archive_unit_type = 'SUBPARTITION' THEN '.' || r.source_subpartition_name END ||
                                          ', mode=TRUNCATE, execute=' || l_execute_flag ||
                                          ', cutoff=' || TO_CHAR(r.cutoff_date, 'YYYY-MM-DD')) ||
          CHR(10);
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

    IF l_summary IS NOT NULL THEN
      PKG_ARCHIVE_LOG.prc_log_summary
      (
        p_run_id       => l_run_id,
        p_process_name => 'TRUNCATE',
        p_columns      => l_summary_columns,
        p_rows         => l_summary
      );
    END IF;

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
