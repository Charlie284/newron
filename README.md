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

## Contributing

Newron is Free and Open Source Software. Contributions, bug reports, and feature requests are welcome!

## License

Distributed under the MIT License. See `LICENSE` for more information.
