import 'package:flutter_test/flutter_test.dart';
import 'package:newron/app_config.dart';

void main() {
  group('AppConfig', () {
    test('uses the same deployment origin for web API requests', () {
      final uri = AppConfig.resolveApiUri(
        'chat/completions',
        isWeb: true,
        pageUri: Uri.parse('https://news.example.com/reader?topic=world'),
      );

      expect(uri, Uri.parse('https://news.example.com/api/chat/completions'));
    });

    test('keeps native API requests on the hosted worker', () {
      final uri = AppConfig.resolveApiUri(
        '/models',
        isWeb: false,
        pageUri: Uri.parse('file:///app/'),
      );

      expect(
        uri,
        Uri.parse('https://royal-union-f92a.charlh048.workers.dev/v1/models'),
      );
    });

    test('honors an explicit API base URL on every platform', () {
      final uri = AppConfig.resolveApiUri(
        'models',
        isWeb: true,
        pageUri: Uri.parse('https://news.example.com/'),
        configuredBaseUrl: 'https://api.example.com/newron/v1',
      );

      expect(uri, Uri.parse('https://api.example.com/newron/v1/models'));
    });
  });
}
