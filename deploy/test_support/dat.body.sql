CREATE OR REPLACE PACKAGE BODY DAT
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
  FUNCTION fn_eod RETURN DATE
  IS
  BEGIN
    RETURN TRUNC(SYSDATE);
  END fn_eod;

  FUNCTION fn_boy RETURN DATE
  IS
    l_date DATE := TRUNC(SYSDATE, 'YYYY');
  BEGIN
    WHILE TO_CHAR(l_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') IN ('SAT', 'SUN') LOOP
      l_date := l_date + 1;
    END LOOP;

    RETURN l_date;
  END fn_boy;

  FUNCTION fn_eoy RETURN DATE
  IS
    l_date DATE := TRUNC(SYSDATE, 'YYYY') - 1;
  BEGIN
    WHILE TO_CHAR(l_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') IN ('SAT', 'SUN') LOOP
      l_date := l_date - 1;
    END LOOP;

    RETURN l_date;
  END fn_eoy;
END DAT;
/
