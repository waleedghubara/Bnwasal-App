const nodemailer = require('nodemailer');

const _createTransporterConfig = () => {
  const host = process.env.EMAIL_HOST;
  const port = parseInt(process.env.EMAIL_PORT, 10) || 587;
  const user = process.env.EMAIL_USER;
  const pass = process.env.EMAIL_PASS;
  return { host, port, user, pass };
};

const _buildMailHtml = ({ greeting, bodyText, otpCode, footerNote }) => `
  <!DOCTYPE html>
  <html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800&display=swap');
      body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
      table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
      img { -ms-interpolation-mode: bicubic; }
    </style>
  </head>
  <body style="font-family: 'Cairo', Tahoma, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 0; direction: rtl; text-align: right; -webkit-font-smoothing: antialiased;">
    <div style="max-width: 600px; margin: 30px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0, 74, 173, 0.05); border: 1px solid #e2e8f0;">
      <!-- Header -->
      <div style="background-color: #004aad; background: linear-gradient(135deg, #004aad 0%, #002860 100%); padding: 35px 20px; text-align: center; border-bottom: 5px solid #F78710;">
        <h1 style="font-size: 32px; font-weight: 800; color: #ffffff; letter-spacing: 0.5px; margin: 0 0 8px 0; text-shadow: 0 2px 4px rgba(0,0,0,0.15); font-family: 'Cairo', sans-serif;">
          بنو<span style="color: #F78710;">صل</span>
        </h1>
        <p style="color: #bfdbfe; font-size: 14px; margin: 0; font-weight: 400; letter-spacing: 0.5px;">شحن ذكي، توصيل سريع وآمن</p>
      </div>
      
      <!-- Body -->
      <div style="padding: 40px 30px; background-color: #ffffff;">
        <div style="font-size: 20px; font-weight: 700; color: #0f172a; margin-bottom: 16px; font-family: 'Cairo', sans-serif;">
          ${greeting}
        </div>
        <p style="font-size: 15px; color: #475569; line-height: 1.8; margin-bottom: 30px; margin-top: 0; font-family: 'Cairo', sans-serif;">
          ${bodyText}
        </p>

        <!-- OTP Code Box -->
        <div style="background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 28px 20px; text-align: center; margin: 30px 0;">
          <div style="font-size: 40px; font-weight: 800; color: #004aad; letter-spacing: 6px; display: inline-block; margin: 0; line-height: 1; font-family: 'Cairo', sans-serif;">
            ${otpCode}
          </div>
          <div style="font-size: 12px; color: #64748b; margin-top: 12px; font-weight: 600; text-transform: uppercase; font-family: 'Cairo', sans-serif;">
            رمز التحقق المؤقت (OTP)
          </div>
        </div>

        <!-- Warning Callout -->
        <div style="text-align: center; margin-bottom: 35px;">
          <span style="font-size: 12px; color: #dc2626; background-color: #fef2f2; border: 1px solid #fee2e2; padding: 12px 18px; border-radius: 8px; display: inline-block; font-family: 'Cairo', sans-serif; line-height: 1.5;">
            ⚠️ هذا الرمز صالح لمدة 10 دقائق فقط. لا تشارك هذا الرمز مطلقاً مع أي شخص لحماية حسابك.
          </span>
        </div>

        <div style="height: 1px; background-color: #e2e8f0; margin: 35px 0;"></div>

        <!-- Footer -->
        <div style="text-align: center; font-size: 12px; color: #94a3b8; line-height: 1.6; font-family: 'Cairo', sans-serif;">
          <p style="margin: 5px 0;">${footerNote}</p>
          <p style="margin: 5px 0;">تم إرسال هذا البريد تلقائياً من نظام إدارة <span style="color: #004aad; font-weight: 700;">بنوصل (We Deliver)</span> للخدمات اللوجستية.</p>
          <p style="margin-top: 20px; font-size: 11px; color: #cbd5e1; margin-bottom: 0;">&copy; 2026 بنوصل. جميع الحقوق محفوظة.</p>
        </div>
      </div>
    </div>
  </body>
  </html>
`;

// ── 1. OTP for account registration / verification ──────────────────────────
const sendOtpEmail = async (email, otpCode, userName = '') => {
  const { host, port, user, pass } = _createTransporterConfig();
  const from = process.env.EMAIL_FROM || '"بنوصل" <contact@bnwasal.com>';

  console.log(`\x1b[35m[OTP Delivery] Preparing to send OTP to ${email}...\x1b[0m`);

  if (!host || !user || !pass) {
    console.log(`\x1b[33m[Email Simulator] SMTP not configured. OTP for ${email}: ${otpCode}\x1b[0m\n`);
    return { success: true, simulated: true };
  }

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      tls: { rejectUnauthorized: false }
    });
    const greeting = userName ? `مرحباً ${userName}،` : 'مرحباً بك،';

    const html = _buildMailHtml({
      greeting,
      bodyText: `شكراً لتسجيلك في تطبيق <strong>بنوصل</strong>. نسعد بوجودك معنا لتجربة شحن وتوصيل ذكية ومميزة.<br>يرجى استخدام رمز التحقق التالي لتفعيل حسابك وإكمال عملية التسجيل:`,
      otpCode,
      footerNote: 'إذا لم تقم بإنشاء حساب في تطبيقنا، يرجى تجاهل هذا البريد الإلكتروني بأمان.',
    });

    const info = await transporter.sendMail({
      from,
      to: email,
      subject: 'كود تفعيل حسابك - بنوصل',
      html,
    });

    console.log(`\x1b[32m[OTP Delivery] Email sent to ${email}. MessageId: ${info.messageId}\x1b[0m`);
    return { success: true, simulated: false };
  } catch (error) {
    console.error(`\x1b[31m[OTP Error] Failed to send to ${email}: ${error.message}\x1b[0m`);
    console.log(`\x1b[33m[Fallback] OTP for ${email}: ${otpCode}\x1b[0m`);
    return { success: false, error: error.message, simulated: true };
  }
};

// ── 2. OTP for forgot password / reset password ──────────────────────────────
const sendResetPasswordEmail = async (email, otpCode, userName = '') => {
  const { host, port, user, pass } = _createTransporterConfig();
  const from = process.env.EMAIL_FROM || '"بنوصل" <contact@bnwasal.com>';

  console.log(`\x1b[35m[Reset Password] Preparing to send reset OTP to ${email}...\x1b[0m`);

  if (!host || !user || !pass) {
    console.log(`\x1b[33m[Email Simulator] SMTP not configured. Reset OTP for ${email}: ${otpCode}\x1b[0m\n`);
    return { success: true, simulated: true };
  }

  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      tls: { rejectUnauthorized: false }
    });
    const greeting = userName ? `مرحباً ${userName}،` : 'مرحباً بك،';

    const html = _buildMailHtml({
      greeting,
      bodyText: `لقد تلقينا طلباً لإعادة تعيين كلمة المرور الخاصة بحسابك في تطبيق <strong>بنوصل</strong>.<br>الرجاء استخدام الرمز التالي لإعادة تعيين كلمة المرور بنجاح. إذا لم تقم بطلب هذا الإجراء، يمكنك تجاهل هذا البريد بأمان:`,
      otpCode,
      footerNote: 'إذا لم تطلب إعادة تعيين كلمة المرور، يرجى تجاهل هذا البريد والتواصل مع الدعم الفني لحماية حسابك.',
    });

    const info = await transporter.sendMail({
      from,
      to: email,
      subject: 'طلب إعادة تعيين كلمة المرور - بنوصل',
      html,
    });

    console.log(`\x1b[32m[Reset Password] Email sent to ${email}. MessageId: ${info.messageId}\x1b[0m`);
    return { success: true, simulated: false };
  } catch (error) {
    console.error(`\x1b[31m[Reset Password Error] Failed to send to ${email}: ${error.message}\x1b[0m`);
    console.log(`\x1b[33m[Fallback] Reset OTP for ${email}: ${otpCode}\x1b[0m`);
    return { success: false, error: error.message, simulated: true };
  }
};

module.exports = {
  sendOtpEmail,
  sendResetPasswordEmail,
};

module.exports = {
  sendOtpEmail,
  sendResetPasswordEmail,
};
