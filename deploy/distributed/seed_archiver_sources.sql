SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

BEGIN
  FOR r IN (
    SELECT 'DIST_AGENT_01_LINK' source_db_link,
           'PMGR_D_AGENT1' source_agent_schema,
           'TBL_ARCHIVER_ORDERS_SRC' target_table_name
      FROM dual
    UNION ALL
    SELECT 'DIST_AGENT_02_LINK',
           'PMGR_D_AGENT2',
           'TBL_ARCHIVER_ORDERS_SRC_2'
      FROM dual
  ) LOOP
    INSERT INTO TBL_ARCHIVER_TABLES
    (
      source_db_link, source_owner, source_table_name, source_agent_schema,
      target_owner, target_table_name, truncate_mode, parallel_degree,
      tablespace_name, last_business_date, days_online, enabled_flag
    )
    VALUES
    (
      r.source_db_link, 'CLIENT1', 'ORDERS_ARCH_SRC', r.source_agent_schema,
      'PMGR_D_ARCHIVER', r.target_table_name, 'TRUNCATE', 4,
      'USERS', 'DATE ''2026-06-01''', 30, 'Y'
    );

    INSERT INTO TBL_ARCHIVER_PARTITIONS
    (
      source_db_link, source_owner, source_table_name, target_owner, target_table_name,
      archive_unit_type, source_partition_name, source_subpartition_name,
      partition_name, subpartition_name, partition_high_value, subpartition_high_value,
      archive_status, quality_status, truncate_status, source_row_count, target_row_count
    )
    VALUES
    (
      r.source_db_link, 'CLIENT1', 'ORDERS_ARCH_SRC', 'PMGR_D_ARCHIVER', r.target_table_name,
      'PARTITION', 'P_ERROR', '#', 'P_ERROR', '#',
      'TO_DATE('' 1800-01-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')',
      '#', 'Y', 'Y', 'Y', 0, 0
    );
  END LOOP;

  COMMIT;
END;
/
