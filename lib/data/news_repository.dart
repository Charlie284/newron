import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../app_config.dart';
import '../domain/news_classifier.dart';
import '../domain/news_models.dart';
import '../domain/news_ranking.dart';
import 'rss_sources.dart';

abstract class NewsRepository {
  Future<NewsLoadResult> load(String topic);

  void dispose() {}
}

class RssNewsRepository implements NewsRepository {
  RssNewsRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _maxSourcesPerLoad = 12;
  static const _maxItemsPerSource = 4;
  static const _maxFeedBytes = 2 * 1024 * 1024;
  static const _concurrency = 6;
  static const _feedTimeout = Duration(seconds: 5);

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<NewsLoadResult> load(String topic) async {
    final selected = selectSourcesForTopic(topic);
    final queue = Queue<RssSource>.from(selected);
    final articles = <NewsArticle>[];
    final successfulSources = <String>[];
    final failures = <String, String>{};

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final source = queue.removeFirst();
        try {
          final sourceArticles = await _fetchSource(source);
          if (sourceArticles.isEmpty) {
            failures[source.name] = 'No readable items were returned.';
          } else {
            articles.addAll(sourceArticles);
            successfulSources.add(source.name);
          }
        } on TimeoutException {
          failures[source.name] = 'Timed out.';
        } on FormatException {
          failures[source.name] = 'The feed format was not readable.';
        } catch (_) {
          failures[source.name] = 'Could not connect.';
        }
      }
    }

    await Future.wait(
      List.generate(selected.length.clamp(0, _concurrency), (_) => worker()),
    );

    final ranked = rankAndDiversifyArticles(articles);
    return NewsLoadResult(
      articles: ranked,
      attemptedSources: selected.map((source) => source.name).toList(),
      successfulSources: List.unmodifiable(successfulSources),
      failures: Map.unmodifiable(failures),
      loadedAt: DateTime.now(),
    );
  }

  Future<List<NewsArticle>> _fetchSource(RssSource source) async {
    final response = await _client
        .get(
          AppConfig.rssUri(source.feedUrl),
          headers: const {
            'Accept':
                'application/atom+xml, application/rss+xml, application/xml, text/xml',
          },
        )
        .timeout(_feedTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('Feed returned ${response.statusCode}');
    }
    if (response.bodyBytes.length > _maxFeedBytes) {
      throw const FormatException('Feed exceeds the response limit');
    }

    final xmlText = utf8.decode(response.bodyBytes, allowMalformed: true);
    return parseFeed(source, xmlText).take(_maxItemsPerSource).toList();
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

List<RssSource> selectSourcesForTopic(String topic) {
  final chosen = <RssSource>[];

  void add(RssSource source) {
    if (chosen.length < RssNewsRepository._maxSourcesPerLoad &&
        !chosen.any((candidate) => candidate.feedUrl == source.feedUrl)) {
      chosen.add(source);
    }
  }

  if (topic == 'Top Stories') {
    // First take one featured source per editorial category so the briefing is
    // not dominated by whichever publishers happen to appear first in a list.
    for (final category in newsCategories.skip(1)) {
      for (final source in rssSources) {
        if (source.featured && source.topic == category) {
          add(source);
          break;
        }
      }
    }
    for (final source in rssSources.where((source) => source.featured)) {
      add(source);
    }
  } else {
    for (final source in rssSources.where(
      (source) => source.topic == topic && source.featured,
    )) {
      add(source);
    }
    for (final source in rssSources.where((source) => source.topic == topic)) {
      add(source);
    }
    for (final source in rssSources.where(
      (source) => source.topic == 'Top Stories' && source.featured,
    )) {
      add(source);
    }
  }
  return List.unmodifiable(chosen);
}

List<NewsArticle> parseFeed(RssSource source, String xmlText) {
  final document = XmlDocument.parse(xmlText);
  final items = document.descendants
      .whereType<XmlElement>()
      .where((element) => const {'item', 'entry'}.contains(element.name.local))
      .take(12);
  final parsed = <NewsArticle>[];

  for (final item in items) {
    final headline = _elementText(item, const ['title']);
    final rawLink = _itemLink(item);
    final link = _safeArticleUrl(rawLink);
    if (headline.isEmpty || link.isEmpty) {
      continue;
    }

    final rawSummary = _elementText(item, const [
      'description',
      'summary',
      'encoded',
      'content',
    ]);
    final summary = sanitizeFeedText(rawSummary, maxCharacters: 520);
    final dateText = _elementText(item, const [
      'pubDate',
      'published',
      'updated',
      'date',
    ]);
    final publishedAt = parseFeedDate(dateText);
    final section = classifyArticle(
      headline: headline,
      summary: summary,
      sourceTopic: source.topic,
    );

    parsed.add(
      NewsArticle(
        id: stableArticleId(source: source.name, url: link, headline: headline),
        section: section,
        headline: sanitizeFeedText(headline, maxCharacters: 240),
        summary: summary.isEmpty
            ? 'Open the original report for the full story.'
            : summary,
        source: source.name,
        url: link,
        readTime: estimateReadTime(summary),
        publishedAt: publishedAt,
      ),
    );
  }

  return parsed;
}

String _elementText(XmlElement parent, Iterable<String> localNames) {
  for (final element in parent.descendants.whereType<XmlElement>()) {
    if (localNames.contains(element.name.local) &&
        element.innerText.trim().isNotEmpty) {
      return element.innerText.trim();
    }
  }
  return '';
}

String _itemLink(XmlElement item) {
  for (final element in item.descendants.whereType<XmlElement>()) {
    if (element.name.local != 'link') {
      continue;
    }
    final relation = element.getAttribute('rel');
    final href = element.getAttribute('href');
    if (href != null && (relation == null || relation == 'alternate')) {
      return href.trim();
    }
    if (element.innerText.trim().isNotEmpty) {
      return element.innerText.trim();
    }
  }
  return _elementText(item, const ['guid']);
}

String _safeArticleUrl(String value) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null || !parsed.hasAuthority) {
    return '';
  }
  if (parsed.scheme == 'http') {
    return parsed.replace(scheme: 'https').toString();
  }
  return parsed.scheme == 'https' ? parsed.toString() : '';
}

String sanitizeFeedText(String value, {required int maxCharacters}) {
  var normalized = value
      .replaceAll(
        RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAllMapped(
        RegExp(r'&#(?:x([0-9a-f]+)|(\d+));?', caseSensitive: false),
        (match) {
          final codePoint = match.group(1) != null
              ? int.tryParse(match.group(1)!, radix: 16)
              : int.tryParse(match.group(2)!);
          return codePoint != null && codePoint > 0 && codePoint <= 0x10ffff
              ? String.fromCharCode(codePoint)
              : ' ';
        },
      )
      .replaceAllMapped(
        RegExp(r'&([a-z]+);?', caseSensitive: false),
        (match) =>
            _namedHtmlEntities[match.group(1)!.toLowerCase()] ??
            match.group(0)!,
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.length > maxCharacters) {
    normalized = '${normalized.substring(0, maxCharacters).trimRight()}…';
  }
  return normalized;
}

const _namedHtmlEntities = <String, String>{
  'amp': '&',
  'apos': "'",
  'gt': '>',
  'hellip': '…',
  'ldquo': '“',
  'lsquo': '‘',
  'lt': '<',
  'mdash': '—',
  'nbsp': ' ',
  'ndash': '–',
  'quot': '"',
  'rdquo': '”',
  'rsquo': '’',
};

DateTime? parseFeedDate(String value) {
  final clean = value.trim();
  if (clean.isEmpty) {
    return null;
  }
  final iso = DateTime.tryParse(clean);
  if (iso != null) {
    return iso.toUtc();
  }

  final match = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?\s+([A-Za-z]{1,5}|[+-]\d{4})',
  ).firstMatch(clean);
  if (match == null) {
    return null;
  }
  const months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) {
    return null;
  }
  var result = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.tryParse(match.group(6) ?? '') ?? 0,
  );
  final zone = match.group(7)!.toUpperCase();
  const namedOffsets = <String, int>{
    'UT': 0,
    'UTC': 0,
    'GMT': 0,
    'Z': 0,
    'EST': -5 * 60,
    'EDT': -4 * 60,
    'CST': -6 * 60,
    'CDT': -5 * 60,
    'MST': -7 * 60,
    'MDT': -6 * 60,
    'PST': -8 * 60,
    'PDT': -7 * 60,
  };
  int offsetMinutes;
  if (RegExp(r'^[+-]\d{4}$').hasMatch(zone)) {
    final sign = zone.startsWith('-') ? -1 : 1;
    offsetMinutes =
        sign *
        (int.parse(zone.substring(1, 3)) * 60 +
            int.parse(zone.substring(3, 5)));
  } else {
    offsetMinutes = namedOffsets[zone] ?? 0;
  }
  result = result.subtract(Duration(minutes: offsetMinutes));
  return result;
}

String estimateReadTime(String text) {
  final words = text.trim().isEmpty
      ? 0
      : text.trim().split(RegExp(r'\s+')).length;
  final minutes = (words / 220).ceil().clamp(1, 15);
  return '$minutes min read';
}
