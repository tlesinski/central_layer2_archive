CREATE OR REPLACE PACKAGE PKG_ARCHIVER_IMPORT
AS
  /*
    Package      : PKG_ARCHIVER_IMPORT
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Import source partitions into target archive via EXCHANGE

    Prerequisite : PKG_ARCHIVER_SQL, PKG_ARCHIVER_LOG, PKG_ARCHIVER_PARTITION,
                   VW_ARCHIVER_IMPORT_PARTITIONS

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
  */
  PROCEDURE prc_import
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_IMPORT;
/
