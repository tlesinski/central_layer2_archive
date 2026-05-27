CREATE OR REPLACE PACKAGE BODY partmgr.PKG_SQL AS
  /*
    Package      : PKG_SQL
    Purpose      : SQL helper package

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.1        2026-05-08   Tomasz Lesinski    Add partition dictionary helper
  */

  FUNCTION fn_get_partition_info
  (
    p_schema_name  IN VARCHAR2,
    p_table_name   IN VARCHAR2,
    p_where_clause IN VARCHAR2 DEFAULT '1=1'
  )
  RETURN type_partition_info_tab PIPELINED
  IS
    l_high_value_partition      LONG;
    l_high_value_subpartition   LONG;
    l_rec                       type_partition_info_obj := type_partition_info_obj(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
    l_cursor                    SYS_REFCURSOR;
    l_sql                       VARCHAR2(32767);
    l_where_clause              VARCHAR2(32767);
  BEGIN
    IF p_schema_name IS NULL OR p_table_name IS NULL THEN
      raise_application_error(-20001, 'Schema name and table name are required');
    END IF;

    l_where_clause := NVL(NULLIF(TRIM(p_where_clause), ''), '1=1');

    l_sql := 'SELECT p.table_owner,
                     p.table_name,
                     p.partition_name,
                     s.subpartition_name,
                     p.high_value,
                     s.high_value,
                     p.partition_position,
                     s.subpartition_position
                FROM (
                      SELECT *
                        FROM dba_tab_partitions
                       WHERE table_owner = :schema_name
                         AND table_name = :table_name
                         AND (' || l_where_clause || ')
                     ) p
                LEFT JOIN dba_tab_subpartitions s
                  ON p.table_owner = s.table_owner
                 AND p.table_name = s.table_name
                 AND p.partition_name = s.partition_name';

    OPEN l_cursor FOR l_sql USING UPPER(p_schema_name), UPPER(p_table_name);

    LOOP
      FETCH l_cursor INTO l_rec.schema_name,
                          l_rec.table_name,
                          l_rec.partition_name,
                          l_rec.subpartition_name,
                          l_high_value_partition,
                          l_high_value_subpartition,
                          l_rec.partition_position,
                          l_rec.subpartition_position;
      EXIT WHEN l_cursor%NOTFOUND;

      l_rec.partition_high_value := DBMS_LOB.SUBSTR(TO_CLOB(l_high_value_partition), 4000, 1);
      l_rec.subpartition_high_value := DBMS_LOB.SUBSTR(TO_CLOB(l_high_value_subpartition), 4000, 1);

      PIPE ROW(l_rec);
    END LOOP;

    CLOSE l_cursor;
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      IF l_cursor%ISOPEN THEN
        CLOSE l_cursor;
      END IF;

      RAISE;
  END fn_get_partition_info;
END PKG_SQL;
/
