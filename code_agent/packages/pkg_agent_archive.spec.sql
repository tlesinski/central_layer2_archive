CREATE OR REPLACE PACKAGE PKG_AGENT_ARCHIVE
AS
  /*
    Package      : PKG_AGENT_ARCHIVE
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Layer 1 archive agent - exposes partition info, row count,
                   cleanup unit, and health check operations

    Prerequisite : TYPE_AGENT_PARTITION_INFO_OBJ, TYPE_AGENT_PARTITION_INFO_TAB

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_get_partition_info
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  RETURN TYPE_AGENT_PARTITION_INFO_TAB PIPELINED;

  FUNCTION fn_get_row_count
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL
  )
  RETURN NUMBER;

  PROCEDURE prc_cleanup_unit
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL,
    p_mode              IN VARCHAR2 DEFAULT 'TRUNCATE',
    p_execute           IN VARCHAR2 DEFAULT 'N'
  );

  FUNCTION fn_health_check
  RETURN VARCHAR2;
END PKG_AGENT_ARCHIVE;
/
