# Repository Instructions

This repository contains the new central layer 2 Oracle archiver design. Treat it
as a new architecture, not as a direct copy of `old_archiver`.

## Primary Goal

Build a central layer 2 archive control plane that can manage many layer 1
sources. Layer 2 owns configuration, orchestration, statuses, quality checks,
and source truncate eligibility. Layer 1 exposes only controlled helper
operations.

## Required Reading

Before making changes, read:

```text
README.md
docs/architecture.md
```

When borrowing from the older repository, inspect the relevant `old_archiver`
object before adapting it. Do not assume the repo export exactly matches the
database state.

## Relationship To old_archiver

The old project is useful as implementation reference for:

```text
- partition HIGH_VALUE extraction
- dynamic partition DDL
- staging/import/exchange patterns
- index rebuild patterns
- quality count checks
- process logging
- source truncate mechanics
```

Avoid copying old design constraints:

```text
- fixed TWP/TWARP source assumptions
- hardcoded DB links
- hardcoded business table exceptions
- layer 1 archive decision-making
- status derived from old snapshot materialized views
- dependency on drift-prone old identify/import views as the new source of truth
```

## Project Boundaries

Keep files organized by deployment side:

```text
layer1_agent/   source-side helper objects
layer2_core/    central layer 2 objects
deploy/layer1/  layer 1 install scripts
deploy/layer2/  layer 2 install scripts
docs/           architecture and operational notes
```

Do not place layer 2 orchestration logic in `layer1_agent`.

## SQL Style

Prefer explicit, deployable SQL scripts:

```text
- one object per file where practical
- schema-qualified object names only when the target schema is intentional
- deterministic install order in deploy scripts
- no hidden table creation from package initialization for core deploy objects
```

For PL/SQL:

```text
- keep public package specs small and intentional
- validate dynamic object names
- use bind variables for values
- log generated dynamic SQL where useful
- include preview/execute behavior for operational routines
- place header comments (`/* ... */`) inside the PL/SQL block (after AS)
  so they appear in user_source / dba_source in the database
```

Use `VARCHAR2(128)` for Oracle object names unless there is a specific reason
not to.

## Windows SQL\*Plus

```text
- @@../../ relative paths fail with SP2-0310 — use @ with paths from repo root
- In PowerShell, escape the @ operator with backtick: `@path/to/file.sql
  (or use the call operator: & sqlplus ... `@script.sql)
```

## Central Model Rules

Layer 2 metadata uses the source database link directly in table configuration:

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME = source table setup key
```

Do not reintroduce `removed source registry table`, surrogate archive ids, or
`ARCHIVE_METHOD` unless the data model is intentionally redesigned.

`TBL_ARCHIVER_PARTITIONS` should support both partitions and subpartitions through
`ARCHIVE_UNIT_TYPE`. Its identity is based on partition and subpartition
`HIGH_VALUE`, not physical names. Do not maintain parent partition status as a
separate operational truth when child subpartition rows already define the state.

## Safety Rules

Do not revert unrelated changes in this repository.

Do not edit generated exports from `old_archiver` while working in this repo
unless the user explicitly asks for that.

Do not add deployment scripts that run destructive source truncate by default.
Truncate and import procedures should expose preview mode first.

## Verification

For structural changes, check:

```text
- file layout remains consistent
- deploy scripts reference existing files in the right order
- package specs and bodies compile together conceptually
- README and architecture docs stay aligned
```

For database-facing changes, prefer adding a clear install or smoke-test script
over relying on manual execution order.

## Reinstall (Clean Drop + Full Install)

Connect as SYS and run in order:

```text
1. @drop_all_schemas.sql
2. @full_reinstall.sql
```

Step 1 drops all component objects from the configured application schema. Step
2 recreates the combined topology and seeds metadata. Verify with:

```text
- all SHOW ERRORS = "No errors"
- seed TBL_ARCHIVER_TABLES = 1 row merged per table
- seed TBL_ARCHIVER_PARTITIONS = N rows merged per table
- combined smoke test completes successfully
- configured component DB links are valid
```
