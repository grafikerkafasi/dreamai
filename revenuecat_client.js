const axios = require('axios');

// Direct fallback against RevenueCat's REST API (v2) for when the
// /revenuecat-webhook event was missed or hasn't arrived yet (e.g. the
// webhook was never configured in the RevenueCat dashboard, or Render's
// free-tier host was asleep when it fired). Only called right before we'd
// otherwise turn away a request as over the free quota, so a paying
// customer never gets stuck behind a stale local record.
//
// Secret keys issued today are v2-only (v1's /v1/subscribers/{id} rejects
// them with error code 7723), and v2 identifies entitlements by an opaque
// id (e.g. "entla2ea8433c5") rather than the human-readable identifier
// ("DreamAI Premium") shown in the dashboard — that identifier is only
// exposed as `lookup_key` on GET /v2/projects/{id}/entitlements, so we
// resolve it once and cache it for the life of the process.
const RC_API_BASE = 'https://api.revenuecat.com/v2';
const ENTITLEMENT_LOOKUP_KEY = 'DreamAI Premium';

let cachedProjectId = null;
let cachedEntitlementId = null;

async function resolveEntitlementId(secretKey) {
  if (cachedEntitlementId) return cachedEntitlementId;

  if (!cachedProjectId) {
    const projects = await axios.get(`${RC_API_BASE}/projects`, {
      headers: { Authorization: `Bearer ${secretKey}` },
      timeout: 8000,
    });
    cachedProjectId = projects.data?.items?.[0]?.id ?? null;
  }
  if (!cachedProjectId) return null;

  const entitlements = await axios.get(
    `${RC_API_BASE}/projects/${cachedProjectId}/entitlements`,
    { headers: { Authorization: `Bearer ${secretKey}` }, timeout: 8000 }
  );
  const match = entitlements.data?.items?.find(
    (e) => e.lookup_key === ENTITLEMENT_LOOKUP_KEY
  );
  cachedEntitlementId = match?.id ?? null;
  return cachedEntitlementId;
}

async function isEntitledOnRevenueCat(deviceId) {
  const secretKey = process.env.REVENUECAT_SECRET_API_KEY;
  if (!secretKey) return false;

  try {
    const entitlementId = await resolveEntitlementId(secretKey);
    if (!entitlementId || !cachedProjectId) return false;

    const response = await axios.get(
      `${RC_API_BASE}/projects/${cachedProjectId}/customers/${encodeURIComponent(deviceId)}/active_entitlements`,
      { headers: { Authorization: `Bearer ${secretKey}` }, timeout: 8000 }
    );
    const active = response.data?.items ?? [];
    return active.some((item) => item.entitlement_id === entitlementId);
  } catch (err) {
    console.error('RevenueCat live entitlement check failed:', err.response?.data || err.message);
    return false;
  }
}

module.exports = { isEntitledOnRevenueCat };
