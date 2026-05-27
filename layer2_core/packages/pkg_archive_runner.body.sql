CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_RUNNER
AS
  FUNCTION normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION normalize_stop_step(p_stop_after_step IN VARCHAR2) RETURN VARCHAR2 IS
    l_step VARCHAR2(30);
  BEGIN
    l_step := UPPER(NVL(TRIM(p_stop_after_step), 'QUALITY'));
    IF l_step NOT IN ('DISCOVER', 'ARCHIVE', 'QUALITY', 'TRUNCATE') THEN
      raise_application_error(-20030, 'Unsupported stop step: ' || p_stop_after_step);
    END IF;
    RETURN l_step;
  END;

  FUNCTION create_run(p_source_db_link IN VARCHAR2, p_source_owner IN VARCHAR2, p_source_table IN VARCHAR2, p_execute IN VARCHAR2)
  RETURN NUMBER
  IS
  BEGIN
    RETURN PKG_ARCHIVE_LOG.create_run('RUNNER', p_source_db_link, p_source_owner, p_source_table, p_execute);
  END;

  PROCEDURE finish_run(p_run_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2 DEFAULT NULL) IS
  BEGIN
    PKG_ARCHIVE_LOG.finish_run(p_run_id, p_status, p_error_message);
  END;

  PROCEDURE run_table
  (
    p_source_db_link   IN VARCHAR2,
    p_owner            IN VARCHAR2,
    p_table_name       IN VARCHAR2,
    p_execute          IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step  IN VARCHAR2 DEFAULT 'QUALITY',
    p_truncate_execute IN VARCHAR2 DEFAULT 'N'
  )
  IS
    l_run_id           NUMBER;
    l_execute_flag     VARCHAR2(1);
    l_truncate_execute VARCHAR2(1);
    l_stop_step        VARCHAR2(30);
  BEGIN
    l_execute_flag := normalize_execute(p_execute);
    l_truncate_execute := normalize_execute(p_truncate_execute);
    l_stop_step := normalize_stop_step(p_stop_after_step);
    l_run_id := create_run(p_source_db_link, p_owner, p_table_name, p_execute);

    DBMS_OUTPUT.PUT_LINE('RUNNER ' || UPPER(p_source_db_link) || '.' || UPPER(p_owner) || '.' || UPPER(p_table_name) ||
                         ' execute=' || l_execute_flag || ' stop_after=' || l_stop_step ||
                         ' truncate_execute=' || l_truncate_execute);
    PKG_ARCHIVE_LOG.log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Runner options: execute=' || l_execute_flag ||
                   ', stop_after=' || l_stop_step ||
                   ', truncate_execute=' || l_truncate_execute
    );

    PKG_ARCHIVE_DISCOVERY.discover_table(p_source_db_link, p_owner, p_table_name, p_execute);
    IF l_stop_step = 'DISCOVER' THEN finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_IMPORT.import_table(p_source_db_link, p_owner, p_table_name, p_execute);
    IF l_stop_step = 'ARCHIVE' THEN finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_QUALITY.check_table(p_source_db_link, p_owner, p_table_name, p_execute);
    IF l_stop_step = 'QUALITY' THEN finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_TRUNCATE.truncate_table(p_source_db_link, p_owner, p_table_name, l_truncate_execute);
    finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN finish_run(l_run_id, 'ERROR', SQLERRM); END IF;
      RAISE;
  END;

  PROCEDURE run_all
  (
    p_execute          IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step  IN VARCHAR2 DEFAULT 'QUALITY',
    p_truncate_execute IN VARCHAR2 DEFAULT 'N'
  )
  IS
  BEGIN
    FOR r IN (
      SELECT SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME
        FROM TW_ARCHIVE_TABLES
       WHERE ENABLED_FLAG = 'Y'
       ORDER BY SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME
    ) LOOP
      run_table(r.SOURCE_DB_LINK, r.SOURCE_OWNER, r.SOURCE_TABLE_NAME, p_execute, p_stop_after_step, p_truncate_execute);
    END LOOP;
  END;
END PKG_ARCHIVE_RUNNER;
/
