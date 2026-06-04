SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ============================================================
PROMPT Provisioning configured application schemas
PROMPT ============================================================

@deploy/config/install_config.local.sql
DEFINE PROVISION_ACTION_SCRIPT = deploy/provision/provision_target.sql
@&&PROVISION_TARGET_MANIFEST

PROMPT Application schema provisioning completed successfully
