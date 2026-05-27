SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Installing Central Archive layer 1 agent objects

@@../../layer1_agent/types/archive_partition_info_obj.sql
@@../../layer1_agent/types/archive_partition_info_tab.sql
@@../../layer1_agent/views/archive_partition_info_vw.sql
@@../../layer1_agent/packages/pkg_archive_agent.spec.sql
@@../../layer1_agent/packages/pkg_archive_agent.body.sql

SHOW ERRORS PACKAGE PKG_ARCHIVE_AGENT
SHOW ERRORS PACKAGE BODY PKG_ARCHIVE_AGENT

PROMPT Central Archive layer 1 agent install completed
