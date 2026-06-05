# Demo Seeds

Run the configured seed cascade from the repository root:

```sql
@seed.sql
```

The cascade is controlled by `REBUILD_SEED_CLIENT`, `REBUILD_SEED_ARCHIVER`,
`REBUILD_SEED_REPLICA`, and `REBUILD_SEED_MAIL` in `config.local.sql`.

CLIENT rebuild automatically includes ARCHIVER and REPLICA. ARCHIVER rebuild
automatically includes REPLICA. REPLICA rebuilds only REPLICA.

MAIL is independent from the data cascade. It updates only `TBL_UTIL_CONFIG`
mail rows in active utility schemas and does not recreate reports, logs,
component metadata, or business objects.

Each module destructively recreates only its owned demo tables, metadata, and
related runs. Component code, schemas, database links, sequences, process logs,
and unrelated metadata are preserved.

Each client receives three source patterns:

```text
ORDERS_ARCH_SRC       RANGE
ORDERS_SUBPART_SRC    RANGE-LIST
ORDERS_DAILY_INT_SRC  daily INTERVAL-LIST with PYYYYMMDD partition names
```
