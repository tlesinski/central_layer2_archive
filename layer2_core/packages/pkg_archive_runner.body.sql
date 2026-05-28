CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_RUNNER
AS
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_normalize_stop_step(p_stop_after_step IN VARCHAR2) RETURN VARCHAR2 IS
    l_step VARCHAR2(30);
  BEGIN
    l_step := UPPER(NVL(TRIM(p_stop_after_step), 'QUALITY'));
    IF l_step NOT IN ('DISCOVER', 'ARCHIVE', 'QUALITY', 'TRUNCATE') THEN
      raise_application_error(-20030, 'Unsupported stop step: ' || p_stop_after_step);
    END IF;
    RETURN l_step;
  END;

  PROCEDURE prc_run_table
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
    l_target_owner     VARCHAR2(128);
    l_target_table     VARCHAR2(128);
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_truncate_execute := fn_normalize_execute(p_truncate_execute);
    l_stop_step := fn_normalize_stop_step(p_stop_after_step);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('RUNNER', p_source_db_link, p_owner, p_table_name, p_execute);

    SELECT target_owner, target_table_name
      INTO l_target_owner, l_target_table
      FROM TW_ARCHIVE_TABLES
     WHERE enabled_flag = 'Y'
       AND source_db_link = UPPER(p_source_db_link)
       AND source_owner = UPPER(p_owner)
       AND source_table_name = UPPER(p_table_name);

    DBMS_OUTPUT.PUT_LINE('RUNNER ' || UPPER(p_source_db_link) || '.' || UPPER(p_owner) || '.' || UPPER(p_table_name) ||
                         ' execute=' || l_execute_flag || ' stop_after=' || l_stop_step ||
                         ' truncate_execute=' || l_truncate_execute);
    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Runner options: execute=' || l_execute_flag ||
                   ', stop_after=' || l_stop_step ||
                   ', truncate_execute=' || l_truncate_execute
    );

    PKG_ARCHIVE_DISCOVERY.prc_discover(l_execute_flag, l_target_owner, l_target_table);
    IF l_stop_step = 'DISCOVER' THEN PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_IMPORT.prc_import(l_execute_flag, l_target_owner, l_target_table);
    IF l_stop_step = 'ARCHIVE' THEN PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_QUALITY.prc_quality(l_execute_flag, l_target_owner, l_target_table);
    IF l_stop_step = 'QUALITY' THEN PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_TRUNCATE.prc_truncate(l_truncate_execute, l_target_owner, l_target_table);
    PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVE_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END;

  PROCEDURE prc_run_all
  (
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
    l_execute_flag := fn_normalize_execute(p_execute);
    l_truncate_execute := fn_normalize_execute(p_truncate_execute);
    l_stop_step := fn_normalize_stop_step(p_stop_after_step);
    l_run_id := PKG_ARCHIVE_LOG.fn_create_run('RUNNER', NULL, NULL, NULL, l_execute_flag);

    DBMS_OUTPUT.PUT_LINE('RUNNER ALL execute=' || l_execute_flag || ' stop_after=' || l_stop_step ||
                         ' truncate_execute=' || l_truncate_execute);
    PKG_ARCHIVE_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Runner all options: execute=' || l_execute_flag ||
                   ', stop_after=' || l_stop_step ||
                   ', truncate_execute=' || l_truncate_execute
    );

    PKG_ARCHIVE_DISCOVERY.prc_discover(l_execute_flag);
    IF l_stop_step = 'DISCOVER' THEN PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_IMPORT.prc_import(l_execute_flag);
    IF l_stop_step = 'ARCHIVE' THEN PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_QUALITY.prc_quality(l_execute_flag);
    IF l_stop_step = 'QUALITY' THEN PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS'); RETURN; END IF;

    PKG_ARCHIVE_TRUNCATE.prc_truncate(l_truncate_execute);

    PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVE_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVE_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END;
END PKG_ARCHIVE_RUNNER;
/


