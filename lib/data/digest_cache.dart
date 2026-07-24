import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/news_models.dart';

abstract class DigestCache {
  Future<NewsDigest?> read(String topic);

  Future<void> write(NewsDigest digest);

  Future<void> clear();
}

class SharedPreferencesDigestCache implements DigestCache {
  static const _prefix = 'newron_digest_v2_';
  static const _maxCacheAge = Duration(days: 2);
  static const _maxSerializedBytes = 256 * 1024;

  @override
  Future<NewsDigest?> read(String topic) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(topic));
    if (raw == null || raw.length > _maxSerializedBytes) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final digest = NewsDigest.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
      if (DateTime.now().difference(digest.updatedAt) > _maxCacheAge) {
        return null;
      }
      return digest;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(NewsDigest digest) async {
    final preferences = await SharedPreferences.getInstance();
    var value = jsonEncode(digest.toJson());
    if (utf8.encode(value).length > _maxSerializedBytes) {
      value = jsonEncode(
        digest.copyWith(articles: digest.articles.take(20).toList()).toJson(),
      );
    }
    await preferences.setString(_key(digest.topic), value);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where((key) => key.startsWith(_prefix));
    await Future.wait(keys.map(preferences.remove));
  }

  String _key(String topic) {
    final slug = topic.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    return '$_prefix$slug';
  }
}

class SettingsStore {
  static const _modelKey = 'newron_selected_model_v2';

  Future<String?> readModel() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_modelKey);
  }

  Future<void> writeModel(String modelId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modelKey, modelId);
  }
}
