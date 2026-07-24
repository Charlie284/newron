# Newron

Newron is a source-first Flutter news reader. It selects a bounded set of RSS
feeds from a catalog of 70+, parses publication dates, removes duplicates,
balances publishers, and links every story to its original report.

AI is optional. Startup and refresh do not generate AI requests. When a user
chooses **Generate AI brief**, **Fact check**, or **Explore**, the app sends the
displayed article metadata through Newron's fixed-task gateway. The gateway
does not expose a general chat proxy, disables outside research in its prompt,
and requires the model to cite displayed article IDs. Model output can still be
wrong, so the UI keeps original reporting visible and labels AI analysis as
interpretive.

## What is implemented

- Dated RSS and Atom parsing with HTTPS-only configured feeds
- Bounded refreshes: at most 12 feeds, six concurrent requests, five seconds
  per feed
- Freshness ranking, URL/headline de-duplication, and publisher diversity
- Partial-failure, offline, stale-cache, loading, and empty states
- Linked article cards with publication time and source
- Opt-in source-grounded briefing, framing analysis, fact-check, and exploration
- Compact local cache without downloaded article bodies
- Adaptive mobile/desktop layout, 48 px/dp controls, labels, focus, and dark mode
- Cloudflare Pages gateway with schema/size/time limits, HTTPS allowlisting,
  redirect revalidation, security headers, and rate-limit support

## Run locally

Requirements: Flutter stable and Node.js 22 or newer.

```bash
flutter pub get
flutter test
flutter run
```

Native builds use `https://app.newron.clh.lol/api` for optional AI tasks and
fetch the configured HTTPS feeds directly. Override the gateway when needed:

```bash
flutter run --dart-define=NEWRON_API_BASE_URL=https://example.com/api
```

The web app needs the Pages Function at `/api`; a bare Flutter development
server cannot provide it. Build first, install the pinned root dev dependency,
then run Pages locally:

```bash
pnpm install
pnpm run build:web
pnpm run dev:web
```

## Verify

```bash
flutter analyze
flutter test
node --test test/web_gateway_test.mjs

cd docs/site
npm ci
npm run lint
npm run build
```

## Deploy the web app

`wrangler.toml` publishes `build/web` and `functions/api/[[path]].js` provides
`/api/models`, `/api/brief`, `/api/fact-check`, `/api/focus`, and the
allowlisted `/api/rss` gateway.

```bash
pnpm install
pnpm run build:web
pnpm run deploy:web
```

Optional Pages environment/binding configuration:

- `NEWRON_UPSTREAM_API_BASE_URL`: replaces the default upstream model API.
- `NEWRON_RATE_LIMITER`: a Cloudflare rate-limiter binding. Without the
  binding, the function applies a best-effort per-isolate fallback limit.

## Android release signing

Release builds never use Flutter's shared debug key. Supply all four values in
the release environment to produce a signed artifact:

```bash
export NEWRON_KEYSTORE_PATH=/absolute/path/to/upload-keystore.jks
export NEWRON_KEYSTORE_PASSWORD='...'
export NEWRON_KEY_ALIAS='...'
export NEWRON_KEY_PASSWORD='...'
flutter build appbundle --release
```

Without those values Gradle intentionally emits an unsigned release artifact.
Do not commit a keystore or its passwords.

## Privacy boundary

Saved briefings stay in local preferences. AI actions send article titles,
source names, summaries, URLs, timestamps, and the requested task to the
gateway and selected model provider. Newron does not claim that this traffic is
local-only or that AI output is independently verified.

## License

MIT — see [LICENSE](LICENSE).
