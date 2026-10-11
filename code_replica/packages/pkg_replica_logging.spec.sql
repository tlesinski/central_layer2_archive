CREATE OR REPLACE EDITIONABLE PACKAGE PKG_REPLICA_LOGGING --AUTHID CURRENT_USER
authid current_user
AS

  /*
    Package      : PKG_REPLICA_LOGGING
    Developer    : Tomasz Lesinski
    Date         : 2020-02-24
    Purpose      : Logging package

    Prerequisite : TBL_REPLICA_PROCESS_LOG, SEQ_REPLICA_PROCESS_LOG

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2020-02-20   Tomasz Lesinski    Initial version
    2.0        2021-12-01   Tomasz Lesinski    Simplification
     2.1        2022-11-04   Tomasz Lesinski    JSON column support
     2.2        2026-05-31   Tomasz Lesinski    ORA-40478 fix: manual JSON for large CLOB messages
  */

-- global variables

g_lang_const CONSTANT VARCHAR2(30) := 'english';

g_timestamp_formt_const CONSTANT VARCHAR2(30) := 'DD-MM-YYYY HH24:MI:SSXFF';
g_date_formt_const CONSTANT VARCHAR2(30) := 'DD-MM-YYYY HH24:MI:SS';
g_short_date_formt_const CONSTANT VARCHAR2(30) := 'DD-MM-YYYY';

g_sttus_init_const CONSTANT VARCHAR2(30) := 'INIT';
g_sttus_executing_const CONSTANT VARCHAR2(30) := 'EXECUTING';
g_sttus_warning_const CONSTANT VARCHAR2(30) := 'WARNING';
g_sttus_success_const CONSTANT VARCHAR2(30) := 'SUCCESS';
g_sttus_error_const CONSTANT VARCHAR2(30) := 'ERROR';
g_sttus_running_const CONSTANT VARCHAR2(30) := 'RUNNING';
g_sttus_undefined_const CONSTANT VARCHAR2(30) := 'UNDEFINED';

g_err_sev_low_const CONSTANT VARCHAR2(10) := 'LOW';
g_err_sev_med_const CONSTANT VARCHAR2(10) := 'MEDIUM';
g_err_sev_hig_const CONSTANT VARCHAR2(10) := 'HIGH';

--Can be set to Y if there is a need for writing log entries of type debug during the next execution.
--'N' normal mode 'D' debug mode
g_log_lvl VARCHAR2(10) := 'N';

--How many days should the log be stored. Used by prc_log_cleanup_table.
g_log_retention_days NUMBER := 90;

--The name of log table.
g_log_table_name VARCHAR2(128) := 'TBL_REPLICA_PROCESS_LOG';

--The name of sequence used for PK.
g_log_sequence_name VARCHAR2(128) := 'SEQ_REPLICA_PROCESS_LOG';

g_curr_schema_name VARCHAR2(128);

  -- Inserts or updates a process log entry with its message and execution context.

  -- Parameters:
  -- p_log_id       identifier of the log entry to insert or update
  -- p_log_msg      message to save
  -- p_log_lvl      logging level: N for normal, D for debug
  -- p_mstr_log_id  optional parent/group log identifier
  -- p_log_categ    optional log category
  -- p_mstr_fun     optional procedure or function name
  -- p_log_sttus    optional process status
  -- p_start_date   optional process start timestamp
  -- p_end_date     optional process end timestamp
  -- p_last_err_code optional Oracle error code
  -- p_last_err_desc optional Oracle error description
  -- p_log_type     message type, such as TEXT or JSON

  -- Example use #1:
  -- PKG_REPLICA_LOGGING.prc_log( p_log_msg => 'log message');
  --
  -- Example use #2:
  -- DECLARE
  -- l_log_id NUMBER := SEQ_REPLICA_PROCESS_LOG.nextval;
  -- BEGIN
  -- PKG_REPLICA_LOGGING.prc_log
  -- (
  -- p_log_id => l_log_id,
  -- p_log_categ => 'load dimensions',
  -- p_mstr_fun => 'prc_load_time_dim',
  -- p_log_sttus => PKG_REPLICA_LOGGING.g_sttus_init_const,
  -- p_start_date => SYSDATE,
  -- p_log_msg => 'init message'
  -- );
  -- END;

  PROCEDURE prc_log
  (
    p_log_id IN NUMBER,
    p_log_msg IN CLOB,
    p_log_lvl IN VARCHAR2 DEFAULT 'N',
    p_mstr_log_id IN NUMBER DEFAULT NULL,
    p_log_categ IN VARCHAR2 DEFAULT NULL,
    p_mstr_fun IN VARCHAR2 DEFAULT NULL,
    p_log_sttus IN VARCHAR2 DEFAULT NULL,
    p_start_date IN DATE DEFAULT NULL,
    p_end_date IN DATE DEFAULT NULL,
    p_last_err_code IN VARCHAR2 DEFAULT NULL,
    p_last_err_desc IN VARCHAR2 DEFAULT NULL,
    p_log_type IN VARCHAR2 DEFAULT 'TEXT'
  );

-- Writes the current Oracle error stack and backtrace to the process log.

-- Parameters:
-- p_log_id      log identifier to associate with the error stack
-- p_mstr_log_id optional parent/group log identifier

PROCEDURE prc_error_stack
(
p_log_id IN NUMBER,
p_mstr_log_id IN NUMBER DEFAULT NULL
);
END PKG_REPLICA_LOGGING;
/
