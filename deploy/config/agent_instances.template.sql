-- Copy to deploy/config/agent_instances.local.sql and add one call per AGENT
-- database. Keep every argument double-quoted.
--
-- Arguments:
--   instance key, connect identifier, admin user, admin password,
--   ARCHIVER-to-AGENT DB link name

@&&AGENT_ACTION_SCRIPT "AGENT_01" "localhost:1521/freepdb1" "SYS" "change_me" "AGENT_01_LINK"
@&&AGENT_ACTION_SCRIPT "AGENT_02" "remote-host:1521/sourcepdb" "SYS" "change_me" "AGENT_02_LINK"
