-- Run as the business source owner.
-- Arguments: AGENT schema, source table.

GRANT SELECT ON &2 TO &1;

-- Required only when cleanup execution is enabled for this source table.
-- GRANT ALTER ON &2 TO &1;
