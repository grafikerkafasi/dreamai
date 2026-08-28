const express = require('express');
const cors = require('cors');
const axios = require('axios');
const nodemailer = require('nodemailer');
const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const {
  checkQuota,
  getUsage,
  recordSuccessfulAnalysis,
  applySubscriptionEvent,
  creditExtraDreams,
  revokeCreditPurchase,
} = require('./usage_store');
const {
  isEntitledOnRevenueCat,
  fetchUnredeemedCreditPurchases,
  creditProductMap,
} = require('./revenuecat_client');

const app = express();
const port = Number(process.env.PORT || 3000);
const apiKey = process.env.OPENAI_API_KEY;
const allowedOrigin = process.env.ALLOWED_ORIGIN || true;
const contactRecipient = process.env.CONTACT_RECIPIENT || 'a.yasiny.yilmaz@gmail.com';
const freeLimit = Number(process.env.FREE_DREAM_LIMIT || 3);
const monthlyLimit = Number(process.env.MONTHLY_DREAM_LIMIT || 50);
const revenueCatWebhookAuth = process.env.REVENUECAT_WEBHOOK_AUTH;

// Render (and most PaaS hosts) sit behind a reverse proxy, so the real
// client IP only shows up in X-Forwarded-For; without this, every request
// looks like it comes from the same proxy IP and IP-based rate limiting
// below would either be useless or throw (express-rate-limit refuses to
// trust X-Forwarded-For until Express is told to).
app.set('trust proxy', 1);

app.use(cors({ origin: allowedOrigin }));
app.use(express.json({ limit: '16kb' }));

// /analyze is the one endpoint that costs real money per call (OpenAI), and
// device_id is just a client-supplied header with no verification behind
// it — anyone can mint a fresh one per request to get a free 3-analysis
// quota over and over. Two layers: per-device_id catches rapid abuse of a
// single identity; per-IP catches the "rotate device_id every request"
// bypass of that. Limits are generous for a real user (writing and reading
// a dream interpretation takes far longer than this allows) and tight for
// a script.
const analyzeDeviceLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.header('x-device-id') || ipKeyGenerator(req.ip),
  message: { error: 'Too many requests from this device. Please wait a moment and try again.' },
});
const analyzeIpLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please wait a moment and try again.' },
});

function readDeviceId(req, res) {
  const deviceId = req.header('x-device-id');
  if (!deviceId || typeof deviceId !== 'string' || deviceId.length < 8 || deviceId.length > 128) {
    res.status(400).json({ error: 'A valid X-Device-Id header is required.' });
    return null;
  }
  return deviceId;
}

app.get('/', (_req, res) => {
  res.json({ service: 'dream-ai-api', ok: true });
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, contactConfigured: Boolean(process.env.SMTP_HOST) });
});

app.get('/usage', async (req, res) => {
  const deviceId = readDeviceId(req, res);
  if (!deviceId) return;
  res.json(await getUsage(deviceId, freeLimit, monthlyLimit));
});

app.post('/revenuecat-webhook', async (req, res) => {
  if (revenueCatWebhookAuth) {
    if (req.header('authorization') !== revenueCatWebhookAuth) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }

  const event = req.body?.event;
  const deviceId = event?.app_user_id;
  const eventType = event?.type;
  if (typeof deviceId !== 'string' || typeof eventType !== 'string') {
    return res.status(400).json({ error: 'Malformed webhook payload.' });
  }

  if (eventType === 'NON_RENEWING_PURCHASE') {
    const productId = event?.product_id;
    const purchaseId = event?.transaction_id ?? event?.id;
    const credits = productId ? creditProductMap()[productId] : undefined;
    if (purchaseId && credits) {
      await creditExtraDreams(deviceId, String(purchaseId), productId, credits);
    }
  } else if (eventType === 'REFUND') {
    // Route by product, not by whether we find a matching redeemed
    // purchase — that keeps this correct (and idempotent in the right
    // direction) even on a duplicate REFUND webhook for the same
    // purchase: revokeCreditPurchase is itself a no-op once already
    // reversed, so it never falls through to also revoking a
    // subscription that was never part of this refund.
    const productId = event?.product_id;
    const purchaseId = event?.transaction_id ?? event?.id;
    const isCreditPack = productId && creditProductMap()[productId];
    if (isCreditPack && purchaseId) {
      await revokeCreditPurchase(deviceId, String(purchaseId));
    } else {
      // A subscription (or an unrecognized product) being refunded —
      // revoke access immediately rather than waiting for the period to
      // naturally expire.
      await applySubscriptionEvent(deviceId, 'EXPIRATION');
    }
  } else {
    await applySubscriptionEvent(deviceId, eventType);
  }
  res.status(200).json({ ok: true });
});

app.post('/redeem-credits', async (req, res) => {
  const deviceId = readDeviceId(req, res);
  if (!deviceId) return;

  const purchases = await fetchUnredeemedCreditPurchases(deviceId);
  for (const purchase of purchases) {
    await creditExtraDreams(
      deviceId,
      purchase.purchaseId,
      purchase.productId,
      purchase.credits,
    );
  }
  res.json(await getUsage(deviceId, freeLimit, monthlyLimit));
});

// Mirrors /redeem-credits, but for the subscription side: the RevenueCat
// webhook is the normal way `subscribed` gets flipped on, but it can lag
// a few seconds behind the purchase actually completing, and a plain
// GET /usage right after subscribing just reads whatever's already in
// the DB — no self-heal. The paywall calls this right after a successful
// purchase/restore so the total it shows doesn't depend on winning a
// race against the webhook.
app.post('/sync-subscription', async (req, res) => {
  const deviceId = readDeviceId(req, res);
  if (!deviceId) return;

  if (await isEntitledOnRevenueCat(deviceId)) {
    await applySubscriptionEvent(deviceId, 'INITIAL_PURCHASE');
  }
  res.json(await getUsage(deviceId, freeLimit, monthlyLimit));
});

function createMailTransport() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) return null;

  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: process.env.SMTP_SECURE === 'true',
    // Render's network has flaky/unroutable IPv6 for some hosts, which
    // otherwise manifests as the TCP connect just hanging until nodemailer's
    // own timeout ("Connection timeout") rather than failing fast.
    family: 4,
    connectionTimeout: 15000,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
}

app.post('/contact', async (req, res) => {
  const name = typeof req.body?.name === 'string' ? req.body.name.trim() : '';
  const email = typeof req.body?.email === 'string' ? req.body.email.trim() : '';
  const message = typeof req.body?.message === 'string' ? req.body.message.trim() : '';

  if (!name || !email || !message || !/^\S+@\S+\.\S+$/.test(email)) {
    return res.status(400).json({ error: 'Name, a valid email, and a message are required.' });
  }
  if (name.length > 120 || email.length > 254 || message.length > 5000) {
    return res.status(400).json({ error: 'One or more fields are too long.' });
  }
  // name lands in the email's From display name and Subject header; a
  // known class of nodemailer CVEs is CRLF/header injection via fields
  // like this, so reject embedded newlines rather than rely on the
  // library to sanitize them.
  if (/[\r\n]/.test(name)) {
    return res.status(400).json({ error: 'Name cannot contain line breaks.' });
  }

  const transporter = createMailTransport();
  if (!transporter) {
    return res.status(503).json({ error: 'Contact email is not configured yet.' });
  }

  try {
    await transporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      to: contactRecipient,
      replyTo: email,
      subject: `DreamAI contact form: ${name}`,
      text: `Name: ${name}\nEmail: ${email}\n\nMessage:\n${message}`,
    });
    return res.status(202).json({ ok: true });
  } catch (error) {
    console.error('Contact email failed:', error.message);
    return res.status(502).json({ error: 'Your message could not be sent. Please try again later.' });
  }
});

app.post('/analyze', analyzeIpLimiter, analyzeDeviceLimiter, async (req, res) => {
  const deviceId = readDeviceId(req, res);
  if (!deviceId) return;

  const userPrompt = typeof req.body?.prompt === 'string' ? req.body.prompt.trim() : '';

  if (!userPrompt) {
    return res.status(400).json({ error: 'A dream prompt is required.' });
  }
  if (userPrompt.length > 8000) {
    return res.status(400).json({ error: 'Dream prompt is too long.' });
  }
  if (!apiKey) {
    console.error('OPENAI_API_KEY is not configured.');
    return res.status(503).json({ error: 'The analysis service is not configured.' });
  }

  let quota = await checkQuota(deviceId, freeLimit, monthlyLimit);
  if (!quota.allowed) {
    // The local record may be stale if a RevenueCat webhook was missed or
    // hasn't arrived yet (subscription, or a one-time credit-pack
    // purchase); double-check directly before turning away a paying
    // customer.
    let healed = false;
    if (quota.reason === 'FREE_LIMIT_REACHED' && (await isEntitledOnRevenueCat(deviceId))) {
      await applySubscriptionEvent(deviceId, 'INITIAL_PURCHASE');
      healed = true;
    }
    const purchases = await fetchUnredeemedCreditPurchases(deviceId);
    for (const purchase of purchases) {
      const applied = await creditExtraDreams(
        deviceId,
        purchase.purchaseId,
        purchase.productId,
        purchase.credits,
      );
      if (applied) healed = true;
    }
    if (healed) {
      quota = await checkQuota(deviceId, freeLimit, monthlyLimit);
    }
  }
  if (!quota.allowed) {
    const resetDateLabel = quota.periodResetsAt
      ? new Date(`${quota.periodResetsAt}T00:00:00Z`).toLocaleDateString('en-US', {
          month: 'long',
          day: 'numeric',
          year: 'numeric',
          timeZone: 'UTC',
        })
      : null;
    return res.status(402).json({
      error: quota.reason === 'MONTHLY_LIMIT_REACHED'
        ? `Monthly dream limit reached. It resets on ${resetDateLabel}.`
        : 'Your free dream interpretations are used up. Subscribe for more.',
      code: quota.reason,
      freeUsed: quota.freeUsed,
      freeLimit: quota.freeLimit,
      periodUsed: quota.periodUsed,
      periodLimit: quota.periodLimit,
      subscribed: quota.subscribed,
      extraCredits: quota.extraCredits,
      periodResetsAt: quota.periodResetsAt,
    });
  }

  try {
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'You are a reflective, creative dream interpreter. Your interpretations are for entertainment and self-reflection only — never present them as medical, mental-health, psychological, or professional advice, and never claim a clinical or diagnostic role.' },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.5,
        max_tokens: 300
      },
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        timeout: 30000,
      }
    );

    const result = response.data?.choices?.[0]?.message?.content?.trim();
    if (!result) {
      throw new Error('OpenAI returned an empty response.');
    }
    await recordSuccessfulAnalysis(deviceId, quota.useExtraCredit);
    return res.json({ result });
  } catch (err) {
    console.error(err.response?.data || err.message);
    const status = err.response?.status;
    if (status === 401 || status === 429) {
      return res.status(status).json({ error: 'The analysis service is temporarily unavailable.' });
    }
    return res.status(502).json({ error: 'Unable to analyze the dream right now.' });
  }
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
