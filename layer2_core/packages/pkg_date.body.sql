CREATE OR REPLACE PACKAGE BODY PKG_DATE AS
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
  FUNCTION fn_eod RETURN DATE IS
  BEGIN
    RETURN TRUNC(SYSDATE);
  END;

  FUNCTION fn_boy RETURN DATE IS
    l_date DATE := TRUNC(SYSDATE, 'YYYY');
  BEGIN
    IF TO_CHAR(l_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') = 'SAT' THEN
      RETURN l_date + 2;
    ELSIF TO_CHAR(l_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') = 'SUN' THEN
      RETURN l_date + 1;
    END IF;
    RETURN l_date;
  END;

  FUNCTION fn_eoy RETURN DATE IS
    l_date DATE := TRUNC(SYSDATE, 'YYYY') - 1;
  BEGIN
    IF TO_CHAR(l_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') = 'SAT' THEN
      RETURN l_date - 1;
    ELSIF TO_CHAR(l_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') = 'SUN' THEN
      RETURN l_date - 2;
    END IF;
    RETURN l_date;
  END;
END PKG_DATE;
/
