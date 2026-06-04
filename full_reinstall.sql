SET DEFINE ON
SET VERIFY OFF
SET SERVEROUTPUT ON
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT Installing configured combined topology
@deploy/combined/install_combined.sql

PROMPT Full reinstall completed
