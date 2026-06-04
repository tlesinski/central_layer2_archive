SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

@deploy/config/install_config.local.sql

PROMPT Connecting to configured combined application schema
CONNECT &&APPLICATION_SCHEMA/"&&APPLICATION_PASSWORD"@&&COMBINED_CONNECT

@deploy/combined/reset_combined_objects.sql

PROMPT Configured combined application objects dropped
