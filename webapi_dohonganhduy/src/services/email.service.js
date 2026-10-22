// Gửi email OTP qua 3 provider (EMAIL_PROVIDER): gmail (nodemailer + Gmail SMTP App Password),
// brevo (REST API qua HTTPS, dự phòng), console (chỉ dev/test: in mã ra terminal).
import nodemailer from 'nodemailer';
import { env } from '../config/env.js';
import { logger } from '../utils/logger.js';

const PURPOSE_TEXT = {
  verify_email: 'xác minh email đăng ký',
  login: 'đăng nhập',
  reset_password: 'đặt lại mật khẩu',
};

/** Hộp thư của provider "console". Test đọc mã OTP ở đây. */
export const consoleOutbox = [];

let gmailTransport;
function getGmailTransport() {
  if (!gmailTransport) {
    gmailTransport = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: { user: env.GMAIL_USER, pass: env.GMAIL_APP_PASSWORD },
    });
  }
  return gmailTransport;
}

function buildOtpMail(code, purpose, fullName) {
  const action = PURPOSE_TEXT[purpose] || 'xác thực';
  const subject = `[ConAn] Mã ${action}: ${code}`;
  const text = `Xin chào ${fullName || ''},\n\nMã ${action} của bạn là: ${code}\nMã có hiệu lực trong 5 phút. Không chia sẻ mã này cho bất kỳ ai.\n\nConAn — Con An toàn`;
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;border:1px solid #e5e7eb;border-radius:12px">
      <h2 style="color:#0f766e;margin:0 0 8px">ConAn — Con An toàn</h2>
      <p>Xin chào <b>${fullName || ''}</b>,</p>
      <p>Mã ${action} của bạn là:</p>
      <p style="font-size:32px;letter-spacing:8px;font-weight:bold;color:#0f766e;margin:16px 0">${code}</p>
      <p style="color:#6b7280">Mã có hiệu lực trong 5 phút. Không chia sẻ mã này cho bất kỳ ai.</p>
    </div>`;
  return { subject, text, html };
}

async function sendViaBrevo(to, { subject, text, html }) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': env.BREVO_API_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({
      sender: { email: env.MAIL_FROM_EMAIL, name: env.MAIL_FROM_NAME },
      to: [{ email: to }],
      subject,
      textContent: text,
      htmlContent: html,
    }),
  });
  if (!res.ok) throw new Error(`Brevo trả lỗi ${res.status}: ${await res.text()}`);
}

export async function sendOtpEmail(to, code, purpose, fullName) {
  const mail = buildOtpMail(code, purpose, fullName);
  switch (env.EMAIL_PROVIDER) {
    case 'gmail':
      await getGmailTransport().sendMail({
        from: `"${env.MAIL_FROM_NAME}" <${env.MAIL_FROM_EMAIL || env.GMAIL_USER}>`,
        to,
        ...mail,
      });
      break;
    case 'brevo':
      await sendViaBrevo(to, mail);
      break;
    default:
      consoleOutbox.push({ to, code, purpose });
      logger.info(`📧 [console] OTP ${purpose} gửi tới ${to}: ${code}`);
  }
}
