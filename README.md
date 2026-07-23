# Newron

Newron is a research-augmented, AI-powered news aggregator built with Flutter. It consolidates news from over 70+ RSS sources and uses advanced AI models to provide smart briefings, bias analysis, and deep-dive research capabilities.

## Features

- **AI-Powered Briefings**: Get concise summaries of the day's top stories, world news, politics, and more.
- **Research-Augmented Summaries**: AI models proactively search the web and news APIs to provide current context and fill in reporting gaps.
- **Bias Analysis**: Visualize the political and social leaning of every article.
- **Highlight to "Go Deeper"**: Select any text in the app to trigger a targeted AI research thread on that specific topic.
- **Customizable AI Models**: Support for multiple free-tier models via OpenRouter or custom workers (e.g., Gemma 4 31B, Nemotron, MiniMax).
- **Cross-Platform**: Runs on Android, iOS, Web, macOS, Windows, and Linux.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- API Keys (Optional):
    - **TheNewsAPI**: [thenewsapi.com](https://www.thenewsapi.com/)
    - **NewsData.io**: [newsdata.io](https://newsdata.io/)

*Note: Newron is fully functional without these keys by using its built-in RSS sources and AI-augmented web research.*

### Configuration

If you choose to use additional news APIs:

1. Locate the `AppSecrets` class at the bottom of `lib/main.dart`.
2. Replace the placeholder strings with your own API tokens.

### Build & Run

```bash
flutter pub get
flutter run
```

### Deploy to Cloudflare Pages

The web build uses a same-origin Pages Function for AI and RSS requests. This
avoids browser CORS and mixed-content failures while native builds continue to
use the hosted API directly.

```bash
flutter build web --release
npx wrangler pages deploy
```

The included `wrangler.toml` publishes `build/web`, and `functions/api/[[path]].js`
provides `/api/models`, `/api/chat/completions`, and the allowlisted `/api/rss`
gateway. Set the optional `NEWRON_UPSTREAM_API_BASE_URL` Pages environment
variable if the upstream AI Worker moves.

For a different web host, deploy an equivalent same-origin gateway or build
with an absolute CORS-enabled gateway URL:

```bash
flutter build web --release \
  --dart-define=NEWRON_API_BASE_URL=https://api.example.com/v1
```

## Contributing

Newron is Free and Open Source Software. Contributions, bug reports, and feature requests are welcome!

## License

Distributed under the MIT License. See `LICENSE` for more information.
