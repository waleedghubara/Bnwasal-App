/**
 * Validates required secrets at startup (production-hardening).
 */
function assertSecurityConfig() {
  const isProd = process.env.NODE_ENV === 'production';

  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
    if (isProd) {
      throw new Error('JWT_SECRET must be set (min 32 chars) in production');
    }
    console.warn('⚠️  JWT_SECRET missing or short — using dev fallback (NOT for production)');
  }

  if (!process.env.JWT_REFRESH_SECRET || process.env.JWT_REFRESH_SECRET.length < 32) {
    if (isProd) {
      throw new Error('JWT_REFRESH_SECRET must be set (min 32 chars) in production');
    }
    console.warn('⚠️  JWT_REFRESH_SECRET missing or short — using dev fallback');
  }

  if (!process.env.RESET_JWT_SECRET || process.env.RESET_JWT_SECRET.length < 32) {
    if (isProd) {
      throw new Error('RESET_JWT_SECRET must be set (min 32 chars) in production');
    }
    console.warn('⚠️  RESET_JWT_SECRET missing — password reset tokens use dev fallback');
  }

  if (isProd) {
    const origins = (process.env.ALLOWED_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean);
    if (origins.length === 0) {
      throw new Error('ALLOWED_ORIGINS must list at least one origin in production');
    }
    if (process.env.UPLOADS_REQUIRE_AUTH !== '1') {
      throw new Error('UPLOADS_REQUIRE_AUTH=1 is required in production');
    }
    if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
      throw new Error('VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY required in production');
    }
    if (!process.env.KASHIER_WEBHOOK_SECRET) {
      throw new Error('KASHIER_WEBHOOK_SECRET must be set in production');
    }
    if (!process.env.LANDING_API_KEY || process.env.LANDING_API_KEY.length < 24) {
      throw new Error('LANDING_API_KEY must be set (min 24 chars) in production');
    }
    if (!process.env.API_CRYPTO_STATIC_KEY || process.env.API_CRYPTO_STATIC_KEY.length < 24) {
      throw new Error('API_CRYPTO_STATIC_KEY must be set (min 24 chars) in production');
    }
  }
}

function isProduction() {
  return process.env.NODE_ENV === 'production';
}

function devOnlyResponse(extra = {}) {
  if (isProduction()) return {};
  return extra;
}

module.exports = { assertSecurityConfig, isProduction, devOnlyResponse };
