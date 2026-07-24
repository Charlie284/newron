import 'package:flutter/material.dart';

@immutable
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.section,
    required this.headline,
    required this.summary,
    required this.source,
    required this.url,
    required this.readTime,
    required this.publishedAt,
    this.accent = const Color(0xFFEE6C4D),
    this.leaningScore = 0,
    this.leaningLabel = 'Not analyzed',
    this.leaningReason = '',
  });

  final String id;
  final String section;
  final String headline;
  final String summary;
  final String source;
  final String url;
  final String readTime;
  final DateTime? publishedAt;
  final Color accent;
  final double leaningScore;
  final String leaningLabel;
  final String leaningReason;

  bool get hasAnalysis => leaningLabel != 'Not analyzed';

  NewsArticle copyWith({
    String? id,
    String? section,
    String? headline,
    String? summary,
    String? source,
    String? url,
    String? readTime,
    DateTime? publishedAt,
    Color? accent,
    double? leaningScore,
    String? leaningLabel,
    String? leaningReason,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      section: section ?? this.section,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      url: url ?? this.url,
      readTime: readTime ?? this.readTime,
      publishedAt: publishedAt ?? this.publishedAt,
      accent: accent ?? this.accent,
      leaningScore: leaningScore ?? this.leaningScore,
      leaningLabel: leaningLabel ?? this.leaningLabel,
      leaningReason: leaningReason ?? this.leaningReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'section': section,
      'headline': headline,
      'summary': summary,
      'source': source,
      'url': url,
      'readTime': readTime,
      'publishedAt': publishedAt?.toUtc().toIso8601String(),
      'accent': accent.toARGB32(),
      'leaningScore': leaningScore,
      'leaningLabel': leaningLabel,
      'leaningReason': leaningReason,
    };
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final headline = _cleanString(json['headline']);
    final source = _cleanString(json['source']);
    final url = _cleanString(json['url']);
    return NewsArticle(
      id: _cleanString(json['id']).isNotEmpty
          ? _cleanString(json['id'])
          : stableArticleId(source: source, url: url, headline: headline),
      section: _cleanString(json['section'], fallback: 'Top Stories'),
      headline: headline,
      summary: _cleanString(json['summary']),
      source: source,
      url: url,
      readTime: _cleanString(json['readTime'], fallback: '1 min read'),
      publishedAt: DateTime.tryParse(_cleanString(json['publishedAt'])),
      accent: Color((json['accent'] as num?)?.toInt() ?? 0xFFEE6C4D),
      leaningScore: ((json['leaningScore'] as num?)?.toDouble() ?? 0).clamp(
        -1,
        1,
      ),
      leaningLabel: _cleanString(
        json['leaningLabel'],
        fallback: 'Not analyzed',
      ),
      leaningReason: _cleanString(json['leaningReason']),
    );
  }
}

@immutable
class NewsDigest {
  const NewsDigest({
    required this.articles,
    required this.updatedAt,
    this.brief,
    this.briefCitationIds = const <String>[],
    this.usedModelInference = false,
    this.topic = 'Top Stories',
  });

  final String? brief;
  final List<String> briefCitationIds;
  final List<NewsArticle> articles;
  final bool usedModelInference;
  final DateTime updatedAt;
  final String topic;

  bool get isStale => DateTime.now().difference(updatedAt).inMinutes >= 30;

  NewsDigest copyWith({
    String? brief,
    bool clearBrief = false,
    List<String>? briefCitationIds,
    List<NewsArticle>? articles,
    bool? usedModelInference,
    DateTime? updatedAt,
    String? topic,
  }) {
    return NewsDigest(
      brief: clearBrief ? null : (brief ?? this.brief),
      briefCitationIds: clearBrief
          ? const <String>[]
          : (briefCitationIds ?? this.briefCitationIds),
      articles: articles ?? this.articles,
      usedModelInference: clearBrief
          ? false
          : (usedModelInference ?? this.usedModelInference),
      updatedAt: updatedAt ?? this.updatedAt,
      topic: topic ?? this.topic,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brief': brief,
      'briefCitationIds': briefCitationIds,
      'articles': articles.map((article) => article.toJson()).toList(),
      'usedModelInference': usedModelInference,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'topic': topic,
    };
  }

  factory NewsDigest.fromJson(Map<String, dynamic> json) {
    final rawArticles = json['articles'];
    final rawCitationIds = json['briefCitationIds'];
    return NewsDigest(
      brief: _nullableCleanString(json['brief']),
      briefCitationIds: rawCitationIds is List
          ? rawCitationIds
                .map((value) => _cleanString(value))
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      articles: rawArticles is List
          ? rawArticles
                .whereType<Map>()
                .map(
                  (value) => NewsArticle.fromJson(
                    value.map((key, item) => MapEntry('$key', item)),
                  ),
                )
                .where((article) => article.headline.isNotEmpty)
                .toList(growable: false)
          : const <NewsArticle>[],
      usedModelInference: json['usedModelInference'] == true,
      updatedAt:
          DateTime.tryParse(_cleanString(json['updatedAt'])) ?? DateTime.now(),
      topic: _cleanString(json['topic'], fallback: 'Top Stories'),
    );
  }
}

@immutable
class NewsLoadResult {
  const NewsLoadResult({
    required this.articles,
    required this.attemptedSources,
    required this.successfulSources,
    required this.failures,
    required this.loadedAt,
  });

  final List<NewsArticle> articles;
  final List<String> attemptedSources;
  final List<String> successfulSources;
  final Map<String, String> failures;
  final DateTime loadedAt;

  bool get hasPartialFailure =>
      successfulSources.isNotEmpty && failures.isNotEmpty;
}

@immutable
class AiBriefResult {
  const AiBriefResult({
    required this.brief,
    required this.citationIds,
    required this.articleAnalyses,
    required this.usedModelInference,
  });

  final String brief;
  final List<String> citationIds;
  final Map<String, ArticleAnalysis> articleAnalyses;
  final bool usedModelInference;
}

@immutable
class ArticleAnalysis {
  const ArticleAnalysis({
    required this.score,
    required this.label,
    required this.reason,
  });

  final double score;
  final String label;
  final String reason;
}

@immutable
class FactCheckResult {
  const FactCheckResult({
    required this.summary,
    required this.sourceIds,
    this.usedModelInference = true,
  });

  final String summary;
  final List<String> sourceIds;
  final bool usedModelInference;
}

String stableArticleId({
  required String source,
  required String url,
  required String headline,
}) {
  final value = '$source|$url|$headline'.toLowerCase();
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'article-${hash.toRadixString(16).padLeft(8, '0')}';
}

String _cleanString(Object? value, {String fallback = ''}) {
  final normalized = '${value ?? ''}'.trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableCleanString(Object? value) {
  final normalized = _cleanString(value);
  return normalized.isEmpty ? null : normalized;
}
