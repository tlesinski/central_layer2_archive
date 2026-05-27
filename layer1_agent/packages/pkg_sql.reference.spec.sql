CREATE OR REPLACE PACKAGE partmgr.PKG_SQL AS
  /*
    Package      : PKG_SQL
    Purpose      : SQL helper package

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.1        2026-05-08   Tomasz Lesinski    Add partition dictionary helper
  */

  TYPE type_partition_info_obj IS RECORD
  (
    schema_name               VARCHAR2(128),
    table_name                VARCHAR2(128),
    partition_name            VARCHAR2(128),
    subpartition_name         VARCHAR2(128),
    partition_high_value      VARCHAR2(4000),
    subpartition_high_value   VARCHAR2(4000),
    partition_position        NUMBER,
    subpartition_position     NUMBER
  );

  TYPE type_partition_info_tab IS TABLE OF type_partition_info_obj;

  FUNCTION fn_get_partition_info
  (
    p_schema_name  IN VARCHAR2,
    p_table_name   IN VARCHAR2,
    p_where_clause IN VARCHAR2 DEFAULT '1=1'
  )
  RETURN type_partition_info_tab PIPELINED;
END PKG_SQL;
/
