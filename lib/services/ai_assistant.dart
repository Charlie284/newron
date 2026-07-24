import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../domain/news_models.dart';

class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.label,
    required this.subtitle,
  });

  final String id;
  final String label;
  final String subtitle;
}

class AiRequestException implements Exception {
  const AiRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AiAssistant {
  Future<List<AiModelOption>> loadModels();

  Future<AiBriefResult> createBrief({
    required String topic,
    required String model,
    required List<NewsArticle> articles,
  });

  Future<FactCheckResult> factCheck({
    required String topic,
    required String model,
    required String brief,
    required List<String> citationIds,
    required List<NewsArticle> articles,
  });

  Future<FactCheckResult> explore({
    required String model,
    required String question,
    required NewsArticle article,
  });

  void dispose() {}
}

class HttpAiAssistant implements AiAssistant {
  HttpAiAssistant({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const requestTimeout = Duration(seconds: 25);
  static const fallbackModels = <AiModelOption>[
    AiModelOption(
      id: 'google/gemma-4-31b-it:free',
      label: 'Gemma 4 31B',
      subtitle: 'Free model via the Newron gateway',
    ),
    AiModelOption(
      id: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super',
      subtitle: 'Free model via the Newron gateway',
    ),
    AiModelOption(
      id: 'minimax/minimax-m2.5:free',
      label: 'MiniMax M2.5',
      subtitle: 'Free model via the Newron gateway',
    ),
  ];

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<List<AiModelOption>> loadModels() async {
    try {
      final response = await _client
          .get(
            AppConfig.apiUri('models'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallbackModels;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['data'] is! List) {
        return fallbackModels;
      }
      final options = <AiModelOption>[];
      for (final item in payload['data'] as List) {
        if (item is! Map) {
          continue;
        }
        final id = '${item['id'] ?? ''}'.trim();
        if (!id.endsWith(':free') || !_safeModelId.hasMatch(id)) {
          continue;
        }
        options.add(
          AiModelOption(
            id: id,
            label: _modelLabel(id),
            subtitle: 'Free model via the Newron gateway',
          ),
        );
      }
      options.sort((a, b) => a.label.compareTo(b.label));
      return options.isEmpty
          ? fallbackModels
          : List.unmodifiable(options.take(40));
    } catch (_) {
      return fallbackModels;
    }
  }

  @override
  Future<AiBriefResult> createBrief({
    required String topic,
    required String model,
    required List<NewsArticle> articles,
  }) async {
    final allowedIds = articles.map((article) => article.id).toSet();
    final payload = await _post('brief', {
      'model': model,
      'topic': topic,
      'articles': articles.take(12).map(_articlePayload).toList(),
    });
    final content = _decodeModelContent(payload);
    final brief = normalizeAiText('${content['brief'] ?? ''}', maxLength: 1800);
    final citations = _stringList(
      content['citation_ids'],
    ).where(allowedIds.contains).toSet().toList(growable: false);
    if (brief.length < 40 || citations.isEmpty) {
      throw const AiRequestException(
        'The AI response was not grounded in the displayed sources. Try again.',
      );
    }

    final analyses = <String, ArticleAnalysis>{};
    final rawAnalyses = content['article_analyses'];
    if (rawAnalyses is List) {
      for (final item in rawAnalyses.whereType<Map>()) {
        final id = '${item['article_id'] ?? ''}';
        if (!allowedIds.contains(id)) {
          continue;
        }
        final label = _safeAnalysisLabel('${item['label'] ?? ''}');
        final reason = normalizeAiText(
          '${item['reason'] ?? ''}',
          maxLength: 280,
        );
        if (label == null || reason.isEmpty) {
          continue;
        }
        analyses[id] = ArticleAnalysis(
          score: ((item['score'] as num?)?.toDouble() ?? 0).clamp(-1, 1),
          label: label,
          reason: reason,
        );
      }
    }
    return AiBriefResult(
      brief: brief,
      citationIds: citations,
      articleAnalyses: Map.unmodifiable(analyses),
    );
  }

  @override
  Future<FactCheckResult> factCheck({
    required String topic,
    required String model,
    required String brief,
    required List<String> citationIds,
    required List<NewsArticle> articles,
  }) async {
    final allowedIds = articles.map((article) => article.id).toSet();
    final payload = await _post('fact-check', {
      'model': model,
      'topic': topic,
      'brief': brief,
      'citation_ids': citationIds,
      'articles': articles.take(12).map(_articlePayload).toList(),
    });
    return _groundedTextResult(payload, allowedIds);
  }

  @override
  Future<FactCheckResult> explore({
    required String model,
    required String question,
    required NewsArticle article,
  }) async {
    final payload = await _post('focus', {
      'model': model,
      'question': question,
      'article': _articlePayload(article),
    });
    return _groundedTextResult(payload, {article.id});
  }

  FactCheckResult _groundedTextResult(
    Map<String, dynamic> payload,
    Set<String> allowedIds,
  ) {
    final content = _decodeModelContent(payload);
    final summary = normalizeAiText(
      '${content['summary'] ?? ''}',
      maxLength: 1800,
    );
    final sourceIds = _stringList(
      content['source_ids'],
    ).where(allowedIds.contains).toSet().toList(growable: false);
    if (summary.length < 20 || sourceIds.isEmpty) {
      throw const AiRequestException(
        'The AI response did not cite the supplied reporting. Try again.',
      );
    }
    return FactCheckResult(summary: summary, sourceIds: sourceIds);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    http.Response response;
    try {
      response = await _client
          .post(
            AppConfig.apiUri(path),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const AiRequestException(
        'The AI request timed out. Your saved coverage is still available.',
      );
    } catch (_) {
      throw const AiRequestException(
        'The AI service could not be reached. Check the connection and retry.',
      );
    }
    if (response.statusCode == 429) {
      throw const AiRequestException(
        'The AI service is busy. Wait a moment, then retry.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AiRequestException(
        'The AI service rejected this request. The source articles remain available.',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      // Converted to the same user-facing validation failure below.
    }
    throw const AiRequestException('The AI service returned unreadable data.');
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

final _safeModelId = RegExp(r'^[a-zA-Z0-9._:/-]{1,120}$');

Map<String, dynamic> _articlePayload(NewsArticle article) {
  return {
    'id': article.id,
    'headline': article.headline,
    'summary': article.summary,
    'source': article.source,
    'url': article.url,
    'published_at': article.publishedAt?.toUtc().toIso8601String(),
  };
}

Map<String, dynamic> _decodeModelContent(Map<String, dynamic> payload) {
  if (payload.containsKey('brief') || payload.containsKey('summary')) {
    return payload;
  }
  final choices = payload['choices'];
  if (choices is! List || choices.isEmpty || choices.first is! Map) {
    throw const AiRequestException('The AI service returned no answer.');
  }
  final message = (choices.first as Map)['message'];
  if (message is! Map) {
    throw const AiRequestException('The AI service returned no answer.');
  }
  var content = '${message['content'] ?? ''}'.trim();
  content = content
      .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s*```$'), '')
      .trim();
  final firstBrace = content.indexOf('{');
  final lastBrace = content.lastIndexOf('}');
  if (firstBrace < 0 || lastBrace <= firstBrace) {
    throw const AiRequestException('The AI service returned unreadable data.');
  }
  try {
    final decoded = jsonDecode(content.substring(firstBrace, lastBrace + 1));
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
  } catch (_) {
    // Converted to a stable validation error below.
  }
  throw const AiRequestException('The AI service returned unreadable data.');
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _safeAnalysisLabel(String value) {
  const allowed = <String>{'Left', 'Center', 'Right', 'Mixed'};
  for (final label in allowed) {
    if (label.toLowerCase() == value.trim().toLowerCase()) {
      return label;
    }
  }
  return null;
}

String normalizeAiText(String value, {required int maxLength}) {
  var result = value
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (result.length > maxLength) {
    result = '${result.substring(0, maxLength).trimRight()}…';
  }
  return result;
}

String _modelLabel(String id) {
  var label = id.split('/').last.replaceAll(':free', '');
  label = label.replaceAll(RegExp(r'[-_.]+'), ' ');
  return label
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => word.length <= 2
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
