SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Dropping all application objects from the current schema

BEGIN
  FOR r IN (
    SELECT object_name, object_type
      FROM user_objects
     WHERE object_type IN
           ('VIEW', 'SYNONYM', 'TRIGGER', 'PACKAGE', 'FUNCTION', 'TABLE', 'SEQUENCE', 'TYPE')
     ORDER BY CASE object_type
                WHEN 'VIEW' THEN 1
                WHEN 'SYNONYM' THEN 2
                WHEN 'TRIGGER' THEN 3
                WHEN 'PACKAGE' THEN 4
                WHEN 'FUNCTION' THEN 5
                WHEN 'TABLE' THEN 6
                WHEN 'SEQUENCE' THEN 7
                WHEN 'TYPE' THEN 8
                ELSE 9
              END
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE
        'DROP ' || r.object_type || ' ' || DBMS_ASSERT.SIMPLE_SQL_NAME(r.object_name) ||
        CASE
          WHEN r.object_type = 'TABLE' THEN ' CASCADE CONSTRAINTS PURGE'
          WHEN r.object_type = 'TYPE' THEN ' FORCE'
          ELSE NULL
        END;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE NOT IN (-4043, -942, -2289) THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  FOR r IN (SELECT db_link FROM user_db_links) LOOP
    EXECUTE IMMEDIATE 'DROP DATABASE LINK ' || DBMS_ASSERT.SIMPLE_SQL_NAME(r.db_link);
  END LOOP;
END;
/

PROMPT Combined application object reset completed
