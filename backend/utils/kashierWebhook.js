const crypto = require('crypto');
const { isProduction } = require('./securityConfig');

/**
 * Verifies Kashier webhook signature when KASHIER_WEBHOOK_SECRET is configured.
 * Also supports Kashier paymentKey hash pattern used on redirect callbacks.
 */
function verifyKashierWebhook(req) {
  const secret = process.env.KASHIER_WEBHOOK_SECRET;
  if (!secret) {
    return !isProduction();
  }

  const signature =
    req.headers['x-kashier-signature'] ||
    req.headers['x-signature'] ||
    req.body?.signature ||
    req.body?.hash;

  if (!signature) return false;

  const rawBody = req.rawBody || JSON.stringify(req.body);
  const expected = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');

  try {
    return crypto.timingSafeEqual(
      Buffer.from(String(signature)),
      Buffer.from(expected)
    );
  } catch {
    return String(signature) === expected;
  }
}

module.exports = { verifyKashierWebhook };
