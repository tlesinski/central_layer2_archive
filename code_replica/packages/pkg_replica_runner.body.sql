CREATE OR REPLACE PACKAGE BODY PKG_REPLICA_RUNNER
AS
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_stop_after(p_stop_after_step IN VARCHAR2) RETURN VARCHAR2 IS
    l_step VARCHAR2(30);
  BEGIN
    l_step := UPPER(TRIM(p_stop_after_step));

    IF l_step IS NULL THEN
      RETURN NULL;
    END IF;

    IF l_step NOT IN ('DISCOVER', 'REPLICATE', 'QUALITY', 'PURGE') THEN
      RAISE_APPLICATION_ERROR(-20220, 'Invalid L3 stop_after_step: ' || p_stop_after_step);
    END IF;

    RETURN l_step;
  END;

  PROCEDURE prc_run
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step   IN VARCHAR2 DEFAULT NULL,
    p_purge_execute     IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  )
  IS
    l_execute_flag VARCHAR2(1);
    l_purge_flag   VARCHAR2(1);
    l_stop_after   VARCHAR2(30);
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);
    l_purge_flag := fn_normalize_execute(p_purge_execute);
    l_stop_after := fn_stop_after(p_stop_after_step);

    DBMS_OUTPUT.PUT_LINE('REPLICA_RUNNER execute=' || l_execute_flag ||
                         ' purge_execute=' || l_purge_flag ||
                         ' stop_after=' || NVL(l_stop_after, '<FULL>') ||
                         ' target_owner=' || NVL(p_target_owner, '<ALL>') ||
                         ' target_table=' || NVL(p_target_table_name, '<ALL>'));

    PKG_REPLICA_DISCOVERY.prc_discover
    (
      p_execute           => l_execute_flag,
      p_target_owner      => p_target_owner,
      p_target_table_name => p_target_table_name
    );

    IF l_stop_after = 'DISCOVER' THEN
      RETURN;
    END IF;

    PKG_REPLICA_REPLICATE.prc_replicate
    (
      p_execute           => l_execute_flag,
      p_target_owner      => p_target_owner,
      p_target_table_name => p_target_table_name
    );

    IF l_stop_after = 'REPLICATE' THEN
      RETURN;
    END IF;

    PKG_REPLICA_QUALITY.prc_quality
    (
      p_execute           => l_execute_flag,
      p_target_owner      => p_target_owner,
      p_target_table_name => p_target_table_name
    );

    IF l_stop_after = 'QUALITY' THEN
      RETURN;
    END IF;

    PKG_REPLICA_PURGE.prc_purge
    (
      p_execute           => l_purge_flag,
      p_target_owner      => p_target_owner,
      p_target_table_name => p_target_table_name
    );
  END prc_run;
END PKG_REPLICA_RUNNER;
/
