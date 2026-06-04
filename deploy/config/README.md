# Installation Configuration

Local configuration files may contain credentials and are ignored by Git.

## Combined and Standalone

Copy:

```text
install_config.template.sql -> install_config.local.sql
agent_instances.template.sql -> agent_instances.local.sql
provision_targets.template.sql -> provision_targets.local.sql
```

`install_config.local.sql` defines the configurable application schema,
password, tablespaces, component locations, enabled components, and combined
loopback DB-link names.

Validate:

```text
@deploy/config/validate_install_config.sql
```

Provision:

```text
@deploy/provision/provision_all_schemas.sql
```

## Distributed

Copy:

```text
distributed_topology.template.sql -> distributed_topology.local.sql
distributed_agents.template.sql -> distributed_agents.local.sql
```

The topology file defines ARCHIVER and REPLICA locations and credentials. The
agent manifest defines any number of AGENT locations. Each location includes
its own application schema, application password, admin account, admin
password, role, and DB-link name.

Provision and install:

```text
@deploy/distributed/deploy_distributed.sql
```
