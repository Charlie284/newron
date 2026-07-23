import 'package:flutter/foundation.dart';

/// Resolves API endpoints without exposing browser requests to cross-origin
/// restrictions. Native builds keep using the hosted Worker directly, while
/// web builds use the same-origin `/api` gateway shipped with this project.
class AppConfig {
  const AppConfig._();

  static const String _defaultUpstreamApiBaseUrl =
      'https://royal-union-f92a.charlh048.workers.dev/v1';
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'NEWRON_API_BASE_URL',
  );

  static Uri apiUri(String path) {
    return resolveApiUri(
      path,
      isWeb: kIsWeb,
      pageUri: Uri.base,
      configuredBaseUrl: _configuredApiBaseUrl,
    );
  }

  static Uri rssUri(String feedUrl) {
    if (!kIsWeb) {
      return Uri.parse(feedUrl);
    }

    return apiUri('rss').replace(queryParameters: {'url': feedUrl});
  }

  @visibleForTesting
  static Uri resolveApiUri(
    String path, {
    required bool isWeb,
    required Uri pageUri,
    String configuredBaseUrl = '',
  }) {
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    final configuredBase = configuredBaseUrl.trim();

    if (configuredBase.isNotEmpty) {
      final normalizedBase = configuredBase.endsWith('/')
          ? configuredBase
          : '$configuredBase/';
      return Uri.parse(normalizedBase).resolve(cleanPath);
    }

    if (isWeb) {
      final origin = pageUri.replace(path: '/', query: null, fragment: null);
      return origin.resolve('api/$cleanPath');
    }

    return Uri.parse('$_defaultUpstreamApiBaseUrl/').resolve(cleanPath);
  }
}
