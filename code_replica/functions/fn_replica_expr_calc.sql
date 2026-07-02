CREATE OR REPLACE FUNCTION FN_REPLICA_EXPR_CALC
(
  p_partition_high_value      IN VARCHAR2,
  p_prev_partition_high_value IN VARCHAR2,
  p_subpartition_high_value   IN VARCHAR2,
  p_replicate_expression      IN VARCHAR2,
  p_mode                      IN VARCHAR2 DEFAULT 'FLAG'
)
RETURN VARCHAR2
IS
  l_expression VARCHAR2(4000);
  l_mode       VARCHAR2(20) := UPPER(TRIM(NVL(p_mode, 'FLAG')));
  l_result     VARCHAR2(4000);

  PROCEDURE assert_placeholder_value
  (
    p_placeholder IN VARCHAR2,
    p_value       IN VARCHAR2
  )
  IS
  BEGIN
    IF INSTR(l_expression, p_placeholder) > 0 AND p_value IS NULL THEN
      RAISE_APPLICATION_ERROR(-20270, 'No value available for placeholder ' || p_placeholder);
    END IF;
  END;
BEGIN
  IF p_replicate_expression IS NULL THEN
    RETURN CASE WHEN l_mode = 'FLAG' THEN 'N' ELSE NULL END;
  END IF;

  IF l_mode NOT IN ('FLAG', 'VALUE') THEN
    RETURN 'ERROR: unsupported FN_REPLICA_EXPR_CALC mode ' || l_mode;
  END IF;

  l_expression := p_replicate_expression;
  assert_placeholder_value('<partition_high_value>', p_partition_high_value);
  assert_placeholder_value('<prev_partition_high_value>', p_prev_partition_high_value);
  assert_placeholder_value('<subpartition_high_value>', p_subpartition_high_value);

  l_expression := REPLACE(l_expression, '<partition_high_value>', p_partition_high_value);
  l_expression := REPLACE(l_expression, '<prev_partition_high_value>', p_prev_partition_high_value);
  l_expression := REPLACE(l_expression, '<subpartition_high_value>', p_subpartition_high_value);

  IF l_mode = 'VALUE' THEN
    RETURN l_expression;
  END IF;

  EXECUTE IMMEDIATE
    'SELECT CASE WHEN ' || l_expression || ' THEN ''Y'' ELSE ''N'' END FROM dual'
    INTO l_result;

  RETURN l_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'ERROR: ' || SQLERRM;
END FN_REPLICA_EXPR_CALC;
/
