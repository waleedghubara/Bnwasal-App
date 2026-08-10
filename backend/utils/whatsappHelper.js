const https = require('https');

const formatPhoneForWhatsapp = (phone) => {
  if (!phone) return '';
  // Remove all non-digit characters
  let digits = phone.replace(/\D/g, '');

  // If it starts with 00, remove it
  if (phone.startsWith('00')) {
    digits = digits.slice(2);
  }

  // Egyptian mobile numbers typically start with 01 (e.g. 010, 011, 012, 015) and have 11 digits.
  // We prepend '2' to match Egyptian country code 20 without leading 0.
  if (digits.startsWith('0') && digits.length === 11) {
    digits = '2' + digits;
  }

  // Append @c.us if not already present
  if (!digits.endsWith('@c.us')) {
    return `${digits}@c.us`;
  }
  return digits;
};

const sendWhatsappMessage = (chatId, text) => {
  return new Promise((resolve, reject) => {
    const instanceId = process.env.WHATSAPP_INSTANCE_ID || 'a26e93dd-3f00-4faf-ad82-1dac415c17b6';
    const apiToken = process.env.WHATSAPP_API_TOKEN || '1529|EZfr4SdbOKbGT1HikCdueTnHmDFGHTql4VsHyARPf93cdf6a';
    const baseUrl = process.env.WHATSAPP_BASE_URL || 'https://app.hypersender.com/api/whatsapp/v2';
    const url = `${baseUrl}/${instanceId}/send-text`;
    const payload = JSON.stringify({ chatId, text });

    const urlObj = new URL(url);
    const options = {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ success: true, statusCode: res.statusCode, body: data });
        } else {
          reject(new Error(`WhatsApp API responded with status ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.write(payload);
    req.end();
  });
};

const sendOtpWhatsapp = async (phone, otpCode, userName = '') => {
  const formattedPhone = formatPhoneForWhatsapp(phone);
  console.log(`\x1b[35m[OTP Delivery] Preparing to send WhatsApp OTP to ${formattedPhone}...\x1b[0m`);

  const headerText = `*بنوصل* 📦\n━━━━━━━━━━━━━━━━━━━━\nمرحباً بك ${userName ? `*${userName}*` : 'في عائلة بنوصل'} 👋\n\nيرجى نسخ الكود المكون من 6 أرقام والموجود في الرسالة التالية 👇 والتوجه للتطبيق، وسيقوم التطبيق بالتعرف على الكود ولصقه تلقائياً بدون أي تدخل منك.\n━━━━━━━━━━━━━━━━━━━━`;
  const codeText = `${otpCode}`;

  try {
    const resultHeader = await sendWhatsappMessage(formattedPhone, headerText);
    const resultCode = await sendWhatsappMessage(formattedPhone, codeText);
    console.log(`\x1b[32m[OTP Delivery] WhatsApp messages sent to ${formattedPhone}. Status: ${resultHeader.statusCode}, ${resultCode.statusCode}\x1b[0m`);
    return { success: true, response: resultCode.body };
  } catch (error) {
    console.error(`\x1b[31m[OTP Error] Failed to send WhatsApp to ${formattedPhone}: ${error.message}\x1b[0m`);
    return { success: false, error: error.message };
  }
};

const sendResetPasswordWhatsapp = async (phone, otpCode, userName = '') => {
  const formattedPhone = formatPhoneForWhatsapp(phone);
  console.log(`\x1b[35m[Reset Password] Preparing to send WhatsApp Reset OTP to ${formattedPhone}...\x1b[0m`);

  const headerText = `*بنوصل* 🔑\n━━━━━━━━━━━━━━━━━━━━\nمرحباً بك ${userName ? `*${userName}*` : 'العزيز'} 👋\n\nيرجى نسخ الكود المكون من 6 أرقام والموجود في الرسالة التالية 👇 والتوجه للتطبيق، وسيقوم التطبيق بالتعرف على الكود ولصقه تلقائياً بدون أي تدخل منك لإعادة تعيين كلمة المرور.\n━━━━━━━━━━━━━━━━━━━━`;
  const codeText = `${otpCode}`;

  try {
    const resultHeader = await sendWhatsappMessage(formattedPhone, headerText);
    const resultCode = await sendWhatsappMessage(formattedPhone, codeText);
    console.log(`\x1b[32m[Reset Password] WhatsApp messages sent to ${formattedPhone}. Status: ${resultHeader.statusCode}, ${resultCode.statusCode}\x1b[0m`);
    return { success: true, response: resultCode.body };
  } catch (error) {
    console.error(`\x1b[31m[Reset Password Error] Failed to send WhatsApp to ${formattedPhone}: ${error.message}\x1b[0m`);
    return { success: false, error: error.message };
  }
};

module.exports = {
  formatPhoneForWhatsapp,
  sendWhatsappMessage,
  sendOtpWhatsapp,
  sendResetPasswordWhatsapp
};
