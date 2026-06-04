SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON

PROMPT Installing standalone AGENT objects

@layer1_agent/types/agent_partition_info_obj.sql
@layer1_agent/types/agent_partition_info_tab.sql
@layer1_agent/views/vw_agent_partition_info.sql
@layer1_agent/packages/pkg_agent_archive.spec.sql
@layer1_agent/packages/pkg_agent_archive.body.sql

SHOW ERRORS TYPE AGENT_PARTITION_INFO_OBJ
SHOW ERRORS TYPE AGENT_PARTITION_INFO_TAB
SHOW ERRORS VIEW VW_AGENT_PARTITION_INFO
SHOW ERRORS PACKAGE PKG_AGENT_ARCHIVE
SHOW ERRORS PACKAGE BODY PKG_AGENT_ARCHIVE

PROMPT Standalone AGENT install completed
