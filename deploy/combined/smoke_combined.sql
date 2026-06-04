SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON
SET ECHO ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

@deploy/config/install_config.local.sql

CONNECT &&APPLICATION_SCHEMA/"&&APPLICATION_PASSWORD"@&&COMBINED_CONNECT

@deploy/layer1/smoke_agent.sql

SET DEFINE ON
@deploy/layer2/smoke_archiver.sql &&COMBINED_AGENT_DB_LINK

SET DEFINE ON
@deploy/layer3/smoke_replica.sql &&COMBINED_ARCHIVER_DB_LINK

SET DEFINE ON
DECLARE
  l_invalid_objects PLS_INTEGER;
  l_tw_objects      PLS_INTEGER;
  l_old_views       PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_invalid_objects
    FROM USER_OBJECTS
   WHERE status <> 'VALID';

  SELECT COUNT(*)
    INTO l_tw_objects
    FROM USER_OBJECTS
   WHERE object_name LIKE 'TW\_%' ESCAPE '\';

  SELECT COUNT(*)
    INTO l_old_views
    FROM USER_VIEWS
   WHERE view_name LIKE '%\_VW' ESCAPE '\';

  IF l_invalid_objects <> 0 THEN
    RAISE_APPLICATION_ERROR(-20071, 'Combined smoke invalid objects: ' || l_invalid_objects);
  ELSIF l_tw_objects <> 0 THEN
    RAISE_APPLICATION_ERROR(-20072, 'Combined smoke found TW_ objects: ' || l_tw_objects);
  ELSIF l_old_views <> 0 THEN
    RAISE_APPLICATION_ERROR(-20073, 'Combined smoke found _VW views: ' || l_old_views);
  END IF;

  DBMS_OUTPUT.PUT_LINE('COMBINED_SMOKE_OK');
END;
/
