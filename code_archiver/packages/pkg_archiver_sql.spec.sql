CREATE OR REPLACE PACKAGE PKG_ARCHIVER_SQL
AS
  /*
    Package      : PKG_ARCHIVER_SQL
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : SQL helper package - name validation, dynamic SQL execution,
                   bind variable handling, SQL logging

    Prerequisite : PKG_ARCHIVER_LOGGING, TBL_ARCHIVER_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    ORA-40478 fix in fn_format_table (TO_CLOB guard)
  */
  -- Validates and returns a simple unqualified Oracle identifier.
  -- Parameters:
  -- p_name identifier to validate
  -- Returns the validated identifier, or raises an error for an invalid name.
  FUNCTION fn_assert_simple_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2;

  -- Validates and returns an owner-qualified Oracle object name.
  -- Parameters:
  -- p_name qualified identifier to validate
  -- Returns the validated qualified name, or raises an error for an invalid name.
  FUNCTION fn_assert_qualified_name
  (
    p_name IN VARCHAR2
  )
  RETURN VARCHAR2;

  -- Executes a query expected to return one value and logs the SQL operation.
  -- Parameters:
  -- p_log_id  optional process log identifier
  -- p_sql     query to execute
  -- p_execute Y executes the query; N logs the preview without executing
  -- Returns the query result as a number.
  FUNCTION fn_run_into_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  -- Executes a SQL statement and logs the operation.
  -- Parameters:
  -- p_log_id  optional process log identifier
  -- p_sql     SQL statement to execute
  -- p_execute Y executes the statement; N logs the preview without executing
  -- Returns the affected-row count when available.
  FUNCTION fn_run_sql
  (
    p_log_id  IN NUMBER,
    p_sql     IN CLOB,
    p_execute IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  -- Executes SQL with positional VARCHAR2 bind values.
  -- Parameters:
  -- p_log_id     optional process log identifier
  -- p_sql        SQL statement containing bind placeholders
  -- p_array_bind bind values in placeholder order
  -- p_execute    Y executes the statement; N logs the preview without executing
  -- Returns the affected-row count when available.
  FUNCTION fn_run_sql_in_bind
  (
    p_log_id     IN NUMBER,
    p_sql        IN CLOB,
    p_array_bind IN SYS.ODCIVARCHAR2LIST,
    p_execute    IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  -- Executes a query with positional VARCHAR2 bind values and returns its numeric result.
  -- Parameters:
  -- p_log_id     optional process log identifier
  -- p_sql        query containing bind placeholders
  -- p_array_bind bind values in placeholder order
  -- p_execute    Y executes the query; N logs the preview without executing
  -- Returns the query result as a number.
  FUNCTION fn_run_into_sql_in_bind
  (
    p_log_id     IN NUMBER,
    p_sql        IN CLOB,
    p_array_bind IN SYS.ODCIVARCHAR2LIST,
    p_execute    IN VARCHAR2 DEFAULT 'Y'
  )
  RETURN NUMBER;

  -- Formats column names and rows as a printable text table.
  -- Parameters:
  -- p_columns       delimited column headings
  -- p_rows          formatted row data
  -- p_col_align     optional column alignment instructions
  -- p_separator     text separating columns
  -- p_null_text     text used for null values
  -- p_max_col_width maximum rendered width of each column
  -- p_box_style     table border style
  -- Returns the formatted table as a CLOB.
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
END PKG_ARCHIVER_SQL;
/
