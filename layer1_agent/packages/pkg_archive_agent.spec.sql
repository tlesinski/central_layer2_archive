CREATE OR REPLACE PACKAGE PKG_ARCHIVE_AGENT
AS
  FUNCTION get_partition_info
  (
    p_owner      IN VARCHAR2,
    p_table_name IN VARCHAR2
  )
  RETURN ARCHIVE_PARTITION_INFO_TAB PIPELINED;

  FUNCTION get_row_count
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL
  )
  RETURN NUMBER;

  PROCEDURE cleanup_unit
  (
    p_owner             IN VARCHAR2,
    p_table_name        IN VARCHAR2,
    p_partition_name    IN VARCHAR2,
    p_subpartition_name IN VARCHAR2 DEFAULT NULL,
    p_mode              IN VARCHAR2 DEFAULT 'TRUNCATE',
    p_execute           IN VARCHAR2 DEFAULT 'N'
  );

  FUNCTION health_check
  RETURN VARCHAR2;
END PKG_ARCHIVE_AGENT;
/
