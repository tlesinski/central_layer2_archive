CREATE OR REPLACE PACKAGE PKG_UTIL_MAIL
AUTHID CURRENT_USER
AS
  /*
    Package      : PKG_UTIL_MAIL
    Purpose      : Send configured mail through UTL_SMTP.

    Change History:
    ------------------------------------------------------------------------------
    Version    Date         Programmer         Description
    ------------------------------------------------------------------------------
    1.0        2026-10-11   Tomasz Lesinski    Add package change history
  */
  g_mailer_id CONSTANT VARCHAR2(256) := 'Mailer by Oracle UTL_SMTP';
  g_boundary CONSTANT VARCHAR2(256) := '----PARTMGR_UTIL_MAIL_BOUNDARY';
  g_first_boundary CONSTANT VARCHAR2(256) := '--' || g_boundary || UTL_TCP.CRLF;
  g_last_boundary CONSTANT VARCHAR2(256) := '--' || g_boundary || '--' || UTL_TCP.CRLF;
  g_multipart_mime_type CONSTANT VARCHAR2(256) := 'multipart/mixed; boundary="' || g_boundary || '"';

  -- Indicates whether outbound mail is enabled by configuration.
  -- Returns Y when enabled and N otherwise.
  FUNCTION fn_mail_enabled
  RETURN VARCHAR2;

  -- Reads a mail configuration value, using a fallback when it is not configured.
  -- Parameters:
  -- p_config_key configuration key to read
  -- p_default    value returned when the key has no configured value
  -- Returns the configured value or the fallback.
  FUNCTION fn_get_config
  (
    p_config_key IN VARCHAR2,
    p_default    IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2;

  -- Opens an SMTP connection using the configured mail server.
  -- Returns the open SMTP connection.
  FUNCTION fn_begin_session
  RETURN UTL_SMTP.CONNECTION;

  -- Opens an SMTP connection and starts a message with the supplied headers.
  -- Parameters:
  -- p_sender     sender address
  -- p_recipients comma-separated recipient addresses
  -- p_subject    message subject
  -- p_mime_type  message MIME type
  -- p_priority   optional message priority
  -- Returns the connection for writing and sending the message.
  FUNCTION fn_begin_mail
  (
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_mime_type  IN VARCHAR2 DEFAULT 'text/plain',
    p_priority   IN PLS_INTEGER DEFAULT NULL
  )
  RETURN UTL_SMTP.CONNECTION;

  -- Starts a message on an already-open SMTP connection.
  -- Parameters:
  -- p_conn       open SMTP connection, updated as the message begins
  -- p_sender     sender address
  -- p_recipients comma-separated recipient addresses
  -- p_subject    message subject
  -- p_mime_type  message MIME type
  -- p_priority   optional message priority
  PROCEDURE prc_begin_mail_in_session
  (
    p_conn       IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_mime_type  IN VARCHAR2 DEFAULT 'text/plain',
    p_priority   IN PLS_INTEGER DEFAULT NULL
  );

  -- Writes plain text to an open SMTP message.
  -- Parameters:
  -- p_conn    open SMTP connection
  -- p_message text to write
  PROCEDURE prc_write_text
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN VARCHAR2
  );

  -- Writes multibyte text to an open SMTP message.
  -- Parameters:
  -- p_conn    open SMTP connection
  -- p_message multibyte text to write
  PROCEDURE prc_write_mb_text
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN VARCHAR2
  );

  -- Writes raw message bytes to an open SMTP message.
  -- Parameters:
  -- p_conn    open SMTP connection
  -- p_message raw bytes to write
  PROCEDURE prc_write_raw
  (
    p_conn    IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_message IN RAW
  );

  -- Writes a CLOB as a MIME attachment or inline body part.
  -- Parameters:
  -- p_conn      open SMTP connection
  -- p_data      CLOB content to attach
  -- p_mime_type attachment MIME type
  -- p_inline    TRUE marks the part as inline; FALSE marks it as an attachment
  -- p_filename  optional attachment filename
  -- p_last      TRUE marks this as the last multipart section
  PROCEDURE prc_attach_clob
  (
    p_conn      IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_data      IN CLOB,
    p_mime_type IN VARCHAR2 DEFAULT 'text/plain',
    p_inline    IN BOOLEAN DEFAULT TRUE,
    p_filename  IN VARCHAR2 DEFAULT NULL,
    p_last      IN BOOLEAN DEFAULT FALSE
  );

  -- Begins a MIME attachment section in an open SMTP message.
  -- Parameters:
  -- p_conn         open SMTP connection
  -- p_mime_type    attachment MIME type
  -- p_inline       TRUE marks the part as inline; FALSE marks it as an attachment
  -- p_filename     optional attachment filename
  -- p_transfer_enc optional MIME transfer encoding
  PROCEDURE prc_begin_attachment
  (
    p_conn         IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_mime_type    IN VARCHAR2 DEFAULT 'text/plain',
    p_inline       IN BOOLEAN DEFAULT TRUE,
    p_filename     IN VARCHAR2 DEFAULT NULL,
    p_transfer_enc IN VARCHAR2 DEFAULT NULL
  );

  -- Ends the current MIME attachment section.
  -- Parameters:
  -- p_conn open SMTP connection
  -- p_last TRUE marks this as the last multipart section
  PROCEDURE prc_end_attachment
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_last IN BOOLEAN DEFAULT FALSE
  );

  -- Ends the message while keeping the SMTP session open.
  -- Parameters:
  -- p_conn open SMTP connection, updated as the message ends
  PROCEDURE prc_end_mail_in_session
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  );

  -- Closes an open SMTP session.
  -- Parameters:
  -- p_conn open SMTP connection to close
  PROCEDURE prc_end_session
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  );

  -- Ends the message and closes its SMTP session.
  -- Parameters:
  -- p_conn open SMTP connection to close
  PROCEDURE prc_end_mail
  (
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION
  );

  -- Sends a plain text email using a new SMTP session.
  -- Parameters:
  -- p_sender     sender address
  -- p_recipients comma-separated recipient addresses
  -- p_subject    message subject
  -- p_message    plain text message body
  PROCEDURE prc_mail
  (
    p_sender     IN VARCHAR2,
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_message    IN VARCHAR2
  );

  -- Sends a text email with a CLOB file attachment.
  -- Parameters:
  -- p_sender       sender address
  -- p_recipients   comma-separated recipient addresses
  -- p_subject      message subject
  -- p_message      message body
  -- p_file_name    attachment filename
  -- p_file_content attachment content
  PROCEDURE prc_mail_file
  (
    p_sender       IN VARCHAR2,
    p_recipients   IN VARCHAR2,
    p_subject      IN VARCHAR2,
    p_message      IN VARCHAR2,
    p_file_name    IN VARCHAR2,
    p_file_content IN CLOB
  );

  -- Sends an HTML email using the configured sender.
  -- Parameters:
  -- p_recipients comma-separated recipient addresses
  -- p_subject    message subject
  -- p_html       HTML message body
  PROCEDURE prc_send_html
  (
    p_recipients IN VARCHAR2,
    p_subject    IN VARCHAR2,
    p_html       IN CLOB
  );

  -- Renders a configured report and sends it to the specified recipients.
  -- Parameters:
  -- p_report_name report configuration name
  -- p_recipients optional recipient override; configuration is used when omitted
  -- p_subject    optional subject override
  PROCEDURE prc_send_report
  (
    p_report_name IN VARCHAR2,
    p_recipients  IN VARCHAR2 DEFAULT NULL,
    p_subject     IN VARCHAR2 DEFAULT NULL
  );
END PKG_UTIL_MAIL;
/
