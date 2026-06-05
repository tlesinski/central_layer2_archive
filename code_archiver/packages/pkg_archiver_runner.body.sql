CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVER_RUNNER
AS
  /*
    Package      : PKG_ARCHIVER_RUNNER
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Archive runner - orchestrates DISCOVER -> ARCHIVE -> QUALITY
                   -> TRUNCATE flow for one or all tables

    Prerequisite : PKG_ARCHIVER_DISCOVERY, PKG_ARCHIVER_IMPORT, PKG_ARCHIVER_QUALITY,
                   PKG_ARCHIVER_TRUNCATE, PKG_ARCHIVER_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
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

  FUNCTION fn_total_steps(p_stop_step IN VARCHAR2) RETURN PLS_INTEGER IS
  BEGIN
    CASE p_stop_step
      WHEN 'DISCOVER' THEN RETURN 1;
      WHEN 'ARCHIVE'  THEN RETURN 2;
      WHEN 'QUALITY'  THEN RETURN 3;
      WHEN 'TRUNCATE' THEN RETURN 4;
    END CASE;
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
    l_total_steps      PLS_INTEGER;
    l_target_owner     VARCHAR2(128);
    l_target_table     VARCHAR2(128);
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_truncate_execute := fn_normalize_execute(p_truncate_execute);
    l_stop_step := fn_normalize_stop_step(p_stop_after_step);
    l_total_steps := fn_total_steps(l_stop_step);
    l_run_id := PKG_ARCHIVER_LOG.fn_create_run('RUNNER', p_source_db_link, p_owner, p_table_name, p_execute);

    SELECT target_owner, target_table_name
      INTO l_target_owner, l_target_table
      FROM TBL_ARCHIVER_TABLES
     WHERE enabled_flag = 'Y'
       AND source_db_link = UPPER(p_source_db_link)
       AND source_owner = UPPER(p_owner)
       AND source_table_name = UPPER(p_table_name);

    DBMS_OUTPUT.PUT_LINE('RUNNER ' || UPPER(p_source_db_link) || '.' || UPPER(p_owner) || '.' || UPPER(p_table_name) ||
                         ' execute=' || l_execute_flag || ' stop_after=' || l_stop_step ||
                         ' truncate_execute=' || l_truncate_execute);
    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started RUNNER with parameters:' || CHR(10) ||
                   '  p_source_db_link    => ' || UPPER(p_source_db_link) || CHR(10) ||
                   '  p_owner             => ' || UPPER(p_owner) || CHR(10) ||
                   '  p_table_name        => ' || UPPER(p_table_name) || CHR(10) ||
                   '  p_execute           => ' || l_execute_flag || CHR(10) ||
                   '  p_stop_after_step   => ' || l_stop_step || CHR(10) ||
                   '  p_truncate_execute  => ' || l_truncate_execute || CHR(10) ||
                   '  total_steps         => ' || l_total_steps
    );

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 1/' || l_total_steps || ': DISCOVER - discovering new source partitions'
    );
    PKG_ARCHIVER_DISCOVERY.prc_discover(l_execute_flag, l_target_owner, l_target_table);
    IF l_stop_step = 'DISCOVER' THEN
      PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished at stop step DISCOVER');
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
      RETURN;
    END IF;

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 2/' || l_total_steps || ': ARCHIVE - importing source data via exchange staging'
    );
    PKG_ARCHIVER_IMPORT.prc_import(l_execute_flag, l_target_owner, l_target_table);
    IF l_stop_step = 'ARCHIVE' THEN
      PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished at stop step ARCHIVE');
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
      RETURN;
    END IF;

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 3/' || l_total_steps || ': QUALITY - comparing source vs target row counts'
    );
    PKG_ARCHIVER_QUALITY.prc_quality(l_execute_flag, l_target_owner, l_target_table);
    IF l_stop_step = 'QUALITY' THEN
      PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished at stop step QUALITY (TRUNCATE skipped)');
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
      RETURN;
    END IF;

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 4/' || l_total_steps || ': TRUNCATE - requesting source truncate through agent' ||
                   CASE WHEN l_truncate_execute = 'Y' THEN '' ELSE ' (preview mode)' END
    );
    PKG_ARCHIVER_TRUNCATE.prc_truncate(l_truncate_execute, l_target_owner, l_target_table);
    PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished all steps');
    PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVER_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
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
    l_total_steps      PLS_INTEGER;
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_truncate_execute := fn_normalize_execute(p_truncate_execute);
    l_stop_step := fn_normalize_stop_step(p_stop_after_step);
    l_total_steps := fn_total_steps(l_stop_step);
    l_run_id := PKG_ARCHIVER_LOG.fn_create_run('RUNNER', NULL, NULL, NULL, l_execute_flag);

    DBMS_OUTPUT.PUT_LINE('RUNNER ALL execute=' || l_execute_flag || ' stop_after=' || l_stop_step ||
                         ' truncate_execute=' || l_truncate_execute);
    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Started RUNNER ALL with parameters:' || CHR(10) ||
                   '  p_execute          => ' || l_execute_flag || CHR(10) ||
                   '  p_stop_after_step  => ' || l_stop_step || CHR(10) ||
                   '  p_truncate_execute => ' || l_truncate_execute || CHR(10) ||
                   '  total_steps        => ' || l_total_steps
    );

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 1/' || l_total_steps || ': DISCOVER - discovering new source partitions'
    );
    PKG_ARCHIVER_DISCOVERY.prc_discover(l_execute_flag);
    IF l_stop_step = 'DISCOVER' THEN
      PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished at stop step DISCOVER');
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
      RETURN;
    END IF;

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 2/' || l_total_steps || ': ARCHIVE - importing source data via exchange staging'
    );
    PKG_ARCHIVER_IMPORT.prc_import(l_execute_flag);
    IF l_stop_step = 'ARCHIVE' THEN
      PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished at stop step ARCHIVE');
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
      RETURN;
    END IF;

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 3/' || l_total_steps || ': QUALITY - comparing source vs target row counts'
    );
    PKG_ARCHIVER_QUALITY.prc_quality(l_execute_flag);
    IF l_stop_step = 'QUALITY' THEN
      PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished at stop step QUALITY (TRUNCATE skipped)');
      PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
      RETURN;
    END IF;

    PKG_ARCHIVER_LOG.prc_log_message
    (
      p_run_id  => l_run_id,
      p_log_msg => 'Step 4/' || l_total_steps || ': TRUNCATE - requesting source truncate through agent' ||
                   CASE WHEN l_truncate_execute = 'Y' THEN '' ELSE ' (preview mode)' END
    );
    PKG_ARCHIVER_TRUNCATE.prc_truncate(l_truncate_execute);

    PKG_ARCHIVER_LOG.prc_log_message(p_run_id => l_run_id, p_log_msg => 'Runner finished all steps');
    PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'SUCCESS');
  EXCEPTION
    WHEN OTHERS THEN
      IF l_run_id IS NOT NULL THEN
        PKG_ARCHIVER_LOG.prc_log_error_stack(l_run_id);
        PKG_ARCHIVER_LOG.prc_finish_run(l_run_id, 'ERROR', SQLERRM);
      END IF;
      RAISE;
  END;
END PKG_ARCHIVER_RUNNER;
/


