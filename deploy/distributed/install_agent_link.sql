SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Creating ARCHIVER link to distributed AGENT &1
@deploy/distributed/create_remote_link.sql &5 &2 &3 &4
