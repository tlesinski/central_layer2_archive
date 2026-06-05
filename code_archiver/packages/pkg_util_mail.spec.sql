CREATE OR REPLACE PACKAGE PKG_UTIL_MAIL
AUTHID CURRENT_USER
AS
  g_mailer_id CONSTANT VARCHAR2(256) := 'Mailer by Oracle UTL_SMTP';
  g_boundary CONSTANT VARCHAR2(256) := '----PARTMGR_UTIL_MAIL_BOUNDARY';
  g_first_boundary CONSTANT VARCHAR2(256) := '--' || g_boundary || UTL_TCP.CRLF;
  g_last_boundary CONSTANT VARCHAR2(256) := '--' || g_boundary || '--' || UTL_TCP.CRLF;
  g_multipart_mime_type CONSTANT VARCHAR2(256) := 'multipart/mixed; boundary="' || g_boundary || '"';

  FUNCTION fn_mail_enabled
  RETURN VARCHAR2;

  FUNCTION fn_get_config
  (
    p_config_key IN VARCHAR2,
    p_default    IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2;

  FUNCTION fn_begin_session
  RETURN UTL_SMTP.CONNECTION;

  FUNCTION fn_begin_mail
  (
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_mime_type  IN VARCHAR2 DEFAULT 'text/plain',
    p_priority   IN PLS_INTEGER DEFAULT NULL
  )
  RETURN UTL_SMTP.CONNECTION;

  PROCEDURE prc_begin_mail_in_session
  (
    p_conn       IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_mime_type  IN VARCHAR2 DEFAULT 'text/plain',
    p_priority   IN PLS_INTEGER DEFAULT NULL
  );

  PROCEDURE prc_write_text
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN VARCHAR2
  );

  PROCEDURE prc_write_mb_text
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN VARCHAR2
  );

  PROCEDURE prc_write_raw
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN RAW
  );

  PROCEDURE prc_attach_clob
  (
    p_conn      IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_data      IN CLOB,
    p_mime_type IN VARCHAR2 DEFAULT 'text/plain',
    p_inline    IN BOOLEAN DEFAULT TRUE,
    p_filename  IN VARCHAR2 DEFAULT NULL,
    p_last      IN BOOLEAN DEFAULT FALSE
  );

  PROCEDURE prc_begin_attachment
  (
    p_conn         IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_mime_type    IN VARCHAR2 DEFAULT 'text/plain',
    p_inline       IN BOOLEAN DEFAULT TRUE,
    p_filename     IN VARCHAR2 DEFAULT NULL,
    p_transfer_enc IN VARCHAR2 DEFAULT NULL
  );

  PROCEDURE prc_end_attachment
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_last IN BOOLEAN DEFAULT FALSE
  );

  PROCEDURE prc_end_mail_in_session
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  );

  PROCEDURE prc_end_session
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  );

  PROCEDURE prc_end_mail
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  );

  PROCEDURE prc_mail
  (
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_message    IN VARCHAR2
  );

  PROCEDURE prc_mail_file
  (
    p_sender       IN VARCHAR2,
    p_recipients   IN VARCHAR2,
    p_subject      IN VARCHAR2,
    p_message      IN VARCHAR2,
    p_file_name    IN VARCHAR2,
    p_file_content IN CLOB
  );

  PROCEDURE prc_send_html
  (
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_html       IN CLOB
  );

  PROCEDURE prc_send_report
  (
    p_report_name IN VARCHAR2,
    p_recipients  IN VARCHAR2 DEFAULT NULL,
    p_subject     IN VARCHAR2 DEFAULT NULL
  );
END PKG_UTIL_MAIL;
/
