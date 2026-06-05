# PARTMGR Oracle Archive Control Plane

This repository contains Oracle code for three components:

- **AGENT**: controlled source metadata, row counts, and source cleanup.
- **ARCHIVER**: archive orchestration, quality, and cleanup eligibility.
- **REPLICA**: bounded replication of qualified ARCHIVER data.

## Code Layout

```text
*.sql           root-level configuration and installation entry points
code_root/      low-level schema and database-link helpers
code_agent/     AGENT database objects
code_archiver/  ARCHIVER database objects
code_replica/   REPLICA database objects
tests/          independent smoke tests
docs/           architecture and operations
```

## Installation Models

`SHARED` installs AGENT, ARCHIVER, and REPLICA in one configured
`PARTMGR_SHARED`-style schema on the source database.

`SPLIT` installs:

```text
AGENT    -> source database
ARCHIVER -> archive database
REPLICA  -> replica database
```

CLIENT1, CLIENT2, AGENT, and SHARED schemas are always managed through the
single configured source SYS connection.

## Quick Start

Copy and edit:

```text
config.template.sql -> config.local.sql
```

To destructively recreate all six configured schemas, explicitly set:

```text
RESET_CONFIRMATION = RESET_ALL
```

Then open `reinstall.sql` and run it as a script, or run reset and
installation separately:

```text
@reinstall.sql

@reset_schemas.sql
@install_code.sql
```

By default, reset and installation do not create business targets, metadata
seeds, sample data, or tests.

## Demo Seeds

Demo sources, targets, and metadata are managed separately by `seed.sql`.
Configure the seed flags in `config.local.sql`:

```text
RUN_SEEDS_AFTER_REINSTALL
REBUILD_SEED_CLIENT
REBUILD_SEED_ARCHIVER
REBUILD_SEED_REPLICA
REBUILD_SEED_MAIL
```

`CLIENT` rebuild cascades to `ARCHIVER` and `REPLICA`. `ARCHIVER` rebuild
cascades to `REPLICA`. `REPLICA` rebuilds only REPLICA. `MAIL` updates only
utility mail metadata. Run manually with:

```text
@seed.sql
```

Each seeded client receives RANGE, RANGE-LIST, and daily INTERVAL-LIST source
tables. Daily interval partitions are normalized to `PYYYYMMDD` names.

When `RUN_SEEDS_AFTER_REINSTALL=Y`, `reinstall.sql` runs the configured seed
cascade after installing code.

## Local Mail Reports

`PKG_UTIL_MAIL` sends through plain SMTP. For local development, run `smtp4dev`
on `localhost:2525`, set `CONFIGURE_MAIL_ACL=Y` to grant Oracle network ACLs,
and set `REBUILD_SEED_MAIL=Y` with the desired `MAIL_*` values to update
`TBL_UTIL_CONFIG`. Mail remains disabled by default.

## Smoke Tests

Smoke tests are independent from installation and seeds. They assume the
required code and demo seed state already exists. Run from the repository root:

```text
@test.sql CLIENT ALL
@test.sql ARCHIVER 003
@test.sql REPLICA ALL
@test.sql ALL ALL
```

Configure optional post-reinstall execution with:

```text
RUN_TESTS_AFTER_REINSTALL
REINSTALL_TEST_LEVEL
REINSTALL_TEST_ID
```

## Core Rules

- Component communication uses real database links.
- `SOURCE_DB_LINK` never uses `LOCAL`, `NONE`, or `NULL`.
- AGENT and SHARED receive `SELECT ANY TABLE` and `ALTER ANY TABLE`.
- Destructive source cleanup and local REPLICA purge remain preview-first.

See [Installation](docs/installation.md), [Architecture](docs/architecture.md),
and [Operations](docs/operations.md).
