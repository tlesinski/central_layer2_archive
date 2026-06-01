CREATE OR REPLACE PACKAGE BODY PKG_REPLICA_PARTITION
AS
  /*
    Package      : PKG_REPLICA_PARTITION
    Developer    : Tomasz Lesinski
    Date         : 2026-06-01
    Purpose      : Partition exchange staging for layer 3 replica -
                   create staging, load from L2 source partition,
                   build indexes, exchange, drop staging.

    Prerequisite : PKG_SQL, PKG_REPLICA_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-06-01   Tomasz Lesinski    Initial version
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
      'STG_TMP_REPLICA_' || TO_CHAR(STG_TMP_REPLICA_SEQ.NEXTVAL),
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
    p_source_db_link         IN VARCHAR2,
    p_source_owner           IN VARCHAR2,
    p_source_table           IN VARCHAR2,
    p_source_partition_name  IN VARCHAR2,
    p_target_owner           IN VARCHAR2,
    p_target_table           IN VARCHAR2,
    p_staging_table_name     IN VARCHAR2,
    p_execute                IN VARCHAR2 DEFAULT 'Y',
    p_log_id                 IN NUMBER DEFAULT NULL,
    p_parallel_degree        IN NUMBER DEFAULT 4,
    p_rows_loaded            OUT NUMBER
  )
  IS
    l_sql CLOB;
  BEGIN
    l_sql := 'INSERT /*+ APPEND PARALLEL(' || p_parallel_degree || ') */ INTO ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' SELECT * FROM ' ||
             fn_qualified_table(p_source_owner, p_source_table, p_source_db_link) ||
             ' PARTITION (' || PKG_SQL.fn_assert_simple_name(p_source_partition_name) || ')';

    p_rows_loaded := PKG_SQL.fn_run_sql(p_log_id, l_sql, p_execute);
  END prc_load_exchange_staging;

  PROCEDURE prc_load_exchange_staging_subpartition
  (
    p_source_db_link              IN VARCHAR2,
    p_source_owner                IN VARCHAR2,
    p_source_table                IN VARCHAR2,
    p_source_subpartition_name    IN VARCHAR2,
    p_target_owner                IN VARCHAR2,
    p_target_table                IN VARCHAR2,
    p_staging_table_name          IN VARCHAR2,
    p_execute                     IN VARCHAR2 DEFAULT 'Y',
    p_log_id                      IN NUMBER DEFAULT NULL,
    p_parallel_degree             IN NUMBER DEFAULT 4,
    p_rows_loaded                 OUT NUMBER
  )
  IS
    l_sql CLOB;
  BEGIN
    l_sql := 'INSERT /*+ APPEND PARALLEL(' || p_parallel_degree || ') */ INTO ' ||
             fn_qualified_table(p_target_owner, p_staging_table_name) ||
             ' SELECT * FROM ' ||
             fn_qualified_table(p_source_owner, p_source_table, p_source_db_link) ||
             ' SUBPARTITION (' || PKG_SQL.fn_assert_simple_name(p_source_subpartition_name) || ')';

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

  PROCEDURE prc_cleanup_orphan_staging
  (
    p_retention_days IN NUMBER DEFAULT 30,
    p_execute        IN VARCHAR2 DEFAULT 'N',
    p_log_id         IN NUMBER DEFAULT NULL
  )
  IS
    l_execute_flag VARCHAR2(1);
  BEGIN
    l_execute_flag := fn_normalize_execute(p_execute);

    DBMS_OUTPUT.PUT_LINE('CLEANUP orphan staging tables older than ' || p_retention_days || ' days');

    FOR r IN (
      SELECT o.object_name AS table_name, o.created
        FROM all_objects o
       WHERE o.owner = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
         AND o.object_type = 'TABLE'
         AND o.object_name LIKE 'STG\_TMP\_REPLICA\_%' ESCAPE '\'
         AND o.created < SYSDATE - NVL(p_retention_days, 30)
       ORDER BY o.object_name
    ) LOOP
      DBMS_OUTPUT.PUT_LINE('[CLEANUP] Candidate: ' || r.table_name ||
                           ' (created: ' || TO_CHAR(r.created, 'YYYY-MM-DD HH24:MI:SS') || ')');

      IF l_execute_flag = 'Y' THEN
        prc_drop_staging(
          p_staging_owner      => SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'),
          p_staging_table_name => r.table_name,
          p_execute            => 'Y',
          p_log_id             => p_log_id
        );
        DBMS_OUTPUT.PUT_LINE('[CLEANUP] Dropped: ' || r.table_name);
      END IF;
    END LOOP;

    IF l_execute_flag = 'N' THEN
      DBMS_OUTPUT.PUT_LINE('[CLEANUP] Preview mode - no tables dropped');
    END IF;
  END prc_cleanup_orphan_staging;
END PKG_REPLICA_PARTITION;
/
