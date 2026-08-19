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

const ready = client.execute(`
  CREATE TABLE IF NOT EXISTS usage (
    device_id TEXT PRIMARY KEY,
    free_used INTEGER NOT NULL DEFAULT 0,
    subscribed INTEGER NOT NULL DEFAULT 0,
    period_start TEXT NOT NULL DEFAULT '',
    period_used INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT ''
  )
`);

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
    sql: 'INSERT INTO usage (device_id, free_used, subscribed, period_start, period_used, updated_at) VALUES (?, 0, 0, ?, 0, ?)',
    args: [deviceId, currentPeriod(), new Date().toISOString()],
  });
  return {
    device_id: deviceId,
    free_used: 0,
    subscribed: 0,
    period_start: currentPeriod(),
    period_used: 0,
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
          SET free_used = ?, subscribed = ?, period_start = ?, period_used = ?, updated_at = ?
          WHERE device_id = ?`,
    args: [
      row.free_used,
      row.subscribed,
      row.period_start,
      row.period_used,
      new Date().toISOString(),
      row.device_id,
    ],
  });
}

// Returns { allowed, reason, freeUsed, freeLimit, periodUsed, periodLimit, subscribed }
async function checkQuota(deviceId, freeLimit, monthlyLimit) {
  const row = rollPeriodIfNeeded(await getOrCreateRow(deviceId));
  const subscribed = Boolean(row.subscribed);

  if (subscribed) {
    const allowed = row.period_used < monthlyLimit;
    return {
      allowed,
      reason: allowed ? null : 'MONTHLY_LIMIT_REACHED',
      freeUsed: row.free_used,
      freeLimit,
      periodUsed: row.period_used,
      periodLimit: monthlyLimit,
      subscribed,
    };
  }

  const allowed = row.free_used < freeLimit;
  return {
    allowed,
    reason: allowed ? null : 'FREE_LIMIT_REACHED',
    freeUsed: row.free_used,
    freeLimit,
    periodUsed: row.period_used,
    periodLimit: monthlyLimit,
    subscribed,
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
  };
}

async function recordSuccessfulAnalysis(deviceId) {
  const row = rollPeriodIfNeeded(await getOrCreateRow(deviceId));
  if (row.subscribed) {
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

module.exports = { checkQuota, getUsage, recordSuccessfulAnalysis, applySubscriptionEvent };
