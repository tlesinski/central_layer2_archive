CREATE OR REPLACE PACKAGE BODY PKG_ARCHIVE_PARTITION
AS
  /*
    Package      : PKG_ARCHIVE_PARTITION
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Partition operations - exchange staging, load staging data,
                   build staging indexes, exchange, drop staging

    Prerequisite : PKG_SQL, PKG_TL_LOGGING

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
    1.1        2026-05-28   Tomasz Lesinski    Add PARALLEL_DEGREE support
  */
  FUNCTION fn_normalize_execute(p_execute IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE WHEN UPPER(NVL(TRIM(p_execute), 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
  END;

  FUNCTION fn_qualified_table
  (
    p_owner          IN VARCHAR2,
    p_table          IN VARCHAR2,
    p_source_db_link IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2
  IS
    l_name VARCHAR2(400);
  BEGIN
    l_name := PKG_SQL.fn_assert_simple_name(p_owner) || '.' || PKG_SQL.fn_assert_simple_name(p_table);

    IF p_source_db_link IS NOT NULL AND UPPER(TRIM(p_source_db_link)) NOT IN ('LOCAL', 'NONE') THEN
      l_name := l_name || '@' || PKG_SQL.fn_assert_simple_name(p_source_db_link);
    END IF;

    RETURN l_name;
  END fn_qualified_table;

  FUNCTION fn_normalize_tablespace_name(p_tablespace_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_tablespace_name IS NULL OR TRIM(p_tablespace_name) IS NULL THEN
      raise_application_error(-20045, 'TABLESPACE_NAME is required for exchange staging objects');
    END IF;

    RETURN PKG_SQL.fn_assert_simple_name(p_tablespace_name);
  END fn_normalize_tablespace_name;

  FUNCTION fn_high_value_to_date(p_high_value IN VARCHAR2) RETURN DATE IS
    l_date DATE;
  BEGIN
    IF p_high_value IS NULL OR UPPER(TRIM(p_high_value)) = 'MAXVALUE' THEN
      RETURN NULL;
    END IF;

    EXECUTE IMMEDIATE 'SELECT ' || p_high_value || ' FROM dual' INTO l_date;
    RETURN l_date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END fn_high_value_to_date;

  FUNCTION fn_first_partition_key_column
  (
    p_owner IN VARCHAR2,
    p_table IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_column_name VARCHAR2(128);
  BEGIN
    SELECT column_name
      INTO l_column_name
      FROM all_part_key_columns
     WHERE owner = UPPER(p_owner)
       AND name = UPPER(p_table)
       AND object_type = 'TABLE'
       AND column_position = 1;

    RETURN PKG_SQL.fn_assert_simple_name(l_column_name);
  END fn_first_partition_key_column;

  FUNCTION fn_first_subpartition_key_column
  (
    p_owner IN VARCHAR2,
    p_table IN VARCHAR2
  )
  RETURN VARCHAR2
  IS
    l_column_name VARCHAR2(128);
  BEGIN
    SELECT column_name
      INTO l_column_name
      FROM all_subpart_key_columns
     WHERE owner = UPPER(p_owner)
       AND name = UPPER(p_table)
       AND object_type = 'TABLE'
       AND column_position = 1;

    RETURN PKG_SQL.fn_assert_simple_name(l_column_name);
  END fn_first_subpartition_key_column;

  PROCEDURE prc_build_staging_indexes
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_parallel_degree    IN NUMBER DEFAULT 4,
    p_tablespace_name    IN VARCHAR2
  )
  IS
    l_sql          CLOB;
    l_column_list  VARCHAR2(4000);
    l_sql_rowcount NUMBER;
    l_index_name   VARCHAR2(128);
    l_tablespace   VARCHAR2(128);
  BEGIN
    l_tablespace := fn_normalize_tablespace_name(p_tablespace_name);

    FOR r IN (
      SELECT i.index_name, i.uniqueness
        FROM all_indexes i
        JOIN all_part_indexes p
          ON p.owner = i.owner
         AND p.index_name = i.index_name
       WHERE i.owner = UPPER(p_target_owner)
         AND i.table_owner = UPPER(p_target_owner)
         AND i.table_name = UPPER(p_target_table)
         AND i.index_type = 'NORMAL'
         AND p.locality = 'LOCAL'
       ORDER BY i.index_name
    ) LOOP
      SELECT LISTAGG(
               PKG_SQL.fn_assert_simple_name(column_name) ||
               CASE WHEN descend = 'DESC' THEN ' DESC' END,
               ', '
             ) WITHIN GROUP (ORDER BY column_position)
        INTO l_column_list
        FROM all_ind_columns
       WHERE index_owner = UPPER(p_target_owner)
         AND table_owner = UPPER(p_target_owner)
         AND table_name = UPPER(p_target_table)
         AND index_name = r.index_name;

      l_index_name := SUBSTR('STG_' || r.index_name || '_' || TO_CHAR(SYSTIMESTAMP, 'HH24MISSFF3'), 1, 128);

      l_sql := 'CREATE ' ||
               CASE WHEN r.uniqueness = 'UNIQUE' THEN 'UNIQUE ' END ||
               'INDEX ' ||
               PKG_SQL.fn_assert_simple_name(p_target_owner) || '.' ||
               PKG_SQL.fn_assert_simple_name(l_index_name) ||
               ' ON ' ||
               fn_qualified_table(p_target_owner, p_staging_table_name) ||
               '(' || l_column_list || ')' ||
               ' TABLESPACE ' || l_tablespace ||
               ' PARALLEL ' || p_parallel_degree;

      l_sql_rowcount := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
    END LOOP;
  END prc_build_staging_indexes;

  PROCEDURE prc_create_exchange_staging
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_partition_name     IN VARCHAR2,
    p_staging_table_name OUT VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_tablespace_name    IN VARCHAR2
  )
  IS
    l_sql          CLOB;
    l_sql_rowcount NUMBER;
    l_tablespace   VARCHAR2(128);
  BEGIN
    l_tablespace := fn_normalize_tablespace_name(p_tablespace_name);

    p_staging_table_name := SUBSTR(
      'STG_' || TO_CHAR(SYSTIMESTAMP, 'DDHH24MISSFF3') || '_' ||
      UPPER(p_target_table) || '_' || UPPER(p_partition_name),
      1,
      128
    );

    l_sql := 'CREATE TABLE ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' TABLESPACE ' || l_tablespace ||
             ' FOR EXCHANGE WITH TABLE ' ||
             fn_qualified_table(p_target_owner, p_target_table);

    l_sql_rowcount := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);

  END prc_create_exchange_staging;

  PROCEDURE prc_load_exchange_staging
  (
    p_source_db_link     IN VARCHAR2,
    p_source_owner       IN VARCHAR2,
    p_source_table       IN VARCHAR2,
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_high_value         IN VARCHAR2,
    p_prev_high_value    IN VARCHAR2 DEFAULT NULL,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL,
    p_parallel_degree    IN NUMBER DEFAULT 4,
    p_rows_loaded        OUT NUMBER
  )
  IS
    l_sql          CLOB;
    l_key_column   VARCHAR2(128);
    l_high_date    DATE;
    l_low_date     DATE;
  BEGIN
    l_key_column := fn_first_partition_key_column(p_target_owner, p_target_table);
    l_high_date := fn_high_value_to_date(p_high_value);
    l_low_date := fn_high_value_to_date(p_prev_high_value);

    IF l_high_date IS NULL THEN
      raise_application_error(-20041, 'EXCHANGE requires a DATE high value for target partition');
    END IF;

    l_sql := 'INSERT /*+ APPEND PARALLEL(' || p_parallel_degree || ') */ INTO ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' SELECT * FROM ' ||
             fn_qualified_table(p_source_owner, p_source_table, p_source_db_link) ||
             ' WHERE ' || l_key_column || ' < DATE ''' || TO_CHAR(l_high_date, 'YYYY-MM-DD') || '''';

    IF l_low_date IS NOT NULL THEN
      l_sql := l_sql || ' AND ' || l_key_column || ' >= DATE ''' || TO_CHAR(l_low_date, 'YYYY-MM-DD') || '''';
    END IF;

    p_rows_loaded := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
  END prc_load_exchange_staging;

  PROCEDURE prc_load_exchange_staging_subpartition
  (
    p_source_db_link            IN VARCHAR2,
    p_source_owner              IN VARCHAR2,
    p_source_table              IN VARCHAR2,
    p_target_owner              IN VARCHAR2,
    p_target_table              IN VARCHAR2,
    p_staging_table_name        IN VARCHAR2,
    p_partition_high_value      IN VARCHAR2,
    p_prev_partition_high_value IN VARCHAR2 DEFAULT NULL,
    p_subpartition_high_value   IN VARCHAR2,
    p_execute                   IN VARCHAR2 DEFAULT 'Y',
    p_log_id                    IN NUMBER DEFAULT NULL,
    p_parallel_degree           IN NUMBER DEFAULT 4,
    p_rows_loaded               OUT NUMBER
  )
  IS
    l_sql             CLOB;
    l_part_key_column VARCHAR2(128);
    l_sub_key_column  VARCHAR2(128);
    l_high_date       DATE;
    l_low_date        DATE;
  BEGIN
    l_part_key_column := fn_first_partition_key_column(p_target_owner, p_target_table);
    l_sub_key_column := fn_first_subpartition_key_column(p_target_owner, p_target_table);
    l_high_date := fn_high_value_to_date(p_partition_high_value);
    l_low_date := fn_high_value_to_date(p_prev_partition_high_value);

    IF l_high_date IS NULL THEN
      raise_application_error(-20043, 'EXCHANGE SUBPARTITION requires a DATE partition high value');
    END IF;

    IF p_subpartition_high_value IS NULL OR TRIM(p_subpartition_high_value) = '#' THEN
      raise_application_error(-20044, 'EXCHANGE SUBPARTITION requires a list subpartition high value');
    END IF;

    l_sql := 'INSERT /*+ APPEND PARALLEL(' || p_parallel_degree || ') */ INTO ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' SELECT * FROM ' ||
             fn_qualified_table(p_source_owner, p_source_table, p_source_db_link) ||
             ' WHERE ' || l_part_key_column || ' < DATE ''' || TO_CHAR(l_high_date, 'YYYY-MM-DD') || '''' ||
             ' AND ' || l_sub_key_column || ' IN (' || p_subpartition_high_value || ')';

    IF l_low_date IS NOT NULL THEN
      l_sql := l_sql || ' AND ' || l_part_key_column || ' >= DATE ''' || TO_CHAR(l_low_date, 'YYYY-MM-DD') || '''';
    END IF;

    p_rows_loaded := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
  END prc_load_exchange_staging_subpartition;

  PROCEDURE prc_exchange_partition
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_partition_name     IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  )
  IS
    l_sql          CLOB;
    l_sql_rowcount NUMBER;
  BEGIN
    l_sql := 'ALTER TABLE ' ||
             fn_qualified_table(p_target_owner, p_target_table) ||
             ' EXCHANGE PARTITION ' ||
             PKG_SQL.fn_assert_simple_name(p_partition_name) ||
             ' WITH TABLE ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' INCLUDING INDEXES WITHOUT VALIDATION';

    l_sql_rowcount := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
  END prc_exchange_partition;

  PROCEDURE prc_exchange_subpartition
  (
    p_target_owner       IN VARCHAR2,
    p_target_table       IN VARCHAR2,
    p_subpartition_name  IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  )
  IS
    l_sql          CLOB;
    l_sql_rowcount NUMBER;
  BEGIN
    l_sql := 'ALTER TABLE ' ||
             fn_qualified_table(p_target_owner, p_target_table) ||
             ' EXCHANGE SUBPARTITION ' ||
             PKG_SQL.fn_assert_simple_name(p_subpartition_name) ||
             ' WITH TABLE ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' INCLUDING INDEXES WITHOUT VALIDATION';

    l_sql_rowcount := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
  END prc_exchange_subpartition;

  PROCEDURE prc_drop_staging
  (
    p_staging_owner      IN VARCHAR2,
    p_staging_table_name IN VARCHAR2,
    p_execute            IN VARCHAR2 DEFAULT 'Y',
    p_log_id             IN NUMBER DEFAULT NULL
  )
  IS
    l_sql          CLOB;
    l_sql_rowcount NUMBER;
  BEGIN
    l_sql := 'DROP TABLE ' ||
             fn_qualified_table(p_staging_owner, p_staging_table_name) ||
             ' PURGE';

    l_sql_rowcount := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
  END prc_drop_staging;
END PKG_ARCHIVE_PARTITION;
/
