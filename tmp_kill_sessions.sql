SET DEFINE OFF
SET SERVEROUTPUT ON
BEGIN
  FOR r IN (SELECT sid, serial# FROM v$session WHERE username IS NOT NULL AND type != 'BACKGROUND' AND (sid != USERENV('SID') OR username != 'SYS')) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || r.sid || ',' || r.serial# || ''' IMMEDIATE';
      DBMS_OUTPUT.PUT_LINE('Killed session ' || r.sid || ',' || r.serial#);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not kill ' || r.sid || ',' || r.serial# || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

