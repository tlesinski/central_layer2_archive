PROMPT ARCHIVER 007 - target metadata, soft validation and count history

CONNECT &&ACTIVE_ARCHIVER_SCHEMA/"&&ACTIVE_ARCHIVER_PASSWORD"@&&ACTIVE_ARCHIVER_CONNECT

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_count FROM VW_ARCHIVER_TARGET_PARTITIONS;
  IF l_count = 0 THEN RAISE_APPLICATION_ERROR(-20670, 'Target partition view returned no rows'); END IF;

  SELECT COUNT(*) INTO l_count
    FROM (SELECT source_db_link, source_owner, source_table_name,
                 partition_high_value, subpartition_high_value
            FROM VW_ARCHIVER_SOFT_VALIDATION
           GROUP BY source_db_link, source_owner, source_table_name,
                    partition_high_value, subpartition_high_value
          HAVING COUNT(*) > 1);
  IF l_count <> 0 THEN RAISE_APPLICATION_ERROR(-20671, 'Soft validation duplicated HIGH_VALUE identities'); END IF;
END;
/

DECLARE
  l_before NUMBER;
  l_after NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_before FROM TBL_ARCHIVER_AUDIT_RESULTS;
  PKG_ARCHIVER_AUDIT.prc_soft_count;
  PKG_ARCHIVER_AUDIT.prc_soft_count;
  SELECT COUNT(*) INTO l_after FROM TBL_ARCHIVER_AUDIT_RESULTS;
  IF l_after <= l_before THEN RAISE_APPLICATION_ERROR(-20672, 'Soft count did not append audit history'); END IF;

  SELECT COUNT(DISTINCT run_id) INTO l_after
    FROM TBL_ARCHIVER_AUDIT_RESULTS
   WHERE run_id IN (SELECT run_id FROM TBL_ARCHIVER_RUNS WHERE run_type='SOFT_COUNT');
  IF l_after < 2 THEN RAISE_APPLICATION_ERROR(-20673, 'Expected two historical SOFT_COUNT runs'); END IF;
END;
/

SAVEPOINT before_name_test;
UPDATE TBL_ARCHIVER_PARTITIONS
   SET partition_name = partition_name || '_X'
 WHERE ROWID = (SELECT MIN(ROWID) FROM TBL_ARCHIVER_PARTITIONS);

DECLARE
  l_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_count
    FROM VW_ARCHIVER_SOFT_VALIDATION
   WHERE target_metadata_name_status = 'MISMATCH'
     AND validation_status = 'MISMATCH';
  IF l_count = 0 THEN RAISE_APPLICATION_ERROR(-20675, 'Name drift was not detected by HIGH_VALUE identity'); END IF;
END;
/
ROLLBACK TO before_name_test;

PROMPT ARCHIVER 007 completed
