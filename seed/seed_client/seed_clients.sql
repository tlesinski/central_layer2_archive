PROMPT Rebuilding CLIENT seed objects

CONNECT &&CLIENT1_SCHEMA/"&&CLIENT1_PASSWORD"@&&SOURCE_SYS_CONNECT
@@seed_client_source.sql 430
@@seed_client_subpart_source.sql 2000 540 20 2.11
@@seed_client_daily_interval_source.sql 3000 30 1.91

CONNECT &&CLIENT2_SCHEMA/"&&CLIENT2_PASSWORD"@&&SOURCE_SYS_CONNECT
@@seed_client_source.sql 250
@@seed_client_subpart_source.sql 4000 360 40 3.22
@@seed_client_daily_interval_source.sql 5000 50 2.77

PROMPT CLIENT seed rebuild completed
