SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100
WHENEVER SQLERROR EXIT

PROMPT ============================================================
PROMPT Central Layer 2 Archive smoke suite
PROMPT ============================================================

SPOOL smoke_all.log

PROMPT
PROMPT ============================================================
PROMPT Step 1: L2 range runner
PROMPT ============================================================

CONNECT CARCH/CarchDev2026_42@localhost:1521/freepdb1

SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100
WHENEVER SQLERROR EXIT

@deploy/layer2/smoke_runner_client1_loopback.sql

PROMPT
PROMPT ============================================================
PROMPT Step 2: L2 multisource range runner
PROMPT ============================================================

@deploy/layer2/smoke_runner_multisource.sql

PROMPT
PROMPT ============================================================
PROMPT Step 3: L2 multisource subpartition runner
PROMPT ============================================================

@deploy/layer2/smoke_runner_multisource_subpart.sql

PROMPT
PROMPT ============================================================
PROMPT Step 4: L2 multisource daily interval runner
PROMPT ============================================================

@deploy/layer2/smoke_runner_multisource_daily_interval.sql

PROMPT
PROMPT ============================================================
PROMPT Step 5: L2 truncate preview
PROMPT ============================================================

@deploy/layer2/smoke_truncate_preview_client1_loopback.sql

PROMPT
PROMPT ============================================================
PROMPT Step 6: L2 target row-count assertions
PROMPT ============================================================

DECLARE
  l_count NUMBER;

  PROCEDURE assert_count
  (
    p_label    IN VARCHAR2,
    p_actual   IN NUMBER,
    p_expected IN NUMBER
  ) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD(p_label, 30) || ' actual=' || p_actual ||
                         ' expected=' || p_expected);
    IF p_actual != p_expected THEN
      RAISE_APPLICATION_ERROR
      (
        -20090,
        p_label || ' expected ' || p_expected || ' rows, got ' || p_actual
      );
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO l_count FROM ORDERS_ARCH_SRC;
  assert_count('ORDERS_ARCH_SRC', l_count, 430);

  SELECT COUNT(*) INTO l_count FROM ORDERS_ARCH_SRC_2;
  assert_count('ORDERS_ARCH_SRC_2', l_count, 250);

  SELECT COUNT(*) INTO l_count FROM ORDERS_SUBPART_SRC;
  assert_count('ORDERS_SUBPART_SRC', l_count, 540);

  SELECT COUNT(*) INTO l_count FROM ORDERS_SUBPART_SRC_2;
  assert_count('ORDERS_SUBPART_SRC_2', l_count, 360);

  SELECT COUNT(*) INTO l_count FROM ORDERS_DAILY_INT_SRC;
  assert_count('ORDERS_DAILY_INT_SRC', l_count, 96);

  SELECT COUNT(*) INTO l_count FROM ORDERS_DAILY_INT_SRC_2;
  assert_count('ORDERS_DAILY_INT_SRC_2', l_count, 96);
END;
/

PROMPT
PROMPT ============================================================
PROMPT Step 7: L2 archive metadata assertions
PROMPT ============================================================

DECLARE
  l_not_ok NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO l_not_ok
    FROM TW_ARCHIVE_PARTITIONS
   WHERE ARCHIVE_STATUS != 'Y'
      OR QUALITY_STATUS != 'Y';

  DBMS_OUTPUT.PUT_LINE('L2 units not archive+quality OK: ' || l_not_ok);
  IF l_not_ok != 0 THEN
    RAISE_APPLICATION_ERROR(-20091, 'L2 has archive units without quality success');
  END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT Step 8: L3 replica runner
PROMPT ============================================================

CONNECT CREPL/CreplDev2026_42@localhost:1521/freepdb1

SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100
WHENEVER SQLERROR EXIT

PROMPT Verifying CREPL DB link to CARCH

SELECT * FROM dual@CARCH_LOOPBACK_LINK;

DECLARE
  l_bad_links NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO l_bad_links
    FROM TW_REPLICA_TABLES
   WHERE SOURCE_DB_LINK IS NULL
      OR UPPER(TRIM(SOURCE_DB_LINK)) IN ('LOCAL', 'NONE');

  DBMS_OUTPUT.PUT_LINE('Invalid replica source DB links: ' || l_bad_links);
  IF l_bad_links != 0 THEN
    RAISE_APPLICATION_ERROR(-20094, 'TW_REPLICA_TABLES contains non-DB-link SOURCE_DB_LINK values');
  END IF;
END;
/

@deploy/layer3/smoke_replica_runner.sql

PROMPT
PROMPT ============================================================
PROMPT Step 9: L3 candidate assertions
PROMPT ============================================================

DECLARE
  l_count NUMBER;

  PROCEDURE assert_zero
  (
    p_label IN VARCHAR2,
    p_count IN NUMBER
  ) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(RPAD(p_label, 30) || ' count=' || p_count);
    IF p_count != 0 THEN
      RAISE_APPLICATION_ERROR(-20092, p_label || ' expected 0, got ' || p_count);
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO l_count FROM TW_REPLICA_DISCOVERY_PARTITIONS_VW;
  assert_zero('discovery_candidates', l_count);

  SELECT COUNT(*) INTO l_count FROM TW_REPLICA_REPLICATE_PARTITIONS_VW;
  assert_zero('replicate_candidates', l_count);

  SELECT COUNT(*) INTO l_count FROM TW_REPLICA_QUALITY_PARTITIONS_VW;
  assert_zero('quality_candidates', l_count);
END;
/

PROMPT
PROMPT ============================================================
PROMPT Step 10: Invalid object assertion
PROMPT ============================================================

CONNECT SYS/r14@localhost:1521/freepdb1 AS SYSDBA

SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
SET LINESIZE 220
SET PAGESIZE 100
WHENEVER SQLERROR EXIT

DECLARE
  l_invalid NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO l_invalid
    FROM DBA_OBJECTS
   WHERE OWNER IN ('CARCH', 'CAGENT1', 'CLIENT1', 'CLIENT2', 'CREPL')
     AND STATUS != 'VALID';

  DBMS_OUTPUT.PUT_LINE('Invalid objects in smoke schemas: ' || l_invalid);
  IF l_invalid != 0 THEN
    RAISE_APPLICATION_ERROR(-20093, 'Invalid objects remain after smoke suite');
  END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT Smoke suite completed successfully.
PROMPT ============================================================

SPOOL OFF
