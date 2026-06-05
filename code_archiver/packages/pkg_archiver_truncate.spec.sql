CREATE OR REPLACE PACKAGE PKG_ARCHIVER_TRUNCATE
AS
  /*
    Package      : PKG_ARCHIVER_TRUNCATE
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Source truncate - request source truncate through layer 1 agent
                   after quality success, respecting RETENTION_RULE

    Prerequisite : PKG_ARCHIVER_SQL, PKG_ARCHIVER_LOG, PKG_AGENT_ARCHIVE,
                   VW_ARCHIVER_TRUNCATE_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
  */
  PROCEDURE prc_truncate
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_TRUNCATE;
/
