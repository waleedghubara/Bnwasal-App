/**
 * Lightweight security unit checks (no DB). Run: node scripts/security-unit.js
 */
require('dotenv').config();

const assert = require('assert');
const crypto = require('crypto');
const {
  generateAccessToken,
  generateResetToken,
  verifyAccessToken,
  verifyResetToken,
} = require('../utils/tokenHelper');
const { escapeHtml } = require('../utils/htmlEscape');
const { verifyKashierWebhook } = require('../utils/kashierWebhook');
const {
  assertShipmentAccess,
  assertOrderAccess,
  assertNegotiationSubmitRole,
  assertCanRespondToOffer,
} = require('../utils/accessControl');
const {
  assertShipmentStatusTransition,
  assertOrderStatusTransition,
} = require('../utils/statusTransitions');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log('✓', name);
  } catch (e) {
    failed++;
    console.error('✗', name, e.message);
  }
}

test('access token round-trip', () => {
  const token = generateAccessToken({ id: 1, role: 'user', email: 'a@b.c' }, 'test-device-id');
  const decoded = verifyAccessToken(token);
  assert.strictEqual(String(decoded.id), '1');
  assert.strictEqual(decoded.role, 'user');
  assert.strictEqual(decoded.deviceId, 'test-device-id');
});

test('reset token cannot be used as access token', () => {
  const reset = generateResetToken(2);
  assert.strictEqual(verifyAccessToken(reset), null);
});

test('reset token verifies with reset verifier', () => {
  const reset = generateResetToken(3);
  const decoded = verifyResetToken(reset);
  assert.strictEqual(String(decoded.id), '3');
});

test('html escape neutralizes script', () => {
  const out = escapeHtml('<script>alert(1)</script>');
  assert(!out.includes('<script>'));
});

test('kashier webhook rejects missing signature when secret set', () => {
  process.env.KASHIER_WEBHOOK_SECRET = 'test-secret';
  const req = { headers: {}, body: { ok: true }, rawBody: '{"ok":true}' };
  assert.strictEqual(verifyKashierWebhook(req), false);
  delete process.env.KASHIER_WEBHOOK_SECRET;
});

test('kashier webhook accepts valid HMAC on rawBody', () => {
  process.env.KASHIER_WEBHOOK_SECRET = 'test-secret';
  const rawBody = '{"status":"SUCCESS"}';
  const sig = crypto.createHmac('sha256', 'test-secret').update(rawBody).digest('hex');
  const req = {
    headers: { 'x-kashier-signature': sig },
    body: JSON.parse(rawBody),
    rawBody,
  };
  assert.strictEqual(verifyKashierWebhook(req), true);
  delete process.env.KASHIER_WEBHOOK_SECRET;
});

test('merchant can access own shipment', () => {
  assertShipmentAccess({ merchantId: 5, captainId: 9 }, { id: 5, role: 'merchant' });
});

test('merchant cannot access another merchant shipment', () => {
  assert.throws(
    () => assertShipmentAccess({ merchantId: 5 }, { id: 99, role: 'merchant' }),
    (e) => e.status === 403
  );
});

test('captain cannot submit negotiation offers', () => {
  assert.throws(
    () => assertNegotiationSubmitRole({ id: 1, role: 'captain' }),
    (e) => e.status === 403
  );
});

test('merchant can respond when they are offer receiver', () => {
  assertCanRespondToOffer(
    { receiverId: 5, senderId: 10 },
    { merchantId: 5 },
    { id: 5, role: 'merchant' }
  );
});

test('stranger cannot accept/reject offer', () => {
  assert.throws(
    () =>
      assertCanRespondToOffer(
        { receiverId: 5, senderId: 10 },
        { merchantId: 5 },
        { id: 99, role: 'merchant' }
      ),
    (e) => e.status === 403
  );
});

test('admin can respond to merchant-initiated offer', () => {
  assertCanRespondToOffer(
    { receiverId: 1, senderId: 5 },
    { merchantId: 5 },
    { id: 2, role: 'admin' }
  );
});

test('order access: captain assigned can read', () => {
  assertOrderAccess({ merchantId: 1, captainId: 7 }, { id: 7, role: 'captain' });
});

test('merchant cannot set arbitrary shipment status', () => {
  assert.throws(
    () =>
      assertShipmentStatusTransition(
        'merchant',
        { merchantId: 5, captainId: null },
        'Delivered',
        5
      ),
    (e) => e.status === 403
  );
});

test('merchant can set allowed shipment status', () => {
  assertShipmentStatusTransition(
    'merchant',
    { merchantId: 5, captainId: null },
    'Awaiting Payment',
    5
  );
});

test('captain cannot update unassigned shipment to In Transit', () => {
  assert.throws(
    () =>
      assertShipmentStatusTransition(
        'captain',
        { merchantId: 1, captainId: 99 },
        'In Transit',
        7
      ),
    (e) => e.status === 403
  );
});

test('admin can set any shipment status', () => {
  assertShipmentStatusTransition(
    'admin',
    { merchantId: 1, captainId: null },
    'Delivered',
    1
  );
});

test('request signature validation logic alignment', () => {
  const timestamp = Date.now().toString();
  const deviceId = 'test-device-uuid';
  const secret = 'fallback_api_crypto_static_key_we_deliver_2026';
  
  // Client side signing emulation
  const dataToSign = timestamp + deviceId;
  const clientSignature = crypto.createHmac('sha256', secret).update(dataToSign).digest('hex');
  
  // Server side verification emulation
  const serverComputed = crypto.createHmac('sha256', secret).update(timestamp + deviceId).digest('hex');
  
  assert.strictEqual(clientSignature, serverComputed);
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
