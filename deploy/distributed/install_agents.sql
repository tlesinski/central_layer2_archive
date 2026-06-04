SET DEFINE ON
@deploy/config/distributed_topology.local.sql
DEFINE DISTRIBUTED_AGENT_ACTION = deploy/distributed/install_agent_instance.sql
@&&DISTRIBUTED_AGENT_MANIFEST
