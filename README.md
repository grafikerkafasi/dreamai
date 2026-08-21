# DreamAI

## Configuration

The Flutter client calls a separately-run Node service. It never contains an
OpenAI API key. Copy `.env.example` to `.env`, set `OPENAI_API_KEY`, and start
the backend locally with `npm run dev` (reads `.env`); use `GET /health` to
verify it is available. In production (e.g. Render), the host injects
environment variables directly, so it runs via plain `npm start` instead —
there is no `.env` file on the server.

The backend is deployed at `https://dreamai-backend-mkit.onrender.com`
(Render free tier + a Turso database for persistent quota state — see
"Manual setup" below for how that's wired up). Pass a backend URL to
Flutter at launch:

```sh
flutter run --dart-define=API_BASE_URL=https://dreamai-backend-mkit.onrender.com --dart-define=USE_DEMO_ANALYSIS=false
```

For a locally-running backend instead, use `http://localhost:3000`
(`http://10.0.2.2:3000` for an Android emulator; a physical device needs
your machine's reachable LAN address). `USE_DEMO_ANALYSIS` defaults to
`true`, which returns a canned local interpretation and never calls the
backend — pass `false` to actually exercise `/analyze` and the free/paid
quota.

Run `npm test`, `flutter analyze`, and `flutter test` before shipping.

## Monetization: pricing (source of truth)

This is the current, canonical pricing for DreamAI — update this section
first if pricing changes, then bring the code in line with it:

- **DreamAI Pro:** $4.99/month → 50 dream interpretations/month
- **Get More Dreams** (one-time credit packs, no subscription needed):
  - 10 Dreams → $1.99 (`dreamai_credits_10`)
  - 30 Dreams → $4.99 (`dreamai_credits_30`)
  - 100 Dreams → $9.99 (`dreamai_credits_100`)

## Monetization: free tier + $4.99/month subscription

The first 3 dream interpretations per device are free; after that, a
subscription unlocks up to 50 per month. This is enforced **server-side**,
keyed by an anonymous per-install device ID (no login required), so
reinstalling the app doesn't reset the free count.

**How it works:**
- The Flutter app generates a UUID on first launch (`lib/services/device_id_service.dart`,
  stored via `shared_preferences`) and sends it as `X-Device-Id` on every
  `/analyze` and `/usage` call.
- `usage_store.js` keeps a small SQLite-compatible database mapping that
  device ID to its free-tier count and monthly subscribed count.
  `/analyze` checks and increments it; a request over the limit gets `402`
  and the app shows `lib/screens/paywall_screen.dart`. Locally this is a
  plain SQLite file (`usage.db`, git-ignored); in production it points at
  a [Turso](https://turso.tech) database instead (see below) so the count
  survives redeploys on hosts with an ephemeral filesystem.
- Subscriptions are sold as a native App Store / Play Store auto-renewing
  subscription via **RevenueCat** (`purchases_flutter`), not directly
  through the backend — Apple/Google require in-app purchase for this kind
  of digital content. RevenueCat calls `POST /revenuecat-webhook` on
  purchase/renewal/expiration so the backend's `subscribed` flag and
  monthly counter stay in sync.
- RevenueCat is web-unavailable by design (`purchase_service.dart` no-ops
  under `kIsWeb`); the free/paid quota still applies during web/demo
  testing, but there's no purchase UI on that target.
- The webhook can be missed or delayed (not yet configured in RevenueCat,
  Render's free tier asleep when it fires, etc.), which would otherwise
  paywall a customer who already paid. As a fallback, when `/analyze`
  finds a device over its free quota and not marked subscribed, it
  queries RevenueCat's REST API directly (`revenuecat_client.js`) before
  saying no; if that shows an active `DreamAI Premium` entitlement, it
  updates the local record and lets the request through. Requires
  `REVENUECAT_SECRET_API_KEY` on Render — without it, this check is
  silently skipped and the account depends on the webhook alone.

**Done:**
- ✅ Backend deployed to Render's free tier:
  `https://dreamai-backend-mkit.onrender.com` (repo:
  `github.com/grafikerkafasi/dreamai`, auto-deploys on push to `main`).
- ✅ Persistent quota storage on [Turso](https://turso.tech)
  (`TURSO_DATABASE_URL` / `TURSO_AUTH_TOKEN` set on Render) — survives
  redeploys, unlike a local SQLite file would on Render's ephemeral disk.
- ✅ `OPENAI_API_KEY` and `REVENUECAT_WEBHOOK_AUTH` set on Render; the
  webhook endpoint correctly rejects requests without the right
  `Authorization` header (verified live).

**Still needed before subscriptions can go live:**
1. Create a RevenueCat account and project, add your iOS and Android apps.
2. In App Store Connect and Google Play Console, create a $4.99/month
   auto-renewing subscription product; attach both to a RevenueCat
   **entitlement** whose exact Identifier is `DreamAI Premium` (matching
   `PurchaseService.entitlementId` in `purchase_service.dart` and the key
   `revenuecat_client.js` reads from the REST API — RevenueCat's
   Identifier field, not its Display Name) and a RevenueCat **offering**
   containing a monthly package.
3. Copy RevenueCat's public API keys and pass them at build/run time:
   `--dart-define=REVENUECAT_API_KEY_IOS=... --dart-define=REVENUECAT_API_KEY_ANDROID=...`
4. In RevenueCat's dashboard, add a webhook pointing at
   `https://dreamai-backend-mkit.onrender.com/revenuecat-webhook`, and set
   its "Authorization header value" to the same secret already set as
   `REVENUECAT_WEBHOOK_AUTH` on Render.
5. Copy RevenueCat's **secret** API key (Project settings > API keys,
   starts with `sk_` — not the public iOS/Android keys from step 3) and
   set it as `REVENUECAT_SECRET_API_KEY` on Render, so `/analyze` can
   self-heal a device's subscribed flag if the webhook above is ever
   missed or delayed.

Free and monthly limits are configurable via `FREE_DREAM_LIMIT` (default
3) and `MONTHLY_DREAM_LIMIT` (default 50) in `.env`.

## Monetization: one-time credit packs

Independent of the subscription, a user can buy a one-time pack of bonus
dream interpretations (`lib/screens/buy_credits_screen.dart`, linked from
the hamburger menu as "Get More Dreams") — useful for someone who burns
through their 50/month fast but doesn't want to wait for the next billing
period, or a free-tier user who wants a few more without subscribing.

**How it works:** mirrors the subscription path above rather than
inventing a new mechanism — same RevenueCat webhook (`NON_RENEWING_PURCHASE`
event) as the primary path, plus the same kind of live REST fallback (this
time via `POST /redeem-credits`, called right after `purchase_service.dart`
completes a purchase, so the balance updates immediately instead of
waiting on the webhook). Applying a purchase is idempotent — each RevenueCat
purchase id is recorded in `redeemed_purchases` before its credits are
added, so the webhook and the self-heal call can never double-credit the
same purchase. `/analyze` spends a credit only after the free/monthly
allowance is exhausted.

**⚠️ Not yet verified against a live purchase.** `revenuecat_client.js`'s
`fetchUnredeemedCreditPurchases` reads RevenueCat's `GET
/v2/projects/{id}/customers/{id}/purchases` and guesses at the purchase/
product id field names (`product_id`/`store_product_id`,
`id`/`transaction_id`/`store_transaction_id`) since no real purchase exists
yet to confirm the exact response shape — check Render's logs against a
real sandbox purchase before relying on this in production, the same way
today's entitlement-id and v1-vs-v2 API bugs only turned up once there was
real data to check against.

**Still needed before this can go live:**
1. In App Store Connect and Google Play Console, create one or more
   **consumable** (not auto-renewing) in-app purchase products — e.g.
   `dreamai_credits_10` for a 10-pack. Give each a clear title/description
   in the store listing ("10 Extra Dreams" / "10 more dream
   interpretations, no expiry") — the app shows those directly rather than
   hardcoding pack sizes.
2. In RevenueCat, add each as a **Non-Subscription** product and put them
   in a **new offering** whose Identifier is exactly `credits` (matching
   `PurchaseService.creditsOfferingId`) — separate from the `default`
   offering the subscription uses.
3. Set `CREDIT_PRODUCT_MAP` on Render to a JSON object mapping each
   product id to how many credits it grants, e.g.
   `{"dreamai_credits_10":10,"dreamai_credits_30":30,"dreamai_credits_100":100}`.
   This is what both the webhook handler and `/redeem-credits` use to know
   how many credits a purchase is worth — nothing is hardcoded in source,
   so adding a new pack later is just an env var edit. Update the pricing
   table at the top of this section too if amounts change.
4. Also update `dreamai_credits_10`/`_30`/`_100`'s store price tiers to
   $1.99/$4.99/$9.99 respectively when creating them.
5. The existing RevenueCat webhook (already pointed at
   `/revenuecat-webhook`, see the subscription section above) automatically
   covers `NON_RENEWING_PURCHASE` events too — no separate webhook needed.

## Contact email

The contact form posts to the Node service and sends to
`a.yasiny.yilmaz@gmail.com`. Configure `SMTP_HOST`, `SMTP_PORT`,
`SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, and a verified `SMTP_FROM` address in
`.env` before starting the server. The recipient can be overridden with
`CONTACT_RECIPIENT`.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
