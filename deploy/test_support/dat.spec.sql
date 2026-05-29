CREATE OR REPLACE PACKAGE DAT
AS
  /*
    Package      : DAT
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Fake business date provider for archive tests.
                   This package is intentionally test support, not archiver core.

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_eod RETURN DATE;
  FUNCTION fn_boy RETURN DATE;
  FUNCTION fn_eoy RETURN DATE;
END DAT;
/
