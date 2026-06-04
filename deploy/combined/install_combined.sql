SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

@deploy/config/install_config.local.sql

PROMPT Connecting to configured combined database
CONNECT &&APPLICATION_SCHEMA/"&&APPLICATION_PASSWORD"@&&COMBINED_CONNECT

SET DEFINE OFF
@deploy/layer1/install_layer1_agent.sql

SET DEFINE ON
@deploy/layer2/create_agent_db_link.sql &&COMBINED_AGENT_DB_LINK &&COMBINED_CONNECT

SET DEFINE OFF
@deploy/layer2/install_layer2_core.sql
@deploy/layer2/install_archiver_orders_target.sql

SET DEFINE ON
@deploy/layer2/seed_archiver_orders.sql &&COMBINED_AGENT_DB_LINK
@deploy/layer3/create_archiver_source.sql &&COMBINED_ARCHIVER_DB_LINK &&COMBINED_CONNECT

SET DEFINE OFF
@deploy/layer3/install_layer3_replica.sql
@deploy/layer3/install_replica_orders_target.sql

SET DEFINE ON
@deploy/layer3/seed_replica_orders.sql &&COMBINED_ARCHIVER_DB_LINK

PROMPT Combined AGENT, ARCHIVER, and REPLICA installation completed
