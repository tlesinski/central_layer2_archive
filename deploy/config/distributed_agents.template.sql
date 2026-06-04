-- Copy to distributed_agents.local.sql and add one call per AGENT database.
--
-- Arguments:
--   instance key, connect identifier, application schema, application password,
--   ARCHIVER-to-AGENT DB link name, admin user, admin password, admin role

@&&DISTRIBUTED_AGENT_ACTION "AGENT_01" "source1-host:1521/sourcepdb" "PARTMGR" "change_me" "AGENT_01_LINK" "SYS" "change_me" "SYSDBA"
@&&DISTRIBUTED_AGENT_ACTION "AGENT_02" "source2-host:1521/sourcepdb" "PARTMGR" "change_me" "AGENT_02_LINK" "SYS" "change_me" "SYSDBA"
