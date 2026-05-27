CREATE OR REPLACE PACKAGE PKG_SQL
AS
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
END PKG_SQL;
/
