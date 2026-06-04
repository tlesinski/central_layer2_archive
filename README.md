# PARTMGR Oracle Archive Control Plane

This repository implements three independently installable Oracle components:

- **AGENT** exposes controlled source metadata, row-count, and cleanup operations.
- **ARCHIVER** owns central archive configuration, orchestration, quality, and source cleanup eligibility.
- **REPLICA** maintains a bounded local copy of qualified ARCHIVER data.

The application schema name is configurable. `PARTMGR` is the production-style
default, not a hardcoded requirement. The same schema name may be used on
different databases. Components may also coexist in one schema on one database.

## Core Rules

- Component communication always uses real database links.
- `SOURCE_DB_LINK` is `NOT NULL` and never uses `LOCAL` or `NONE`.
- Tables use the `TBL_` prefix and views use the `VW_` prefix.
- Packages are component-specific: `PKG_AGENT_*`, `PKG_ARCHIVER_*`, `PKG_REPLICA_*`.
- ARCHIVER source truncate and REPLICA purge default to preview mode.
- AGENT does not decide archive policy.
- REPLICA reads ARCHIVER metadata and data but never modifies ARCHIVER.

## Repository Layout

```text
layer1_agent/       AGENT objects
layer2_core/        ARCHIVER objects
layer3_replica/     REPLICA objects
deploy/config/      committed templates and ignored local configuration
deploy/provision/   configurable schema provisioning
deploy/layer1/      standalone AGENT installation and smoke
deploy/layer2/      standalone ARCHIVER installation and smoke
deploy/layer3/      standalone REPLICA installation and smoke
deploy/combined/    single-schema combined topology
deploy/distributed/ multi-database topology and local simulation
deploy/onboarding/  source onboarding templates
docs/               architecture, installation, operations, validation
```

## Naming

Representative objects:

```text
VW_AGENT_PARTITION_INFO
PKG_AGENT_ARCHIVE

TBL_ARCHIVER_TABLES
TBL_ARCHIVER_PARTITIONS
TBL_ARCHIVER_RUNS
TBL_ARCHIVER_PROCESS_LOG
VW_ARCHIVER_DISCOVERY_PARTITIONS
PKG_ARCHIVER_RUNNER

TBL_REPLICA_TABLES
TBL_REPLICA_PARTITIONS
TBL_REPLICA_RUNS
TBL_REPLICA_PROCESS_LOG
VW_REPLICA_REPLICATE_PARTITIONS
PKG_REPLICA_RUNNER
```

## Quick Start: Combined Topology

Create local configuration from the committed templates, then run:

```text
@drop_all_schemas.sql
@full_reinstall.sql
@deploy/smoke_all.sql
```

`drop_all_schemas.sql` removes objects from the configured application schema,
not the schema account itself. `full_reinstall.sql` installs AGENT, ARCHIVER,
and REPLICA together and creates configured loopback database links.

Expected smoke markers:

```text
REPLICA_SMOKE_OK
COMBINED_SMOKE_OK
```

## Quick Start: Distributed Topology

Create:

```text
deploy/config/distributed_topology.local.sql
deploy/config/distributed_agents.local.sql
```

Then run:

```text
@deploy/distributed/deploy_distributed.sql
```

For the included local multi-schema simulation:

```text
@deploy/distributed/prepare_smoke.sql
@deploy/distributed/smoke_distributed.sql
```

Expected marker:

```text
DISTRIBUTED_SMOKE_OK
```

## Standalone Installers

```text
@deploy/layer1/install_agent.sql <agent-connect>
@deploy/layer2/install_archiver.sql
@deploy/layer3/install_replica.sql
```

Each component owns its utilities, logging, metadata, and sequences. Standalone
installation does not require local installation of either other component.

## Further Reading

- [Architecture](docs/architecture.md)
- [Installation](docs/installation.md)
- [Operations](docs/operations.md)
- [Stage Acceptance](docs/stage_acceptance.md)
