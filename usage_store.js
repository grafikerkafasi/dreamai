const path = require('node:path');
const { createClient } = require('@libsql/client');

// If TURSO_DATABASE_URL is set, this talks to a remote Turso database (real
// persistence across redeploys/restarts on hosts with an ephemeral
// filesystem, e.g. Render's free tier). Otherwise it falls back to a local
// SQLite file for development.
const client = process.env.TURSO_DATABASE_URL
  ? createClient({
      url: process.env.TURSO_DATABASE_URL,
      authToken: process.env.TURSO_AUTH_TOKEN,
    })
  : createClient({
      url: `file:${process.env.USAGE_DB_PATH || path.join(__dirname, 'usage.db')}`,
    });

// CREATE TABLE IF NOT EXISTS is a no-op against a table that already
// exists in production, so a new column added there (extra_credits)
// needs its own migration for installs that predate it — ALTER TABLE
// throws if the column is already present (fresh installs get it via
// CREATE TABLE above), which we simply ignore.
async function ensureExtraCreditsColumn() {
  try {
    await client.execute('ALTER TABLE usage ADD COLUMN extra_credits INTEGER NOT NULL DEFAULT 0');
  } catch (err) {
    if (!/duplicate column/i.test(err.message || '')) throw err;
  }
}

const ready = Promise.all([
  client.execute(`
    CREATE TABLE IF NOT EXISTS usage (
      device_id TEXT PRIMARY KEY,
      free_used INTEGER NOT NULL DEFAULT 0,
      subscribed INTEGER NOT NULL DEFAULT 0,
      period_start TEXT NOT NULL DEFAULT '',
      period_used INTEGER NOT NULL DEFAULT 0,
      extra_credits INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL DEFAULT ''
    )
  `).then(ensureExtraCreditsColumn),
  // Records every one-time credit-pack purchase we've already applied, so
  // crediting stays a no-op on retries — whether the same purchase reaches
  // us twice via the webhook, or via the /redeem-credits self-heal check
  // (see revenuecat_client.js) after the webhook already handled it.
  client.execute(`
    CREATE TABLE IF NOT EXISTS redeemed_purchases (
      purchase_id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      credits INTEGER NOT NULL,
      redeemed_at TEXT NOT NULL
    )
  `),
]);

function currentPeriod() {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
}

async function getOrCreateRow(deviceId) {
  await ready;
  const result = await client.execute({
    sql: 'SELECT * FROM usage WHERE device_id = ?',
    args: [deviceId],
  });
  if (result.rows.length > 0) return { ...result.rows[0] };

  await client.execute({
    sql: 'INSERT INTO usage (device_id, free_used, subscribed, period_start, period_used, extra_credits, updated_at) VALUES (?, 0, 0, ?, 0, 0, ?)',
    args: [deviceId, currentPeriod(), new Date().toISOString()],
  });
  return {
    device_id: deviceId,
    free_used: 0,
    subscribed: 0,
    period_start: currentPeriod(),
    period_used: 0,
    extra_credits: 0,
  };
}

function rollPeriodIfNeeded(row) {
  const period = currentPeriod();
  if (row.period_start !== period) {
    row.period_start = period;
    row.period_used = 0;
  }
  return row;
}

async function persist(row) {
  await client.execute({
    sql: `UPDATE usage
          SET free_used = ?, subscribed = ?, period_start = ?, period_used = ?, extra_credits = ?, updated_at = ?
          WHERE device_id = ?`,
    args: [
      row.free_used,
      row.subscribed,
      row.period_start,
      row.period_used,
      row.extra_credits,
      new Date().toISOString(),
      row.device_id,
    ],
  });
}

// Returns { allowed, reason, freeUsed, freeLimit, periodUsed, periodLimit,
// subscribed, extraCredits, useExtraCredit }. useExtraCredit tells the
// caller which counter recordSuccessfulAnalysis should decrement.
async function checkQuota(deviceId, freeLimit, monthlyLimit) {
  const row = rollPeriodIfNeeded(await getOrCreateRow(deviceId));
  const subscribed = Boolean(row.subscribed);
  const withinPlan = subscribed
    ? row.period_used < monthlyLimit
    : row.free_used < freeLimit;

  const allowed = withinPlan || row.extra_credits > 0;
  let reason = null;
  if (!allowed) {
    reason = subscribed ? 'MONTHLY_LIMIT_REACHED' : 'FREE_LIMIT_REACHED';
  }

  return {
    allowed,
    reason,
    freeUsed: row.free_used,
    freeLimit,
    periodUsed: row.period_used,
    periodLimit: monthlyLimit,
    subscribed,
    extraCredits: row.extra_credits,
    useExtraCredit: allowed && !withinPlan,
  };
}

async function getUsage(deviceId, freeLimit, monthlyLimit) {
  const row = rollPeriodIfNeeded(await getOrCreateRow(deviceId));
  await persist(row);
  return {
    subscribed: Boolean(row.subscribed),
    freeUsed: row.free_used,
    freeLimit,
    periodUsed: row.period_used,
    periodLimit: monthlyLimit,
    extraCredits: row.extra_credits,
  };
}

async function recordSuccessfulAnalysis(deviceId, useExtraCredit) {
  const row = rollPeriodIfNeeded(await getOrCreateRow(deviceId));
  if (useExtraCredit) {
    row.extra_credits = Math.max(0, row.extra_credits - 1);
  } else if (row.subscribed) {
    row.period_used += 1;
  } else {
    row.free_used += 1;
  }
  await persist(row);
}

// Applies a RevenueCat webhook event to a device's subscription state.
async function applySubscriptionEvent(deviceId, eventType) {
  const row = await getOrCreateRow(deviceId);
  const resettingEvents = ['INITIAL_PURCHASE', 'RENEWAL'];
  const activatingEvents = [...resettingEvents, 'UNCANCELLATION', 'PRODUCT_CHANGE'];
  const deactivatingEvents = ['EXPIRATION'];

  if (activatingEvents.includes(eventType)) {
    row.subscribed = 1;
    if (resettingEvents.includes(eventType)) {
      row.period_start = currentPeriod();
      row.period_used = 0;
    }
  } else if (deactivatingEvents.includes(eventType)) {
    row.subscribed = 0;
  }
  // CANCELLATION only means auto-renew was turned off; access continues
  // until the current period's EXPIRATION event arrives, so no DB change.

  await persist(row);
}

// Idempotently credits a one-time credit-pack purchase. Returns true if this
// call actually applied it (false if purchaseId was already redeemed).
async function creditExtraDreams(deviceId, purchaseId, productId, credits) {
  await ready;
  try {
    await client.execute({
      sql: 'INSERT INTO redeemed_purchases (purchase_id, device_id, product_id, credits, redeemed_at) VALUES (?, ?, ?, ?, ?)',
      args: [purchaseId, deviceId, productId, credits, new Date().toISOString()],
    });
  } catch (err) {
    // Primary key collision means this purchase was already redeemed.
    return false;
  }

  const row = await getOrCreateRow(deviceId);
  row.extra_credits += credits;
  await persist(row);
  return true;
}

// Reverses a previously-credited one-time purchase (RevenueCat's REFUND
// webhook event). Idempotent the same way creditExtraDreams is idempotent
// going the other direction: the delete only affects a row if this exact
// purchase was actually redeemed and hasn't already been reversed, so a
// duplicate REFUND webhook for the same purchase is a no-op. Returns true
// if credits were actually deducted (false means this wasn't a known
// credit-pack purchase, or it already was reversed).
async function revokeCreditPurchase(deviceId, purchaseId) {
  await ready;
  const found = await client.execute({
    sql: 'SELECT credits FROM redeemed_purchases WHERE purchase_id = ? AND device_id = ?',
    args: [purchaseId, deviceId],
  });
  if (found.rows.length === 0) return false;
  const credits = found.rows[0].credits;

  const deleted = await client.execute({
    sql: 'DELETE FROM redeemed_purchases WHERE purchase_id = ? AND device_id = ?',
    args: [purchaseId, deviceId],
  });
  if (deleted.rowsAffected === 0) return false; // raced with another delete

  const row = await getOrCreateRow(deviceId);
  row.extra_credits = Math.max(0, row.extra_credits - credits);
  await persist(row);
  return true;
}

module.exports = {
  checkQuota,
  getUsage,
  recordSuccessfulAnalysis,
  applySubscriptionEvent,
  creditExtraDreams,
  revokeCreditPurchase,
};
