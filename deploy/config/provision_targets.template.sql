-- Copy to deploy/config/provision_targets.local.sql and add exactly one call
-- per unique database that will host AGENT, ARCHIVER, or REPLICA.
--
-- Arguments:
--   target key, connect identifier, admin user, admin password, admin role
--
-- The provisioning account must be allowed to create users and grant the
-- privileges listed in deploy/provision/create_application_schema.sql.

@&&PROVISION_ACTION_SCRIPT "APP_DB_01" "localhost:1521/freepdb1" "SYS" "change_me" "SYSDBA"
@&&PROVISION_ACTION_SCRIPT "APP_DB_02" "remote-host:1521/archivepdb" "SYS" "change_me" "SYSDBA"
