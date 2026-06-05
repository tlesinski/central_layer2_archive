# Installation

Public installation scripts are located in the repository root. Open them
directly in SQL Developer and run with **F5 (Run Script)**. All nested paths
remain below the root and are resolved relative to the current script.

## Central Configuration

Copy:

```text
config.template.sql -> config.local.sql
```

The ignored local file defines:

- `SHARED` or `SPLIT` installation model,
- three SYS connections: source, ARCHIVER, and REPLICA,
- six configurable schema names and passwords,
- default and temporary tablespaces,
- required real DB-link names.

Validate without resetting schemas:

```text
@validate_config.sql
```

## Schema Reset

`reset_schemas.sql` always drops and recreates all six configured schemas:

```text
CLIENT1
CLIENT2
PARTMGR_AGENT
PARTMGR_ARCHIVER
PARTMGR_REPLICA
PARTMGR_SHARED
```

It requires the explicit configuration token:

```text
RESET_CONFIRMATION = RESET_ALL
```

Run:

```text
@reset_schemas.sql
```

CLIENT schemas receive a standard data-owner profile. AGENT receives
`SELECT ANY TABLE` and `ALTER ANY TABLE`. SHARED receives the complete component
privilege superset.

## Code Installation

Run:

```text
@install_code.sql
```

For a full destructive reset followed by code installation, run:

```text
@reinstall.sql
```

## Optional Demo Seeds

The following `config.local.sql` flags control demo seed rebuilding:

```sql
DEFINE RUN_SEEDS_AFTER_REINSTALL = N
DEFINE REBUILD_SEED_CLIENT = N
DEFINE REBUILD_SEED_ARCHIVER = N
DEFINE REBUILD_SEED_REPLICA = N
```

Run `@seed.sql` manually, or set `RUN_SEEDS_AFTER_REINSTALL=Y` to invoke it
after `reinstall.sql`. ARCHIVER cascades to CLIENT. REPLICA cascades to
ARCHIVER and CLIENT.

Seed modules destructively recreate only their demo tables, metadata, and
related runs. Component sequences, process logs, code, links, and unrelated
metadata are preserved.

For `SHARED`, all component code and two distinct loopback links are installed
in the configured SHARED schema on the source database.

For `SPLIT`, component code is installed in AGENT, ARCHIVER, and REPLICA schemas
on their configured databases. ARCHIVER-to-AGENT and REPLICA-to-ARCHIVER links
are created automatically.

## Component Installers

The following code-only installers remain available:

```text
@install_agent.sql
@install_archiver.sql
@install_replica.sql
@install_combined.sql
@deploy_distributed.sql
```

All use root-level `config.local.sql`.

## Post-Installation Check

Run in every active component schema:

```sql
SELECT object_name, object_type
FROM user_objects
WHERE status <> 'VALID';
```
