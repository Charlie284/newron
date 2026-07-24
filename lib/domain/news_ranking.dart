import 'news_models.dart';

List<NewsArticle> rankAndDiversifyArticles(
  Iterable<NewsArticle> input, {
  DateTime? now,
  int limit = 30,
}) {
  final clock = now ?? DateTime.now();
  final uniqueByUrl = <String, NewsArticle>{};
  final seenHeadlines = <String>{};

  for (final article in input) {
    final headlineKey = _normalizeHeadline(article.headline);
    if (headlineKey.isEmpty || !seenHeadlines.add(headlineKey)) {
      continue;
    }
    final urlKey = _normalizeUrl(article.url);
    if (urlKey.isEmpty || uniqueByUrl.containsKey(urlKey)) {
      continue;
    }
    uniqueByUrl[urlKey] = article;
  }

  final sorted = uniqueByUrl.values.toList()
    ..sort((a, b) {
      final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

  final freshCutoff = clock.subtract(const Duration(days: 10));
  final fresh = sorted
      .where(
        (article) =>
            article.publishedAt == null ||
            !article.publishedAt!.isBefore(freshCutoff),
      )
      .toList();
  final candidates = fresh.length >= 8 ? fresh : sorted;

  final bySource = <String, List<NewsArticle>>{};
  for (final article in candidates) {
    bySource.putIfAbsent(article.source, () => <NewsArticle>[]).add(article);
  }

  final diversified = <NewsArticle>[];
  var round = 0;
  while (diversified.length < limit) {
    var added = false;
    for (final articles in bySource.values) {
      if (round < articles.length) {
        diversified.add(articles[round]);
        added = true;
        if (diversified.length == limit) {
          break;
        }
      }
    }
    if (!added) {
      break;
    }
    round += 1;
  }
  return List.unmodifiable(diversified);
}

String _normalizeHeadline(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) {
    return '';
  }
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere(
      (key, _) =>
          key.toLowerCase().startsWith('utm_') ||
          const {
            'fbclid',
            'gclid',
            'mc_cid',
            'mc_eid',
          }.contains(key.toLowerCase()),
    );
  return uri
      .replace(fragment: '', queryParameters: query.isEmpty ? null : query)
      .toString()
      .replaceFirst(RegExp(r'/$'), '');
}
