CREATE OR REPLACE PACKAGE PKG_REPLICA_RUNNER
AS
  PROCEDURE prc_run
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_stop_after_step   IN VARCHAR2 DEFAULT NULL,
    p_purge_execute     IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_REPLICA_RUNNER;
/
