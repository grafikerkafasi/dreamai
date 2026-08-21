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
let cachedProductStoreIds = null; // opaque RevenueCat product id -> store_identifier

async function resolveProjectId(secretKey) {
  if (cachedProjectId) return cachedProjectId;
  const projects = await axios.get(`${RC_API_BASE}/projects`, {
    headers: { Authorization: `Bearer ${secretKey}` },
    timeout: 8000,
  });
  cachedProjectId = projects.data?.items?.[0]?.id ?? null;
  return cachedProjectId;
}

async function resolveEntitlementId(secretKey) {
  if (cachedEntitlementId) return cachedEntitlementId;

  const projectId = await resolveProjectId(secretKey);
  if (!projectId) return null;

  const entitlements = await axios.get(
    `${RC_API_BASE}/projects/${projectId}/entitlements`,
    { headers: { Authorization: `Bearer ${secretKey}` }, timeout: 8000 }
  );
  const match = entitlements.data?.items?.find(
    (e) => e.lookup_key === ENTITLEMENT_LOOKUP_KEY
  );
  cachedEntitlementId = match?.id ?? null;
  return cachedEntitlementId;
}

// Maps a RevenueCat one-time-purchase product id to how many bonus dream
// interpretations it grants, e.g. {"dreamai_credits_10": 10}. Configured via
// env rather than hardcoded so new packs/prices don't need a code change —
// see README for the product ids this expects you to create in App Store
// Connect / Play Console.
let cachedCreditProductMap = null;
function creditProductMap() {
  if (cachedCreditProductMap) return cachedCreditProductMap;
  try {
    cachedCreditProductMap = JSON.parse(process.env.CREDIT_PRODUCT_MAP || '{}');
  } catch (err) {
    console.error('CREDIT_PRODUCT_MAP is not valid JSON:', err.message);
    cachedCreditProductMap = {};
  }
  return cachedCreditProductMap;
}

// GET /purchases identifies each purchase's product by RevenueCat's opaque
// internal id (e.g. "prod742cbacf26"), not the App Store Connect / Play
// Console identifier ("dreamai_credits_10") that CREDIT_PRODUCT_MAP is
// keyed by — same opaque-id-vs-store-identifier split as entitlements
// above. GET /v2/projects/{id}/products exposes the real one as
// `store_identifier`, resolved once and cached.
async function resolveProductStoreIds(secretKey, projectId) {
  if (cachedProductStoreIds) return cachedProductStoreIds;

  const products = await axios.get(`${RC_API_BASE}/projects/${projectId}/products`, {
    headers: { Authorization: `Bearer ${secretKey}` },
    timeout: 8000,
  });
  cachedProductStoreIds = {};
  for (const product of products.data?.items ?? []) {
    if (product.id && product.store_identifier) {
      cachedProductStoreIds[product.id] = product.store_identifier;
    }
  }
  return cachedProductStoreIds;
}

// Looks up a customer's one-time purchases on RevenueCat and returns the
// ones that match a configured credit pack. The caller is expected to
// de-dupe against already-applied purchase ids (see
// usage_store.creditExtraDreams) before crediting.
async function fetchUnredeemedCreditPurchases(deviceId) {
  const secretKey = process.env.REVENUECAT_SECRET_API_KEY;
  const productMap = creditProductMap();
  if (!secretKey || Object.keys(productMap).length === 0) return [];

  try {
    const projectId = await resolveProjectId(secretKey);
    if (!projectId) return [];
    const storeIds = await resolveProductStoreIds(secretKey, projectId);

    const response = await axios.get(
      `${RC_API_BASE}/projects/${projectId}/customers/${encodeURIComponent(deviceId)}/purchases`,
      { headers: { Authorization: `Bearer ${secretKey}` }, timeout: 8000 }
    );
    const items = response.data?.items ?? [];

    return items
      .map((item) => {
        const opaqueProductId = item.product_id ?? item.store_product_id ?? null;
        const productId = opaqueProductId ? storeIds[opaqueProductId] : null;
        const purchaseId =
          item.id ?? item.transaction_id ?? item.store_transaction_id ?? null;
        const credits = productId ? productMap[productId] : undefined;
        return { purchaseId, productId, credits };
      })
      .filter((p) => p.purchaseId && p.productId && p.credits);
  } catch (err) {
    console.error('RevenueCat purchase lookup failed:', err.response?.data || err.message);
    return [];
  }
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

module.exports = {
  isEntitledOnRevenueCat,
  fetchUnredeemedCreditPurchases,
  creditProductMap,
};
