# PARTMGR Oracle Archive Control Plane

## Overview

PARTMGR is an Oracle partition archive control plane for distributed,
partitioned data estates. It coordinates source discovery, archive loading,
quality checks, source truncate eligibility, bounded downstream replication,
and operational reporting.

The system is split into three logical components:

- **AGENT**: source-side helper for controlled metadata, row counts, and cleanup.
- **ARCHIVER**: central archive orchestrator and quality control plane.
- **REPLICA**: downstream replica of qualified ARCHIVER data.

PARTMGR is designed to keep source schemas small and policy-free. Source
databases expose controlled helper operations through AGENT, while ARCHIVER and
REPLICA own orchestration, status tracking, quality checks, and preview-first
cleanup decisions.

## Problem It Solves

Large Oracle systems often need to move old partitions out of source schemas
without embedding archive policy in every source application. PARTMGR provides a
centralized, database-native way to:

- discover partition and subpartition metadata through real database links,
- archive qualified source units into centrally managed partitioned targets,
- compare source and target row counts before cleanup,
- decide source truncate eligibility without making source cleanup automatic,
- replicate archived data into a bounded downstream schema,
- report recent processing status with mail-ready summaries and process details.

The design avoids hardcoded source assumptions. A configured source is identified
by:

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME
```

`SOURCE_DB_LINK` must always be a real database link. Special values such as
`LOCAL`, `NONE`, or `NULL` are intentionally invalid.

## Architecture At A Glance

The high-level data flow is:

```text
CLIENT tables -> AGENT -> ARCHIVER -> REPLICA
```

ARCHIVER processing:

```text
DISCOVER -> ARCHIVE -> QUALITY -> TRUNCATE preview
```

REPLICA processing:

```text
DISCOVER -> REPLICATE -> QUALITY -> PURGE preview
```

AGENT is installed close to source business schemas. It exposes partition
metadata, controlled row counts, health checks, and explicit cleanup preview or
execution routines. AGENT does not decide retention, archive eligibility, or
quality status.

ARCHIVER reads AGENT metadata through a real DB link, loads archive targets,
tracks each archive unit, compares row counts, and identifies source truncate
candidates. Source truncate remains preview-first.

REPLICA reads qualified ARCHIVER metadata and physical archive targets through a
real DB link, loads replica targets, performs quality checks, and identifies
local purge candidates. REPLICA purge remains preview-first.

## Code Layout

```text
*.sql           root-level configuration and installation entry points
code_root/      low-level schema and database-link helpers
code_agent/     AGENT database objects
code_archiver/  ARCHIVER database objects
code_replica/   REPLICA database objects
seed/           optional demo data and mail metadata seeds
tests/          independent smoke tests
docs/           detailed architecture, installation, and operations notes
```

## Installation Models

`SHARED` installs AGENT, ARCHIVER, and REPLICA in one configured schema on the
source database. It is useful for local development, smoke tests, and
single-database validation. Logical component boundaries still use configured
loopback DB links.

`SPLIT` installs components independently:

```text
AGENT    -> source database
ARCHIVER -> archive database
REPLICA  -> replica database
```

This is the production-like topology. CLIENT schemas and AGENT are managed
through `SOURCE_SYS_CONNECT`; ARCHIVER and REPLICA can be managed through their
own SYS connections.

Schema names are configurable in `config.local.sql`. Names such as
`PARTMGR_AGENT`, `PARTMGR_ARCHIVER`, `PARTMGR_REPLICA`, and `PARTMGR_SHARED`
are defaults, not hard requirements.

## Installation

Copy and edit the local configuration:

```text
config.template.sql -> config.local.sql
```

To destructively recreate all six configured schemas, explicitly set:

```text
RESET_CONFIRMATION = RESET_ALL
```

Then open `reinstall.sql` in SQL Developer and run it as a script, or run reset
and installation separately:

```text
@reinstall.sql

@reset_schemas.sql
@install_code.sql
```

By default, reset and installation do not create demo business tables, archive
targets, replica targets, metadata seeds, or test data.

## Demo Seeds

Demo sources, targets, and metadata are managed separately by `seed.sql`.
Configure seed flags in `config.local.sql`:

```text
RUN_SEEDS_AFTER_REINSTALL
REBUILD_SEED_CLIENT
REBUILD_SEED_ARCHIVER
REBUILD_SEED_REPLICA
REBUILD_SEED_MAIL
```

Seed cascade is top-down:

```text
CLIENT   -> CLIENT + ARCHIVER + REPLICA
ARCHIVER -> ARCHIVER + REPLICA
REPLICA  -> REPLICA only
MAIL     -> mail metadata only
```

Run manually with:

```text
@seed.sql
```

Each seeded client receives RANGE, RANGE-LIST, and daily INTERVAL-LIST source
tables. Daily interval partitions are normalized to `PYYYYMMDD` names.

`REBUILD_SEED_MAIL` updates application mail settings in `TBL_UTIL_CONFIG`.
Oracle network ACLs are not a seed; they are SYS-level infrastructure managed by
`configure_mail_acl.sql`.

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

## Reports And Mail

`PKG_UTIL_MAIL` sends through plain SMTP. For local development, run `smtp4dev`
on `localhost:2525`, set `CONFIGURE_MAIL_ACL=Y` to grant Oracle network ACLs,
and set `REBUILD_SEED_MAIL=Y` with the desired `MAIL_*` values to update
`TBL_UTIL_CONFIG`. Mail remains disabled by default.

The standard component reports are:

```text
ARCHIVER_SUMMARY
REPLICA_SUMMARY
```

These reports are code metadata installed with ARCHIVER and REPLICA, not demo
seeds. The main mail body is intentionally lightweight. Full latest process
summaries are attached as separate HTML files, one attachment per process.

Reporting settings in `TBL_UTIL_CONFIG`:

```text
REPORT_LOOKBACK_DAYS       default 7
REPORT_SUMMARY_MAX_CHARS   default 4000 per process
REPORT_MAX_ROWS            default 100
```

Send reports with:

```sql
BEGIN
  PKG_UTIL_MAIL.prc_send_report('ARCHIVER_SUMMARY');
  PKG_UTIL_MAIL.prc_send_report('REPLICA_SUMMARY');
END;
/
```

## Operational Safety

- Component communication uses real Oracle database links.
- `SOURCE_DB_LINK` never uses `LOCAL`, `NONE`, or `NULL`.
- Source truncate and local replica purge are preview-first.
- `RESET_CONFIRMATION=RESET_ALL` is required before schema reset drops users.
- Code installation, demo seeds, tests, mail metadata, and ACL setup are separate
  steps.
- AGENT and SHARED receive `SELECT ANY TABLE` and `ALTER ANY TABLE` by design.
- ARCHIVER and REPLICA track process runs, detailed process logs, partition
  statuses, row counts, and latest summary logs.

## Documentation Links

- [Installation](docs/installation.md)
- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
