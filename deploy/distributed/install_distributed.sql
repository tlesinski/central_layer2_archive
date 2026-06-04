SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

@deploy/distributed/install_agents.sql
SET DEFINE ON
@deploy/distributed/install_archiver.sql
SET DEFINE ON
@deploy/distributed/install_replica.sql

PROMPT Distributed topology installation completed
