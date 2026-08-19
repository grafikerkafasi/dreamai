# DreamAI

## Configuration

The Flutter client calls a separately-run Node service. It never contains an
OpenAI API key. Copy `.env.example` to `.env`, set `OPENAI_API_KEY`, and start
the backend locally with `npm run dev` (reads `.env`); use `GET /health` to
verify it is available. In production (e.g. Render), the host injects
environment variables directly, so it runs via plain `npm start` instead —
there is no `.env` file on the server.

Pass the backend URL to Flutter at launch:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=USE_DEMO_ANALYSIS=false
```

Use `http://10.0.2.2:3000` for an Android emulator; a physical device needs
your machine's reachable LAN address. `USE_DEMO_ANALYSIS` defaults to `true`,
which returns a canned local interpretation and never calls the backend —
pass `false` to actually exercise `/analyze` and the free/paid quota.

Run `npm test`, `flutter analyze`, and `flutter test` before shipping.

## Monetization: free tier + $5/month subscription

The first 3 dream interpretations per device are free; after that, a
subscription unlocks up to 30 per month. This is enforced **server-side**,
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

**Manual setup still needed (outside this repo) before this can go live:**
1. Create a RevenueCat account and project, add your iOS and Android apps.
2. In App Store Connect and Google Play Console, create a $5/month
   auto-renewing subscription product; attach both to a RevenueCat
   **entitlement** named `premium` (the ID `purchase_service.dart` checks)
   and a RevenueCat **offering** containing a monthly package.
3. Copy RevenueCat's public API keys and pass them at build/run time:
   `--dart-define=REVENUECAT_API_KEY_IOS=... --dart-define=REVENUECAT_API_KEY_ANDROID=...`
4. In RevenueCat's dashboard, add a webhook pointing at
   `https://<your-backend>/revenuecat-webhook`, and set an "Authorization
   header value" — put that same secret in the backend's `.env` as
   `REVENUECAT_WEBHOOK_AUTH` so the endpoint can reject spoofed requests.
5. Create a free [Turso](https://turso.tech) database (`turso db create
   dreamai`, then `turso db show dreamai --url` and `turso db tokens
   create dreamai` for the URL/token) and set `TURSO_DATABASE_URL` /
   `TURSO_AUTH_TOKEN` as environment variables on the host — without
   these, `usage_store.js` falls back to a local file that won't survive
   a redeploy on an ephemeral host.
6. Deploy the backend (e.g. to [Render](https://render.com)'s free web
   service tier) and set `OPENAI_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`,
   `TURSO_DATABASE_URL`, and `TURSO_AUTH_TOKEN` there as environment
   variables — the host runs `npm start`, which does not read `.env`.

Free and monthly limits are configurable via `FREE_DREAM_LIMIT` (default
3) and `MONTHLY_DREAM_LIMIT` (default 30) in `.env`.

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
