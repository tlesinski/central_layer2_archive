-- Copy to deploy/config/install_config.local.sql and adjust local values.
-- Component installers load the ignored local copy of this template.

DEFINE APPLICATION_SCHEMA = PARTMGR
DEFINE APPLICATION_PASSWORD = PartmgrDev2026_42
DEFINE DEFAULT_TABLESPACE = USERS
DEFINE TEMPORARY_TABLESPACE = TEMP

DEFINE INSTALL_AGENT = Y
DEFINE INSTALL_ARCHIVER = Y
DEFINE INSTALL_REPLICA = Y

-- SQL*Net connect identifiers, without usernames or passwords.
DEFINE ARCHIVER_CONNECT = localhost:1521/freepdb1
DEFINE REPLICA_CONNECT = localhost:1521/freepdb1

-- Administrative credentials used by schema provisioning.
DEFINE ARCHIVER_ADMIN_USER = SYS
DEFINE ARCHIVER_ADMIN_PASSWORD = change_me
DEFINE REPLICA_ADMIN_USER = SYS
DEFINE REPLICA_ADMIN_PASSWORD = change_me

-- Real DB links remain mandatory, including combined-database loopback setups.
DEFINE REPLICA_ARCHIVER_DB_LINK = ARCHIVER_LINK

-- Combined single-database topology.
DEFINE COMBINED_CONNECT = localhost:1521/freepdb1
DEFINE COMBINED_AGENT_DB_LINK = COMBINED_AGENT_LINK
DEFINE COMBINED_ARCHIVER_DB_LINK = COMBINED_ARCHIVER_LINK

-- Executable manifest containing any number of AGENT database entries.
DEFINE AGENT_INSTANCE_MANIFEST = deploy/config/agent_instances.local.sql

-- Executable manifest containing every unique database that will host at least
-- one component. Each physical database must appear exactly once.
DEFINE PROVISION_TARGET_MANIFEST = deploy/config/provision_targets.local.sql
