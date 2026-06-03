# Central Layer 2 Archive

Central Layer 2 Archive is the next architecture for the Oracle archiver. The
goal is to move archive control, orchestration, metadata, status tracking, and
quality decisions into layer 2, while layer 1 exposes only a controlled helper
agent for source-side operations.

The existing `old_archiver` project proves the current `TWP -> TWARP` flow, but
it is single-source by design. This repository should keep the useful Oracle
techniques from that project without copying its hardcoded source model.

## Architecture Direction

Target split:

```text
Layer 2 = control plane + processing engine + central metadata
Layer 1 = source data + controlled helper agent
```

Layer 2 decides:

```text
- which sources are enabled
- which tables are in archive scope
- which partitions or subpartitions are candidates
- when archive import runs
- whether quality checks passed
- whether source truncation can be requested on layer 1
```

Layer 1 only provides technical metadata and executes explicit requests from
layer 2.

## Repository Layout

```text
full_reinstall.sql                          root-level full reinstall script

docs/
  central_layer2_archive_architecture.md
  central_layer3_replica_architecture.md

deploy/
  test_support/
    dat.spec.sql
    dat.body.sql

layer1_agent/
  types/
    archive_partition_info_obj.sql
    archive_partition_info_tab.sql
  packages/
    pkg_archive_agent.spec.sql
    pkg_archive_agent.body.sql
    pkg_sql.reference.spec.sql
    pkg_sql.reference.body.sql

layer2_core/
  sequences/
    md_process_log_seq.sql
    stg_tmp_arch_seq.sql
  tables/
    md_process_log.sql
    tw_archive_tables.sql
    tw_archive_runs.sql
    tw_archive_partitions.sql
  functions/
    fn_archive_high_value_date.sql
    fn_calculate_retention_rule.sql
    fn_validate_preserve_rule.sql
  triggers/
    trg_archive_tables_retention_calc.sql
    trg_archive_tables_preserve_calc.sql
  views/
    tw_archive_source_partitions_vw.sql
    tw_archive_discovery_partitions_vw.sql
    tw_archive_import_partitions_vw.sql
    tw_archive_quality_partitions_vw.sql
    tw_archive_truncate_partitions_vw.sql
  packages/
    pkg_sql.spec.sql / body.sql
    pkg_tl_logging.spec.sql / body.sql
    pkg_archive_log.spec.sql / body.sql
    pkg_archive_partition.spec.sql / body.sql
    pkg_archive_discovery.spec.sql / body.sql
    pkg_archive_import.spec.sql / body.sql
    pkg_archive_quality.spec.sql / body.sql
    pkg_archive_truncate.spec.sql / body.sql
    pkg_archive_runner.spec.sql / body.sql

layer3_replica/
  sequences/
    stg_tmp_replica_seq.sql
  tables/
    tw_replica_tables.sql
    tw_replica_runs.sql
    tw_replica_partitions.sql
  views/
    tw_replica_source_partitions_vw.sql
    tw_replica_discovery_partitions_vw.sql
    tw_replica_replicate_partitions_vw.sql
    tw_replica_quality_partitions_vw.sql
    tw_replica_purge_partitions_vw.sql
  packages/
    pkg_replica_partition.spec.sql / body.sql
    pkg_replica_discovery.spec.sql / body.sql
    pkg_replica_replicate.spec.sql / body.sql
    pkg_replica_quality.spec.sql / body.sql
    pkg_replica_purge.spec.sql / body.sql
    pkg_replica_runner.spec.sql / body.sql

deploy/
  smoke_all.sql                            full local smoke suite
  drop_all_schemas.sql                     schema-level drop script (root)
  client1/
    install_client1_test_source.sql
    install_client1_subpart_test_source.sql
    install_client1_daily_interval_test_source.sql
    grant_client1_to_cagent1.sql
    grant_client1_subpart_to_cagent1.sql
    grant_client1_daily_interval_to_cagent1.sql
    grant_cleanup_admin_to_cagent1.sql
  client2/
    install_client2_test_source.sql
    install_client2_subpart_test_source.sql
    install_client2_daily_interval_test_source.sql
    grant_client2_to_cagent1.sql
    grant_client2_subpart_to_cagent1.sql
    grant_client2_daily_interval_to_cagent1.sql
  layer1/
    install_layer1_agent.sql
    grant_layer1_agent_to_carch.sql
  layer2/
    create_client1_loopback_link.sql
    install_layer2_core.sql
    install_orders_archive_target.sql
    install_orders_archive_target2.sql
    install_orders_subpart_archive_target.sql
    install_orders_subpart_archive_target2.sql
    install_orders_daily_interval_archive_target.sql
    install_orders_daily_interval_archive_target2.sql
    recreate_layer2_core.sql
    reset_client1_loopback_metadata.sql
    seed_client1_loopback.sql
    seed_client1_loopback_subpart.sql
    seed_client1_loopback_daily_interval.sql
    seed_client2_loopback.sql
    seed_client2_loopback_subpart.sql
    seed_client2_loopback_daily_interval.sql
    smoke_remote_client1_loopback.sql
    smoke_remote_flow_client1_loopback.sql
    smoke_truncate_preview_client1_loopback.sql
    smoke_runner_client1_loopback.sql
    smoke_runner_client1_loopback_subpart.sql
    smoke_runner_client1_loopback_exchange.sql
    smoke_runner_multisource.sql
    smoke_runner_multisource_subpart.sql
    smoke_runner_multisource_daily_interval.sql
  layer3/
    install_layer3_replica.sql
    recreate_layer3_replica.sql
    install_orders_replica_target.sql
    install_orders_subpart_replica_target.sql
    seed_carch_local_replica.sql
    seed_carch_local_replica_subpart.sql
    smoke_replica_discovery.sql
    smoke_replica_replicate.sql
    smoke_replica_quality.sql
    smoke_replica_purge_preview.sql
    smoke_replica_runner.sql
```

Current state:

```text
- architecture documented
- central layer 2 metadata tables present (TW_ARCHIVE_TABLES, TW_ARCHIVE_PARTITIONS, TW_ARCHIVE_RUNS)
- process logging (MD_PROCESS_LOG, PKG_TL_LOGGING)
- SQL helper package (PKG_SQL)
- layer 1 archive agent package (PKG_ARCHIVE_AGENT)
- layer 2 core packages: PKG_ARCHIVE_LOG, PKG_ARCHIVE_PARTITION,
  PKG_ARCHIVE_DISCOVERY, PKG_ARCHIVE_IMPORT, PKG_ARCHIVE_QUALITY,
  PKG_ARCHIVE_TRUNCATE, PKG_ARCHIVE_RUNNER
- layer 1 and layer 2 install scripts present
- remote-path loopback smoke tests present
- remote-path truncate preview smoke test present
- remote-path runner smoke test present (range and subpartition)
- multisource runner smoke tests present for CLIENT1 and CLIENT2
- daily interval source/target smoke coverage present
- active target uniqueness safeguards present
- full reinstall script (clean drop + full install, including CLIENT2 and CREPL)
- fake `DAT` package for local tests only; it is not part of the layer 2 core
- layer 3 replica metadata model and process candidate views present
- layer 3 packages present: PKG_REPLICA_LOG, PKG_REPLICA_DISCOVERY,
  PKG_REPLICA_PARTITION, PKG_REPLICA_REPLICATE, PKG_REPLICA_QUALITY,
  PKG_REPLICA_PURGE, PKG_REPLICA_RUNNER
- layer 3 local smoke scripts present for DISCOVER, REPLICATE, QUALITY, PURGE
  preview, and RUNNER
```

## Relationship To old_archiver

Use `old_archiver` as a source of proven implementation patterns, not as a
template to copy wholesale.

Good candidates to reuse or adapt:

```text
- PKG_SQL.fn_get_partition_info for dictionary HIGH_VALUE extraction
- PKG_TL_LOGGING and MD_PROCESS_LOG as the base process log
- TW_ARCHIVER discovery, target DDL, staging/import, exchange, index rebuild,
  and quality-check ideas
- TW_LOCAL_ARCHIVER truncate ideas, especially source cleanup only after quality success
```

Do not preserve the old architecture:

```text
- no hardcoded single source such as one fixed TWP database link
- no source identity based only on DB link name
- no central archive state owned by layer 1 snapshots
- no layer 1 decision-making about retention, eligibility, archive status, or
  truncate eligibility
- no direct dependency on drift-prone old views as the new source of truth
```

The current `old_archiver` stage B work around `TW_IMPORT_PARTITIONS_VW` and
`TW_ARCHIVER.import_partitions` belongs to the old flow. In this repository, the
equivalent import should be rebuilt around central layer 2 metadata.

## Planned Layer 2 Model

Minimal central model:

```text
TW_ARCHIVE_TABLES
TW_ARCHIVE_PARTITIONS
TW_ARCHIVE_RUNS
```

Current minimal model removes `TW_ARCHIVE_SOURCES`. `SOURCE_DB_LINK` lives
directly in `TW_ARCHIVE_TABLES` and is part of the natural primary key for a
source table setup.

`TW_ARCHIVE_TABLES` includes:

```text
PARALLEL_DEGREE    controls staging inserts and staging index builds
TABLESPACE_NAME    controls exchange staging table and index placement
TRUNCATE_MODE      enables or disables source cleanup requests
LAST_BUSINESS_DATE SQL expression used to calculate the current business date
DAYS_ONLINE        number of days kept online on the source before truncate
PRESERVE_RULE      optional SQL returning dates that must not be truncated
PRESERVE_CALC      validation result for PRESERVE_RULE
```

The current retention model is not a static `SYSDATE - N` rule. Layer 2 derives
truncate eligibility from business-date configuration and partition high values:

```text
cutoff_date = FN_ARCHIVE_HIGH_VALUE_DATE(LAST_BUSINESS_DATE) - DAYS_ONLINE
```

Local test installs provide a fake `DAT` package with `fn_eod`, `fn_boy`, and
`fn_eoy` so sample metadata can use business-date expressions. Production date
logic is expected to be provided outside the archiver core.

`TW_ARCHIVE_PARTITIONS` should represent both partitions and subpartitions using
an explicit `ARCHIVE_UNIT_TYPE` column. Parent partition status for
subpartitioned tables should be derived from child rows instead of stored as a
second operational truth.

Active table configuration is intentionally one-target-owner/table per active
archive table mapping. If multiple sources need one physical target in the
future, the target table must carry a source discriminator and the model should
make that sharing explicit instead of allowing accidental duplicate mappings.

Current safeguards:

```text
TW_ARCHIVE_TABLES_UK1
  blocks duplicate TARGET_OWNER/TARGET_TABLE_NAME mappings

TW_ARCHIVE_PARTITIONS_PK
  uses SOURCE_DB_LINK, SOURCE_OWNER, SOURCE_TABLE_NAME,
  PARTITION_HIGH_VALUE, SUBPARTITION_HIGH_VALUE as the logical source unit key

TW_ARCHIVE_PARTITIONS_UK1
  blocks duplicate target high-value metadata rows
```

Each process logs a per-unit summary in `MD_PROCESS_LOG` via
`PKG_ARCHIVE_LOG.prc_log_message` with the format
`table_owner|table_name|partition_name|subpartition_name|status`.

## Planned Layer 1 Agent

Layer 1 should expose a small package, for example `PKG_ARCHIVE_AGENT`, with a
contract like:

```sql
fn_get_partition_info(owner, table_name)
fn_get_row_count(owner, table_name, partition_name, subpartition_name)
prc_cleanup_unit(owner, table_name, partition_name, subpartition_name, mode)
fn_health_check
```

The agent should not contain archive policy. It must not decide which
partitions are eligible, whether quality passed, whether retention has elapsed,
or whether cleanup should run. Those decisions belong to layer 2.

## Implemented L1/L2 Flow

The current L1/L2 implementation contains the core flow below:

```text
1. Layer 1 exposes PKG_ARCHIVE_AGENT for partition metadata, row counts,
   and explicit cleanup requests.
2. Layer 2 owns TW_ARCHIVE_TABLES, TW_ARCHIVE_PARTITIONS, TW_ARCHIVE_RUNS,
   and MD_PROCESS_LOG.
3. DISCOVER reads source partition metadata through the layer 1 agent view
   and adds missing target partitions.
4. ARCHIVE imports eligible partitions/subpartitions into layer 2 target
   tables through staging and EXCHANGE.
5. QUALITY compares source and target row counts and updates QUALITY_STATUS.
6. TRUNCATE requests source cleanup through the layer 1 agent only after
   archive and quality success, business-date cutoff, and preserve checks.
7. RUNNER orchestrates DISCOVER -> ARCHIVE -> QUALITY -> TRUNCATE with
   preview/execute controls.
```

Every operational procedure should support preview and execute modes:

```sql
p_execute => 'N'
p_execute => 'Y'
```

## Design Rules

Use source identity explicitly in the table setup:

```text
SOURCE_DB_LINK + SOURCE_OWNER + SOURCE_TABLE_NAME = source table identity
```

Dynamic SQL is expected, but it should be centralized and validated:

```text
- validate owner, table, partition, and subpartition names
- log generated SQL
- support preview mode
- use controlled error handling
```

Staging objects should be traceable and cleaned:

```text
- include RUN_ID in generated staging names
- clean up in exception paths
- track staging objects if they can outlive a run
- provide orphan staging cleanup
```

## Deployment Status

This repository is not yet a complete archiver. It currently contains the
deployable core model, logging, central SQL helpers, and a minimal layer 1 agent.

Local development database layout used so far:

```text
CARCH    central layer 2 schema
CAGENT1  layer 1 agent schema
CLIENT1  sample client/source schema
CLIENT2  second sample client/source schema for multisource validation
CREPL    layer 3 replica schema
```

Installed smoke flow:

```text
CLIENT1.ORDERS_ARCH_SRC
  range-partitioned test source table

CLIENT1.ORDERS_SUBPART_SRC
  range-list subpartitioned test source table

CLIENT1.ORDERS_DAILY_INT_SRC
  daily interval test source table

CLIENT2.ORDERS_ARCH_SRC / ORDERS_SUBPART_SRC / ORDERS_DAILY_INT_SRC
  second source schema with matching structures and separate CARCH targets

CAGENT1.PKG_ARCHIVE_AGENT
  reads partition metadata and row counts from CLIENT1 and CLIENT2

CARCH.PKG_ARCHIVE_DISCOVERY
  opens one DISCOVER run and processes all configured source tables in that run
  can be narrowed to one target table with optional target owner/table parameters
  inserts rows into TW_ARCHIVE_PARTITIONS after each ALTER TABLE ADD PARTITION
  uses TW_ARCHIVE_SOURCE_PARTITIONS_VW and TW_ARCHIVE_DISCOVERY_PARTITIONS_VW over
  CAGENT1.ARCHIVE_PARTITION_INFO_VW so discovery works through DB links
  physically adds missing target partitions with ALTER TABLE ADD PARTITION
  ignores source MAXVALUE partitions

CARCH.PKG_ARCHIVE_IMPORT
  reads TW_ARCHIVE_IMPORT_PARTITIONS_VW and imports not-yet-archived source
  partitions and subpartitions into the target archive table with EXCHANGE
  opens one ARCHIVE run and can be narrowed to one target table with optional
  target owner/table parameters
  builds staging tables and staging indexes from the target local indexes
  uses date range predicates for remote DB links

CARCH.PKG_ARCHIVE_QUALITY
  reads TW_ARCHIVE_QUALITY_PARTITIONS_VW
  opens one QUALITY run and can be narrowed to one target table with optional
  target owner/table parameters
  reads source row counts through the layer 1 agent
  compares source and target row counts and sets QUALITY_STATUS

CARCH.PKG_ARCHIVE_TRUNCATE
  reads TW_ARCHIVE_TRUNCATE_PARTITIONS_VW
  opens one TRUNCATE run and can be narrowed to one target table with optional
  target owner/table parameters
  requests source truncate through the layer 1 agent only after quality success
  applies LAST_BUSINESS_DATE - DAYS_ONLINE cutoff before truncating source
  partitions/subpartitions
  respects optional PRESERVE_RULE dates that protect matching archive units

CARCH.PKG_ARCHIVE_RUNNER
  runs DISCOVER -> ARCHIVE -> QUALITY -> TRUNCATE with stop-after-step control
  and a separate truncate execute switch
```

Expected discovery smoke result:

```text
5 discovered partition rows for CLIENT1.ORDERS_ARCH_SRC
10 discovered subpartition rows for CLIENT1.ORDERS_SUBPART_SRC
daily interval source rows discovered for CLIENT1.ORDERS_DAILY_INT_SRC
matching CLIENT2 rows discovered into separate target tables
PMAX source partitions ignored
```

Expected import smoke result:

```text
4 archived partition rows for CLIENT1.ORDERS_ARCH_SRC
250 rows in CARCH.ORDERS_ARCH_SRC
8 archived subpartition rows for CLIENT1.ORDERS_SUBPART_SRC
360 rows in CARCH.ORDERS_SUBPART_SRC
96 rows in CARCH.ORDERS_DAILY_INT_SRC
same row-count expectations for CLIENT2 targets:
  CARCH.ORDERS_ARCH_SRC_2
  CARCH.ORDERS_SUBPART_SRC_2
  CARCH.ORDERS_DAILY_INT_SRC_2
TARGET_ROW_COUNT populated during archive
```

Expected quality smoke result:

```text
SOURCE_ROW_COUNT and TARGET_ROW_COUNT match for imported units
ARCHIVE_STATUS = Y
QUALITY_STATUS = Y
TRUNCATE_STATUS = N for archive units
P_ERROR has ARCHIVE_STATUS = Y, QUALITY_STATUS = Y, TRUNCATE_STATUS = Y
```

Remote-path loopback validation:

```text
CLIENT1_LOOPBACK_LINK connects CARCH to CAGENT1 through //localhost:1521/FREEPDB1
CLIENT1_LOOPBACK_LINK is stored as SOURCE_DB_LINK in TW_ARCHIVE_TABLES
DISCOVER -> ARCHIVE -> QUALITY passes through the DB link
TRUNCATE preview passes through the DB link without changing source data
RUNNER smoke executes through QUALITY with truncate disabled by default
```

Remote compatibility notes:

```text
- Pipelined functions returning user-defined object/table types are not used for
  remote discovery because Oracle raises ORA-30626 across DB links.
- Remote discovery reads CAGENT1.ARCHIVE_PARTITION_INFO_VW instead.
- Remote EXCHANGE staging load uses date range predicates derived from partition
  HIGH_VALUE because table partition syntax is not usable over DB links.
- TRUNCATE is destructive on the source side. Smoke truncate uses preview mode
  only unless execute mode is explicitly requested.
- TRUNCATE mode uses physical `ALTER TABLE ... TRUNCATE PARTITION` in the
  layer 1 agent. When the agent schema is not the table owner, Oracle requires a
  stronger source-side privilege model; the local smoke setup grants
  `DROP ANY TABLE` to CAGENT1 so truncate can execute through the DB link.
- DELETE cleanup is intentionally not part of the current layer 2 archive path.
```

## Layer 3 Direction

Layer 3 replica design is intentionally kept out of this README and captured in
`docs/central_layer3_replica_architecture.md`. The implemented foundation
contains the `TW_REPLICA_*` metadata tables, process candidate views, local
`CREPL` smoke target tables, seed metadata, EXCHANGE-based replication, quality,
purge preview, and runner smoke coverage.

## Quick Reinstall

Connect as SYS and run in sequence:

```text
1. @drop_all_schemas.sql
2. @full_reinstall.sql
```

Verify success:

```text
- all SHOW ERRORS = "No errors"
- seed TW_ARCHIVE_TABLES = 1 row merged per source table setup
- seed TW_ARCHIVE_PARTITIONS = N rows merged per target table setup
- CLIENT1 and CLIENT2 source schemas installed
- CREPL layer 3 replica schema installed and seeded
- DB link test: SELECT * FROM dual@CLIENT1_LOOPBACK_LINK → returns X
```

## Recommended Smoke Path

After a clean reinstall, run the full smoke suite:

```text
1. @drop_all_schemas.sql
2. @full_reinstall.sql
3. @deploy/smoke_all.sql
```

`deploy/smoke_all.sql` runs the L2 range, multisource range, multisource
subpartition, multisource daily interval, truncate preview, and L3 replica
runner smoke tests. It also asserts the expected target row counts, checks that
L3 has no remaining discovery/replicate/quality candidates, and verifies that
the smoke schemas have no invalid objects.

On Windows SQL*Plus, `ORA-12638` usually means the local Oracle client is trying
NTS authentication. For a single session, point `TNS_ADMIN` at a directory with
this `sqlnet.ora`, or fix the local Oracle client configuration:

```text
SQLNET.AUTHENTICATION_SERVICES = (NONE)
```
