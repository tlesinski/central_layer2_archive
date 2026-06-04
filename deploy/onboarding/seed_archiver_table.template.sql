-- Copy and customize this template on the ARCHIVER database.
-- Every source must use a real ARCHIVER-to-AGENT DB link.

INSERT INTO TBL_ARCHIVER_TABLES
(
  source_db_link, source_owner, source_table_name, source_agent_schema,
  target_owner, target_table_name, truncate_mode, parallel_degree,
  tablespace_name, last_business_date, days_online, enabled_flag
)
VALUES
(
  'AGENT_01_LINK', 'CLIENT_SCHEMA', 'SOURCE_TABLE', 'PARTMGR',
  'PARTMGR', 'TBL_ARCHIVER_SOURCE_TABLE', 'TRUNCATE', 4,
  'USERS', 'DATE ''2026-06-01''', 30, 'Y'
);

COMMIT;
