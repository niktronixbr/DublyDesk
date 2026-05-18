const nodemailer = require('nodemailer');

function createSmtpTransport() {
  const smtpUser = process.env.SMTP_USER ?? process.env.EMAIL_USER ?? null;
  const smtpPass = process.env.SMTP_PASS ?? process.env.EMAIL_PASS ?? null;
  const smtpHost = process.env.SMTP_HOST ?? (smtpUser ? 'smtp.gmail.com' : null);
  const smtpPort = parseInt(process.env.SMTP_PORT ?? '587');

  if (!smtpHost || !smtpUser || !smtpPass) {
    console.warn('⚠️  SMTP não configurado — emails não serão enviados');
  }

  return nodemailer.createTransport({
    host: smtpHost ?? '',
    port: smtpPort,
    secure: smtpPort === 465,
    auth: smtpUser && smtpPass ? { user: smtpUser, pass: smtpPass } : undefined,
  });
}

async function sendEmail({ to, subject, html, text, attachments }) {
  const transport = createSmtpTransport();

  const fromUser = process.env.SMTP_USER ?? process.env.EMAIL_USER ?? 'no-reply@dublydesk.app';
  return transport.sendMail({
    from: `"DublyDesk" <${fromUser}>`,
    to,
    subject,
    text,
    html,
    attachments,
  });
}

module.exports = { sendEmail };
