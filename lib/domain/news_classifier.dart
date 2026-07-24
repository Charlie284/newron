const _categoryTerms = <String, Map<String, int>>{
  'World': {
    'international': 2,
    'global': 1,
    'diplomatic': 2,
    'foreign ministry': 3,
    'united nations': 3,
    'ukraine': 3,
    'russia': 2,
    'china': 2,
    'gaza': 3,
    'israel': 2,
    'europe': 2,
    'africa': 2,
    'asia': 2,
  },
  'Politics': {
    'election': 3,
    'congress': 3,
    'senate': 3,
    'house': 1,
    'president': 2,
    'governor': 2,
    'campaign': 3,
    'democrat': 2,
    'republican': 2,
    'parliament': 2,
    'vote': 2,
    'ballot': 2,
  },
  'Business': {
    'business': 2,
    'market': 2,
    'stocks': 3,
    'economy': 3,
    'economic': 2,
    'earnings': 3,
    'company': 1,
    'trade': 2,
    'inflation': 3,
    'bank': 2,
    'merger': 3,
    'tariff': 2,
  },
  'Technology': {
    'technology': 3,
    'tech': 2,
    'software': 3,
    'cybersecurity': 3,
    'artificial intelligence': 4,
    'ai': 3,
    'robot': 2,
    'chip': 2,
    'semiconductor': 3,
    'startup': 2,
    'smartphone': 3,
  },
  'Science': {
    'science': 3,
    'scientist': 2,
    'research': 2,
    'space': 2,
    'nasa': 3,
    'climate': 2,
    'physics': 3,
    'biology': 3,
    'study': 1,
    'discovery': 2,
  },
  'Health': {
    'health': 3,
    'medical': 3,
    'medicine': 3,
    'hospital': 2,
    'disease': 2,
    'vaccine': 3,
    'doctor': 2,
    'patient': 2,
    'public health': 4,
  },
  'Sports': {
    'sports': 3,
    'game': 1,
    'match': 2,
    'team': 1,
    'league': 2,
    'championship': 3,
    'football': 3,
    'basketball': 3,
    'baseball': 3,
    'soccer': 3,
    'formula 1': 4,
    'grand prix': 4,
  },
  'Policy': {
    'policy': 3,
    'regulation': 3,
    'legislation': 3,
    'lawmakers': 2,
    'public spending': 3,
    'zoning': 2,
    'ordinance': 2,
  },
};

String classifyArticle({
  required String headline,
  required String summary,
  required String sourceTopic,
}) {
  final normalized = _normalize('$headline $summary');
  final padded = ' $normalized ';
  final scores = <String, int>{};

  for (final category in _categoryTerms.entries) {
    var score = 0;
    for (final term in category.value.entries) {
      if (padded.contains(' ${_normalize(term.key)} ')) {
        score += term.value;
      }
    }
    if (score > 0) {
      scores[category.key] = score;
    }
  }

  if (scores.isEmpty) {
    return sourceTopic;
  }

  final ranked = scores.entries.toList()
    ..sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      return byScore != 0 ? byScore : a.key.compareTo(b.key);
    });
  final strongest = ranked.first;

  // A weak generic keyword should not override a feed's curated topic.
  if (strongest.value < 2 && sourceTopic != 'Top Stories') {
    return sourceTopic;
  }
  return strongest.key;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
