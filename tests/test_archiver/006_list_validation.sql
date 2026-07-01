PROMPT ARCHIVER 006 - structural validation and metadata exclusions

CONNECT &&ACTIVE_ARCHIVER_SCHEMA/"&&ACTIVE_ARCHIVER_PASSWORD"@&&ACTIVE_ARCHIVER_CONNECT

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TBL_ARCHIVER_TEST_TYPE PURGE';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TBL_ARCHIVER_TEST_MULTI PURGE';
EXCEPTION
  WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE TBL_ARCHIVER_TEST_TYPE
(
  ORDER_DATE VARCHAR2(30) NOT NULL
)
PARTITION BY LIST (ORDER_DATE)
(
  PARTITION P_ERROR VALUES ('#ERROR#')
);

CREATE TABLE TBL_ARCHIVER_TEST_MULTI
(
  ORDER_DATE DATE NOT NULL,
  ORDER_ID   NUMBER NOT NULL
)
PARTITION BY RANGE (ORDER_DATE, ORDER_ID)
(
  PARTITION P_ERROR VALUES LESS THAN (DATE '1800-01-01', 0)
);

DECLARE
  PROCEDURE assert_validation_error
  (
    p_target_table     IN VARCHAR2,
    p_partition_method IN VARCHAR2,
    p_expected_code    IN NUMBER
  )
  IS
  BEGIN
    BEGIN
      PKG_ARCHIVER_DISCOVERY.prc_validate_table_setup
      (
        p_source_db_link      => UPPER('&&ACTIVE_AGENT_LINK'),
        p_source_owner        => UPPER('&&CLIENT1_SCHEMA'),
        p_source_table_name   => 'ORDERS_LIST_DATE_SRC',
        p_target_owner        => UPPER('&&ACTIVE_ARCHIVER_SCHEMA'),
        p_target_table_name   => p_target_table,
        p_partition_method    => p_partition_method,
        p_subpartition_method => NULL
      );
      RAISE_APPLICATION_ERROR(-20650, 'Expected validation error was not raised');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != p_expected_code THEN
          RAISE;
        END IF;
    END;
  END;
BEGIN
  assert_validation_error('TBL_ARCHIVER_CLIENT1_LIST_DATE', 'RANGE', -20064);
  assert_validation_error('TBL_ARCHIVER_TEST_TYPE', 'LIST', -20066);
  assert_validation_error('TBL_ARCHIVER_TEST_MULTI', 'LIST', -20062);

END;
/

DECLARE
  l_source_rows    NUMBER;
  l_metadata_rows  NUMBER;
  l_discovery_rows NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO l_source_rows
    FROM VW_ARCHIVER_SOURCE_PARTITIONS
   WHERE source_owner = UPPER('&&CLIENT1_SCHEMA')
     AND source_table_name = 'ORDERS_ARCH_SRC'
     AND partition_high_value = 'MAXVALUE';

  SELECT COUNT(*)
    INTO l_metadata_rows
    FROM TBL_ARCHIVER_PARTITIONS
   WHERE source_owner = UPPER('&&CLIENT1_SCHEMA')
     AND source_table_name = 'ORDERS_ARCH_SRC'
     AND partition_high_value = 'MAXVALUE'
     AND archive_status = 'Y'
     AND quality_status = 'Y'
     AND truncate_status = 'Y';

  SELECT COUNT(*)
    INTO l_discovery_rows
    FROM VW_ARCHIVER_DISCOVERY_PARTITIONS
   WHERE source_owner = UPPER('&&CLIENT1_SCHEMA')
     AND source_table_name = 'ORDERS_ARCH_SRC'
     AND partition_high_value = 'MAXVALUE';

  IF l_source_rows <> 1 OR l_metadata_rows <> 1 OR l_discovery_rows <> 0 THEN
    RAISE_APPLICATION_ERROR(-20651, 'MAXVALUE metadata exclusion is not effective');
  END IF;
END;
/

DROP TABLE TBL_ARCHIVER_TEST_TYPE PURGE;
DROP TABLE TBL_ARCHIVER_TEST_MULTI PURGE;

PROMPT ARCHIVER 006 completed
