const axios = require('axios');

// Direct fallback against RevenueCat's REST API for when the
// /revenuecat-webhook event was missed or hasn't arrived yet (e.g. the
// webhook was never configured in the RevenueCat dashboard, or Render's
// free-tier host was asleep when it fired). Only called right before we'd
// otherwise turn away a request as over the free quota, so a paying
// customer never gets stuck behind a stale local record.
async function isEntitledOnRevenueCat(deviceId) {
  const secretKey = process.env.REVENUECAT_SECRET_API_KEY;
  if (!secretKey) return false;

  try {
    const response = await axios.get(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(deviceId)}`,
      {
        headers: { Authorization: `Bearer ${secretKey}` },
        timeout: 8000,
      }
    );
    const entitlement = response.data?.subscriber?.entitlements?.premium;
    if (!entitlement) return false;
    // Entitlements without an expiration date (e.g. lifetime/non-subscription
    // grants) never lapse; subscriptions always carry an expires_date.
    if (!entitlement.expires_date) return true;
    return new Date(entitlement.expires_date).getTime() > Date.now();
  } catch (err) {
    console.error('RevenueCat live entitlement check failed:', err.response?.data || err.message);
    return false;
  }
}

module.exports = { isEntitledOnRevenueCat };
