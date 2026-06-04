# Installation

Run SQL*Plus scripts from the repository root.

## Configuration

Copy committed templates to ignored local files:

```text
deploy/config/install_config.template.sql
  -> deploy/config/install_config.local.sql

deploy/config/agent_instances.template.sql
  -> deploy/config/agent_instances.local.sql

deploy/config/provision_targets.template.sql
  -> deploy/config/provision_targets.local.sql

deploy/config/distributed_topology.template.sql
  -> deploy/config/distributed_topology.local.sql

deploy/config/distributed_agents.template.sql
  -> deploy/config/distributed_agents.local.sql
```

Validate combined and standalone configuration:

```text
@deploy/config/validate_install_config.sql
```

## Schema Provisioning

The application schema must be provisioned before component installation.
Provisioning grants the common AGENT/ARCHIVER/REPLICA privilege superset and
fails if the schema already exists.

Combined or shared-name database targets:

```text
@deploy/provision/provision_all_schemas.sql
```

Distributed topology:

```text
@deploy/distributed/provision_distributed.sql
```

## Standalone Components

```text
@deploy/layer1/install_agent.sql <agent-connect>
@deploy/layer2/install_archiver.sql
@deploy/layer3/install_replica.sql
```

ARCHIVER-to-AGENT and REPLICA-to-ARCHIVER communication must be configured
through real database links.

## Combined Installation

The configured schema must already exist:

```text
@drop_all_schemas.sql
@full_reinstall.sql
@deploy/smoke_all.sql
```

`drop_all_schemas.sql` removes application objects but preserves the schema
account and its privileges.

## Distributed Installation

The master entry point provisions all configured schemas, installs all AGENT
instances, installs ARCHIVER, creates ARCHIVER-to-AGENT links, installs REPLICA,
and creates the REPLICA-to-ARCHIVER link:

```text
@deploy/distributed/deploy_distributed.sql
```

Partial installation entry points:

```text
@deploy/distributed/install_agents.sql
@deploy/distributed/install_archiver.sql
@deploy/distributed/install_replica.sql
```

## Local Distributed Simulation

Separate schemas in one PDB can simulate separate databases:

```text
@deploy/distributed/reset_local_simulation.sql
@deploy/distributed/deploy_distributed.sql
@deploy/distributed/prepare_smoke.sql
@deploy/distributed/smoke_distributed.sql
```

Different local schema names are required because one PDB cannot contain
multiple users with the same name. Production databases may each use `PARTMGR`.

## Client Onboarding

Use the templates:

```text
deploy/onboarding/grant_source_table.template.sql
deploy/onboarding/seed_archiver_table.template.sql
```

Grant source `SELECT` to the AGENT schema. Grant source `ALTER` only when
executed source cleanup is required. Create the ARCHIVER target table and seed
`TBL_ARCHIVER_TABLES` with a real DB link.
