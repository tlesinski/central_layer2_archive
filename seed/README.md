# Demo Seeds

Run the configured seed cascade from the repository root:

```sql
@seed.sql
```

The cascade is controlled by `REBUILD_SEED_CLIENT`, `REBUILD_SEED_ARCHIVER`,
and `REBUILD_SEED_REPLICA` in `config.local.sql`.

ARCHIVER rebuild automatically includes CLIENT. REPLICA rebuild automatically
includes CLIENT and ARCHIVER.

Each module destructively recreates only its owned demo tables, metadata, and
related runs. Component code, schemas, database links, sequences, process logs,
and unrelated metadata are preserved.

Each client receives three source patterns:

```text
ORDERS_ARCH_SRC       RANGE
ORDERS_SUBPART_SRC    RANGE-LIST
ORDERS_DAILY_INT_SRC  daily INTERVAL-LIST with PYYYYMMDD partition names
```
