/**
 * API Keys for external services & public endpoints
 *
 * ── Security Notes ─────────────────────────────────────────────────────────
 * Store this file securely. In production, consider:
 *   1. Encrypting this file with a deployment secret
 *   2. Loading keys from environment variables / vault instead
 *   3. Adding this file to .gitignore if not using env vars
 *
 * ── Usage ──────────────────────────────────────────────────────────────────
 *   const apiKeys = require('./config/api-keys');
 *   // apiKeys.landing.public  →  public key for the landing website
 * ────────────────────────────────────────────────────────────────────────────
 */

const apiKeys = {
  landing: {
    public: process.env.LANDING_API_KEY || null,
  },
};

module.exports = apiKeys;
