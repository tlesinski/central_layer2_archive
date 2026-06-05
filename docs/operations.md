# Operations

## Health and Validation

Check AGENT:

```sql
SELECT PKG_AGENT_ARCHIVE.fn_health_check FROM dual;
```

Check invalid objects:

```sql
SELECT object_name, object_type
FROM user_objects
WHERE status <> 'VALID';
```

Check configured source links:

```sql
SELECT source_db_link, source_owner, source_table_name
FROM TBL_ARCHIVER_TABLES;

SELECT source_db_link, source_owner, source_table_name
FROM TBL_REPLICA_TABLES;
```

Every listed source link must exist in `USER_DB_LINKS`.

## ARCHIVER Run

Run one configured source table:

```sql
BEGIN
  PKG_ARCHIVER_RUNNER.prc_run_table(
    p_source_db_link   => 'AGENT_01_LINK',
    p_owner            => 'CLIENT_SCHEMA',
    p_table_name       => 'SOURCE_TABLE',
    p_execute          => 'Y',
    p_stop_after_step  => 'TRUNCATE',
    p_truncate_execute => 'N'
  );
END;
/
```

Run all enabled sources:

```sql
BEGIN
  PKG_ARCHIVER_RUNNER.prc_run_all(
    p_execute          => 'Y',
    p_stop_after_step  => 'TRUNCATE',
    p_truncate_execute => 'N'
  );
END;
/
```

Keep `p_truncate_execute => 'N'` until preview output and quality results have
been reviewed.

## REPLICA Run

```sql
BEGIN
  PKG_REPLICA_RUNNER.prc_run(
    p_execute         => 'Y',
    p_stop_after_step => 'PURGE',
    p_purge_execute   => 'N'
  );
END;
/
```

Keep `p_purge_execute => 'N'` until purge candidates have been reviewed.

## Logs and Status

ARCHIVER:

```text
TBL_ARCHIVER_RUNS
TBL_ARCHIVER_PROCESS_LOG
TBL_ARCHIVER_PARTITIONS
```

REPLICA:

```text
TBL_REPLICA_RUNS
TBL_REPLICA_PROCESS_LOG
TBL_REPLICA_PARTITIONS
```

Use process views to inspect candidates before execution:

```text
VW_ARCHIVER_DISCOVERY_PARTITIONS
VW_ARCHIVER_IMPORT_PARTITIONS
VW_ARCHIVER_QUALITY_PARTITIONS
VW_ARCHIVER_TRUNCATE_PARTITIONS

VW_REPLICA_DISCOVERY_PARTITIONS
VW_REPLICA_REPLICATE_PARTITIONS
VW_REPLICA_QUALITY_PARTITIONS
VW_REPLICA_PURGE_PARTITIONS
```

## Deployment Boundary

Installation scripts install code only unless `RUN_SEEDS_AFTER_REINSTALL=Y`.
Demo tables, targets, and metadata are managed by the independent cascading
`seed.sql` entry point. Automated tests remain separate and are launched through
root-level `test.sql`.

Examples:

```text
@test.sql CLIENT ALL
@test.sql ARCHIVER 003
@test.sql REPLICA ALL
@test.sql ALL ALL
```

## Local Mail Reports

Start a local SMTP collector, for example `smtp4dev`, with SMTP exposed on
`localhost:2525` and its web UI on `localhost:8081`.

Grant Oracle network ACLs as SYS:

```text
@configure_mail_acl.sql
```

Update mail metadata with `REBUILD_SEED_MAIL=Y` and `@seed.sql`, then send a
report from ARCHIVER or REPLICA:

```sql
BEGIN
  PKG_UTIL_MAIL.prc_send_report('UTIL_SMOKE_REPORT');
END;
/
```

Keep `MAIL_ENABLED=N` unless report mail should be sent by that schema.

Standard weekly-style component summaries are available as:

```sql
BEGIN
  PKG_UTIL_MAIL.prc_send_report('ARCHIVER_SUMMARY');
  PKG_UTIL_MAIL.prc_send_report('REPLICA_SUMMARY');
END;
/
```

The reporting window is controlled by `TBL_UTIL_CONFIG.REPORT_LOOKBACK_DAYS`
and defaults to `7`. Latest process summary excerpts are limited by
`TBL_UTIL_CONFIG.REPORT_SUMMARY_MAX_CHARS` and default to `4000` per process.
