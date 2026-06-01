CREATE OR REPLACE PACKAGE PKG_ARCHIVE_QUALITY
AS
  /*
    Package      : PKG_ARCHIVE_QUALITY
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Quality check - compare source and target row counts,
                   set QUALITY_STATUS

    Prerequisite : PKG_SQL, PKG_ARCHIVE_LOG, PKG_ARCHIVE_AGENT,
                   TW_ARCHIVE_QUALITY_PARTITIONS_VW

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
     1.0        2026-05-28   Tomasz Lesinski    Initial version
     1.1        2026-05-31   Tomasz Lesinski    Compact per-table summary, ORA-40478 fix
  */
  PROCEDURE prc_quality
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVE_QUALITY;
/
