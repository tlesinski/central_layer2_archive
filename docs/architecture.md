# Architecture

## Components

### AGENT

AGENT is installed close to source business schemas. It exposes:

- `VW_AGENT_PARTITION_INFO` for partition and subpartition metadata.
- `PKG_AGENT_ARCHIVE.fn_get_row_count` for controlled source counts.
- `PKG_AGENT_ARCHIVE.prc_cleanup_unit` for explicit preview/execute cleanup.
- `PKG_AGENT_ARCHIVE.fn_health_check`.

AGENT contains no retention, archive eligibility, quality, or orchestration policy.

### ARCHIVER

ARCHIVER is the central Layer 2 control plane. Its source identity is:

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME
```

Primary metadata:

```text
TBL_ARCHIVER_TABLES
TBL_ARCHIVER_PARTITIONS
TBL_ARCHIVER_RUNS
TBL_ARCHIVER_PROCESS_LOG
```

The ARCHIVER runner executes:

```text
DISCOVER -> ARCHIVE -> QUALITY -> TRUNCATE
```

DISCOVER reads AGENT metadata through a real database link. ARCHIVE loads local
staging tables and exchanges partitions into ARCHIVER targets. QUALITY compares
source and target counts. TRUNCATE calls AGENT only for qualified units and
defaults to preview.

ARCHIVER configuration stores `PARTITION_METHOD` (`RANGE` or `LIST`) and an
optional `SUBPARTITION_METHOD` (`LIST`). AGENT exposes source key columns,
methods, and dictionary data types; discovery validates them against the target.
Raw Oracle `HIGH_VALUE` expressions drive target DDL and load predicates:

```text
RANGE -> key >= previous HIGH_VALUE and key < HIGH_VALUE
LIST  -> key IN (HIGH_VALUE)
```

`IMPORT_EXPRESSION` and `TRUNCATE_EXPRESSION` determine eligibility.
Multi-column partition keys are outside the supported operational set.
Technical or boundary units such as `P_ERROR`, `MAXVALUE`, `DEFAULT`, and LIST
`NULL` are not hardcoded exclusions. Administrators register them in
`TBL_ARCHIVER_PARTITIONS` with completed statuses so discovery treats them as
already processed.

### REPLICA

REPLICA is an independent Layer 3 component. Primary metadata:

```text
TBL_REPLICA_TABLES
TBL_REPLICA_PARTITIONS
TBL_REPLICA_RUNS
TBL_REPLICA_PROCESS_LOG
```

The REPLICA runner executes:

```text
DISCOVER -> REPLICATE -> QUALITY -> PURGE
```

REPLICA reads qualified ARCHIVER metadata dynamically in
`VW_REPLICA_SOURCE_PARTITIONS`. Each configuration row queries
`TBL_ARCHIVER_PARTITIONS@SOURCE_DB_LINK`, so one REPLICA can consume multiple
ARCHIVER databases without synonyms. Physical ARCHIVER targets use the same
per-row database link. PURGE operates only on local REPLICA targets and defaults
to preview.

REPLICA supports single-column `RANGE` and `LIST` partitioning with optional
single-column `LIST` subpartitioning. It validates methods, key names, and key
types between the remote ARCHIVER table and local REPLICA target. Raw
`HIGH_VALUE` expressions generate RANGE and LIST predicates for REPLICATE and
QUALITY.

`REPLICATE_EXPRESSION` is the desired-presence rule. `Y` selects pending units
for REPLICATE. `N` selects already replicated and qualified units for PURGE.
`ERROR: ...` selects neither path. Technical units are controlled through
completed `TBL_REPLICA_PARTITIONS` metadata rather than hardcoded names or
values.

## Topologies

### Combined

The `SHARED` model installs AGENT, ARCHIVER, and REPLICA in one configurable
schema on the source database. Logical
component boundaries are still crossed through two distinct loopback links:

```text
ARCHIVER -> AGENT
REPLICA  -> ARCHIVER
```

### Distributed

The `SPLIT` model installs AGENT on the source database, ARCHIVER on the archive
database, and REPLICA on the replica database. CLIENT1 and CLIENT2 are located
beside AGENT. Three SYS connections manage schema lifecycle for the source,
ARCHIVER, and REPLICA locations.

## Data and Safety Rules

- `SOURCE_DB_LINK` is real and non-null in component configuration and run data.
- `LOCAL` and `NONE` are invalid source-link values.
- Partition identity is based on high values, not only physical names.
- ARCHIVER supports RANGE, RANGE-LIST, LIST, LIST-LIST, INTERVAL, and
  INTERVAL-LIST for single-column keys.
- ARCHIVER and REPLICA support RANGE, RANGE-LIST, LIST, and LIST-LIST targets
  and use local staging plus partition exchange.
- Generated object names are validated before dynamic SQL execution.
- Destructive operations require an explicit execute switch.
- Component tables use `TBL_`; component views use `VW_`.
