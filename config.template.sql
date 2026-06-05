/*
  Local installation configuration used by root-level installation scripts.

  INSTALL_MODEL controls where component code is installed:
    SPLIT  - installs AGENT, ARCHIVER, and REPLICA in their separate schemas.
    SHARED - installs all three components in SHARED_SCHEMA.

  RESET_CONFIRMATION protects all configured schemas from accidental removal:
    NOT_CONFIRMED - reset_schemas.sql stops before the first DROP USER.
    RESET_ALL     - reset_schemas.sql drops and recreates all six schemas:
                    CLIENT1, CLIENT2, AGENT, ARCHIVER, REPLICA, and SHARED.
  The reset always processes all six schemas, regardless of INSTALL_MODEL.

  RUN_SEEDS_AFTER_REINSTALL controls whether reinstall.sql invokes seed.sql
  after code installation. REBUILD_SEED_* flags control destructive demo seed
  rebuilds. ARCHIVER cascades to CLIENT; REPLICA cascades to ARCHIVER and CLIENT.
  Seeds rebuild only their demo tables, metadata, and related runs. They do not
  reset component sequences or process logs.

  DEFAULT_TABLESPACE and TEMPORARY_TABLESPACE are assigned to every schema
  created by reset_schemas.sql.

  *_SYS_CONNECT and *_SYS_PASSWORD define the three administrative database
  connections used to reset schemas and install code. The SYS username and
  SYSDBA role are fixed by the installation scripts.

  *_SCHEMA and *_PASSWORD define configurable application schema credentials.
  CLIENT1, CLIENT2, AGENT, and SHARED are created on SOURCE_SYS_CONNECT.
  ARCHIVER is created on ARCHIVER_SYS_CONNECT.
  REPLICA is created on REPLICA_SYS_CONNECT.

  *_DB_LINK values define real Oracle database link names created between
  logical components. SPLIT uses ARCHIVER_AGENT_DB_LINK and
  REPLICA_ARCHIVER_DB_LINK. SHARED uses the two SHARED_* DB links.

  Keep this local file private because it contains passwords.
*/

-- Copy to config.local.sql in the repository root and adjust local values.

DEFINE INSTALL_MODEL = SPLIT
DEFINE RESET_CONFIRMATION = NOT_CONFIRMED
DEFINE RUN_SEEDS_AFTER_REINSTALL = N

DEFINE REBUILD_SEED_CLIENT = N
DEFINE REBUILD_SEED_ARCHIVER = N
DEFINE REBUILD_SEED_REPLICA = N

DEFINE DEFAULT_TABLESPACE = USERS
DEFINE TEMPORARY_TABLESPACE = TEMP

DEFINE SOURCE_SYS_CONNECT = source-host:1521/sourcepdb
DEFINE SOURCE_SYS_PASSWORD = change_me

DEFINE ARCHIVER_SYS_CONNECT = archive-host:1521/archivepdb
DEFINE ARCHIVER_SYS_PASSWORD = change_me

DEFINE REPLICA_SYS_CONNECT = replica-host:1521/replicapdb
DEFINE REPLICA_SYS_PASSWORD = change_me

DEFINE CLIENT1_SCHEMA = CLIENT1
DEFINE CLIENT1_PASSWORD = change_me

DEFINE CLIENT2_SCHEMA = CLIENT2
DEFINE CLIENT2_PASSWORD = change_me

DEFINE AGENT_SCHEMA = PARTMGR_AGENT
DEFINE AGENT_PASSWORD = change_me

DEFINE ARCHIVER_SCHEMA = PARTMGR_ARCHIVER
DEFINE ARCHIVER_PASSWORD = change_me

DEFINE REPLICA_SCHEMA = PARTMGR_REPLICA
DEFINE REPLICA_PASSWORD = change_me

DEFINE SHARED_SCHEMA = PARTMGR_SHARED
DEFINE SHARED_PASSWORD = change_me

DEFINE ARCHIVER_AGENT_DB_LINK = AGENT_LINK
DEFINE REPLICA_ARCHIVER_DB_LINK = ARCHIVER_LINK
DEFINE SHARED_AGENT_DB_LINK = SHARED_AGENT_LINK
DEFINE SHARED_ARCHIVER_DB_LINK = SHARED_ARCHIVER_LINK
