BEGIN
  RAISE_APPLICATION_ERROR(-20502, 'No test script is mapped for TEST_ID=&&TEST_ID in this test level');
END;
/
