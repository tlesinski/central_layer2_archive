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
    1.1        2026-10-11   Tomasz Lesinski    Use HIGH_VALUE-based FOR selectors
                                                for counts and source cleanup
  */
  -- Returns partition and subpartition metadata for a source table.
  -- Parameters:
  -- p_owner      schema owning the source table
  -- p_table_name source table name
  FUNCTION fn_get_partition_info
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  RETURN TYPE_AGENT_PARTITION_INFO_TAB PIPELINED;

  -- Counts rows in a source partition or subpartition selected by HIGH_VALUE.
  -- Parameters:
  -- p_owner                     schema owning the source table
  -- p_table_name                source table name
  -- p_partition_high_value      partition HIGH_VALUE expression
  -- p_prev_partition_high_value previous partition HIGH_VALUE; required for RANGE selection
  -- p_subpartition_high_value   subpartition HIGH_VALUE expression, when counting a subpartition
  -- p_archive_unit_type         unit to count: PARTITION or SUBPARTITION
  FUNCTION fn_get_row_count
  (
    p_owner                    IN VARCHAR2,
    p_table_name               IN VARCHAR2,
    p_partition_high_value     IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value  IN VARCHAR2 DEFAULT NULL,
    p_archive_unit_type        IN VARCHAR2 DEFAULT 'PARTITION'
  )
  RETURN NUMBER;

  -- Truncates or deletes a selected source unit, optionally as a preview.
  -- Parameters:
  -- p_owner                     schema owning the source table
  -- p_table_name                source table name
  -- p_partition_high_value      partition HIGH_VALUE expression
  -- p_prev_partition_high_value previous partition HIGH_VALUE; required for RANGE selection
  -- p_subpartition_high_value   subpartition HIGH_VALUE expression, when cleaning a subpartition
  -- p_archive_unit_type         unit to clean: PARTITION or SUBPARTITION
  -- p_mode                      cleanup operation: TRUNCATE or DELETE
  -- p_execute                   Y executes the operation; N only logs the generated operation
  PROCEDURE prc_cleanup_unit
  (
    p_owner                    IN VARCHAR2,
    p_table_name               IN VARCHAR2,
    p_partition_high_value     IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value  IN VARCHAR2 DEFAULT NULL,
    p_archive_unit_type        IN VARCHAR2 DEFAULT 'PARTITION',
    p_mode                     IN VARCHAR2 DEFAULT 'TRUNCATE',
    p_execute                  IN VARCHAR2 DEFAULT 'N'
  );

  -- Reports the health of the source-side AGENT installation.
  -- Returns the health-check status text.
  FUNCTION fn_health_check
  RETURN VARCHAR2;
END PKG_AGENT_ARCHIVE;
/
