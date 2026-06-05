CREATE OR REPLACE PACKAGE PKG_REPLICA_SQL
AS
  /*
    Package      : PKG_REPLICA_SQL
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : SQL helper package - name validation, dynamic SQL execution,
                   bind variable handling, SQL logging

    Prerequisite : PKG_REPLICA_TL_LOGGING, TBL_REPLICA_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    ORA-40478 fix in fn_format_table (TO_CLOB guard)
  */
  FUNCTION fn_assert_simple_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2;

  FUNCTION fn_assert_qualified_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2;

  FUNCTION fn_run_into_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  FUNCTION fn_run_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  FUNCTION fn_run_sql_in_bind
  (
    p_log_id     IN NUMBER,
    p_sql        IN CLOB,
    p_array_bind IN SYS.ODCIVARCHAR2LIST,
    p_execute    IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  FUNCTION fn_run_into_sql_in_bind
  (
    p_log_id     IN NUMBER,
    p_sql        IN CLOB,
    p_array_bind IN SYS.ODCIVARCHAR2LIST,
    p_execute    IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  FUNCTION fn_format_table
  (
    p_columns       IN VARCHAR2,
    p_rows          IN CLOB,
    p_col_align     IN VARCHAR2 DEFAULT NULL,
    p_separator     IN VARCHAR2 DEFAULT '|',
    p_null_text     IN VARCHAR2 DEFAULT '-',
    p_max_col_width IN NUMBER   DEFAULT 120,
    p_box_style     IN VARCHAR2 DEFAULT 'SIMPLE'
  )
  RETURN CLOB;
END PKG_REPLICA_SQL;
/
