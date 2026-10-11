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
     1.1        2026-05-28   Tomasz Lesinski    Add process summary logging
     1.2        2026-06-30   Tomasz Lesinski    Use TRUNCATE_EXPRESSION eligibility
     1.3        2026-10-11   Tomasz Lesinski    Pass HIGH_VALUE selectors to
                                                AGENT source cleanup
  */
  -- Identifies source units eligible for cleanup and optionally requests cleanup from AGENT.
  -- Parameters:
  -- p_execute           Y executes eligible source cleanup; N previews it
  -- p_target_owner      optionally limits cleanup to this target schema
  -- p_target_table_name optionally limits cleanup to this target table
  PROCEDURE prc_truncate
  (
    p_execute           IN VARCHAR2 DEFAULT 'N',
    p_target_owner      IN VARCHAR2 DEFAULT NULL,
    p_target_table_name IN VARCHAR2 DEFAULT NULL
  );
END PKG_ARCHIVER_TRUNCATE;
/
