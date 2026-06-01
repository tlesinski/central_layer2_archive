CREATE OR REPLACE PACKAGE BODY PKG_REPLICA_LOG
AS
  /*
    Package      : PKG_REPLICA_LOG
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Replica process logging - creates runs, logs messages,
                   handles errors, finishes runs

    Prerequisite : PKG_TL_LOGGING, TW_REPLICA_RUNS, MD_PROCESS_LOG_SEQ

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_create_run
  (
    p_run_type       IN VARCHAR2,
    p_source_db_link IN VARCHAR2,
    p_source_owner   IN VARCHAR2,
    p_source_table   IN VARCHAR2,
    p_execute        IN VARCHAR2
  )
  RETURN NUMBER
  IS
    l_run_id       NUMBER;
    l_log_id       NUMBER;
    l_run_type     VARCHAR2(30);
    l_execute_flag VARCHAR2(1);
  BEGIN
    l_run_type := UPPER(TRIM(p_run_type));
    l_execute_flag := fn_normalize_execute(p_execute);
    l_log_id := MD_PROCESS_LOG_SEQ.NEXTVAL;

    INSERT INTO TW_REPLICA_RUNS
      (RUN_TYPE, RUN_STATUS, SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME, MSTR_LOG_ID, EXECUTE_FLAG)
    VALUES
      (l_run_type, 'RUNNING', UPPER(p_source_db_link), UPPER(p_source_owner), UPPER(p_source_table), l_log_id, l_execute_flag)
    RETURNING RUN_ID INTO l_run_id;

    RETURN l_run_id;
  END fn_create_run;

  FUNCTION fn_get_log_id
  (
    p_run_id IN NUMBER
  )
  RETURN NUMBER
  IS
    l_log_id NUMBER;
  BEGIN
    SELECT MSTR_LOG_ID
      INTO l_log_id
      FROM TW_REPLICA_RUNS
     WHERE RUN_ID = p_run_id;

    RETURN l_log_id;
  END fn_get_log_id;

  PROCEDURE prc_log_message
  (
    p_run_id    IN NUMBER,
    p_log_msg   IN CLOB,
    p_log_type  IN VARCHAR2 DEFAULT 'TEXT',
    p_log_sttus IN VARCHAR2 DEFAULT PKG_TL_LOGGING.g_sttus_running_const
  )
  IS
    l_log_id NUMBER;
  BEGIN
    IF p_run_id IS NULL THEN
      RETURN;
    END IF;

    l_log_id := fn_get_log_id(p_run_id);

    PKG_TL_LOGGING.prc_log
    (
      p_log_id      => l_log_id,
      p_mstr_log_id => l_log_id,
      p_log_msg     => p_log_msg,
      p_log_sttus   => p_log_sttus,
      p_log_type    => p_log_type
    );
  END prc_log_message;

  PROCEDURE prc_log_error_stack
  (
    p_run_id IN NUMBER
  )
  IS
    l_log_id NUMBER;
  BEGIN
    IF p_run_id IS NULL THEN
      RETURN;
    END IF;

    l_log_id := fn_get_log_id(p_run_id);
    PKG_TL_LOGGING.prc_error_stack
    (
      p_log_id      => l_log_id,
      p_mstr_log_id => l_log_id
    );
  END prc_log_error_stack;

  FUNCTION fn_summary_cell
  (
    p_value IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
  BEGIN
    IF p_value IS NULL OR p_value = '#' THEN
      RETURN '-';
    END IF;

    RETURN REPLACE(REPLACE(REPLACE(TRIM(p_value), CHR(13), ' '), CHR(10), ' '), '|', '/');
  END fn_summary_cell;

  PROCEDURE prc_finish_run
  (
    p_run_id        IN NUMBER,
    p_status        IN VARCHAR2,
    p_error_message IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_log_id   NUMBER;
    l_run_type TW_REPLICA_RUNS.RUN_TYPE%TYPE;
  BEGIN
    SELECT MSTR_LOG_ID, RUN_TYPE
      INTO l_log_id, l_run_type
      FROM TW_REPLICA_RUNS
     WHERE RUN_ID = p_run_id;

    UPDATE TW_REPLICA_RUNS
       SET RUN_STATUS = p_status,
           ENDED_AT = SYSTIMESTAMP,
           ERROR_MESSAGE = SUBSTR(p_error_message, 1, 4000),
           UPDATED_AT = SYSTIMESTAMP
     WHERE RUN_ID = p_run_id;

    PKG_TL_LOGGING.prc_log
    (
      p_log_id          => l_log_id,
      p_mstr_log_id     => l_log_id,
      p_log_categ       => l_run_type,
      p_mstr_fun        => 'PKG_REPLICA_' || l_run_type,
      p_log_sttus       => p_status,
      p_end_date        => SYSDATE,
      p_last_err_code   => CASE WHEN p_status = 'ERROR' THEN TO_CHAR(SQLCODE) END,
      p_last_err_desc   => CASE WHEN p_status = 'ERROR' THEN SUBSTR(p_error_message, 1, 256) END,
      p_log_type        => CASE WHEN p_status = 'ERROR' THEN 'ERROR' ELSE 'TEXT' END,
      p_log_msg         => 'Finished ' || l_run_type || ' with status ' || p_status ||
                           CASE WHEN p_error_message IS NOT NULL THEN ': ' || SUBSTR(p_error_message, 1, 3000) END
    );
  END prc_finish_run;
END PKG_REPLICA_LOG;
/
