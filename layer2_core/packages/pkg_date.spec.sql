CREATE OR REPLACE PACKAGE PKG_DATE AS
  /*
    Package      : PKG_DATE
    Developer    : Tomasz Lesinski
    Date         : 2026-05-28
    Purpose      : Business date utilities — EOD, BOY, EOY

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-05-28   Tomasz Lesinski    Initial version
  */
  FUNCTION fn_eod RETURN DATE;  -- bieżący biznesowy dzień
  FUNCTION fn_boy RETURN DATE;  -- pierwszy dzień roku (nie weekend)
  FUNCTION fn_eoy RETURN DATE;  -- ostatni dzień poprzedniego roku (nie weekend)
END PKG_DATE;
/
