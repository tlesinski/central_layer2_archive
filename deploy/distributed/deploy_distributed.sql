SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Provisioning distributed topology
@deploy/distributed/provision_distributed.sql

SET DEFINE ON
PROMPT Installing distributed topology
@deploy/distributed/install_distributed.sql

PROMPT Distributed topology deployment completed
