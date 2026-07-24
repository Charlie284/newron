import 'package:flutter_test/flutter_test.dart';
import 'package:newron/data/news_repository.dart';
import 'package:newron/data/rss_sources.dart';
import 'package:newron/domain/news_classifier.dart';
import 'package:newron/domain/news_models.dart';
import 'package:newron/domain/news_ranking.dart';

void main() {
  test(
    'top stories avoids feeds that repeatedly fail the live health check',
    () {
      final selected = selectSourcesForTopic('Top Stories');
      final names = selected.map((source) => source.name).toSet();

      expect(names, isNot(contains('Washington Post World')));
      expect(names, isNot(contains('Scientific American')));
      expect(names, containsAll(['BBC World', 'ScienceDaily']));
      expect(selected, hasLength(12));
    },
  );

  group('feed parsing', () {
    const source = RssSource(
      name: 'Example',
      feedUrl: 'https://example.com/feed',
      topic: 'Technology',
    );

    test(
      'parses publication time, strips markup, and upgrades article HTTPS',
      () {
        const xml = '''
        <rss><channel><item>
          <title>AI system ships with documented safeguards</title>
          <link>http://example.com/story?utm_source=rss</link>
          <description><![CDATA[<p>A <strong>documented</strong> report.</p><script>bad()</script>]]></description>
          <pubDate>Thu, 23 Jul 2026 10:30:00 -0500</pubDate>
        </item></channel></rss>
      ''';

        final articles = parseFeed(source, xml);

        expect(articles, hasLength(1));
        expect(articles.first.url, startsWith('https://'));
        expect(articles.first.summary, 'A documented report.');
        expect(articles.first.publishedAt, DateTime.utc(2026, 7, 23, 15, 30));
        expect(articles.first.section, 'Technology');
      },
    );

    test('parses Atom alternate links and ISO timestamps', () {
      const xml = '''
        <feed xmlns="http://www.w3.org/2005/Atom"><entry>
          <title>Space telescope publishes new research</title>
          <link rel="alternate" href="https://example.com/space" />
          <summary>Peer-reviewed observations are described.</summary>
          <updated>2026-07-23T15:30:00Z</updated>
        </entry></feed>
      ''';

      final articles = parseFeed(source, xml);

      expect(articles.single.url, 'https://example.com/space');
      expect(articles.single.section, 'Science');
      expect(articles.single.publishedAt, DateTime.utc(2026, 7, 23, 15, 30));
    });

    test('decodes numeric and named HTML entities in feed text', () {
      const xml = '''
        <rss><channel><item>
          <title>TikTok&amp;#8217;s safeguards &amp;amp; limits</title>
          <link>https://example.com/entities</link>
          <description>It&amp;rsquo;s documented&amp;hellip;</description>
        </item></channel></rss>
      ''';

      final article = parseFeed(source, xml).single;

      expect(article.headline, 'TikTok’s safeguards & limits');
      expect(article.summary, 'It’s documented…');
    });
  });

  test(
    'classifier uses token boundaries instead of matching ai substrings',
    () {
      expect(
        classifyArticle(
          headline: 'California port authority approves repairs',
          summary: 'Local officials discussed the project.',
          sourceTopic: 'Policy',
        ),
        'Policy',
      );
      expect(
        classifyArticle(
          headline: 'AI chip startup publishes benchmark',
          summary: 'The software result includes limitations.',
          sourceTopic: 'Top Stories',
        ),
        'Technology',
      );
    },
  );

  test('source selection is HTTPS-only, bounded, and category-aware', () {
    expect(rssSources.length, greaterThanOrEqualTo(70));
    expect(
      rssSources.every((source) => source.feedUrl.startsWith('https://')),
      isTrue,
    );

    final top = selectSourcesForTopic('Top Stories');
    expect(top.length, lessThanOrEqualTo(12));
    expect(top.map((source) => source.topic).toSet().length, greaterThan(4));

    final science = selectSourcesForTopic('Science');
    expect(science.length, lessThanOrEqualTo(12));
    expect(
      science.where((source) => source.topic == 'Science').length,
      greaterThan(3),
    );
  });

  test(
    'ranking orders by date, removes duplicates, and preserves source diversity',
    () {
      NewsArticle article(String id, String source, int hour, String headline) {
        return NewsArticle(
          id: id,
          section: 'World',
          headline: headline,
          summary: 'Summary',
          source: source,
          url: 'https://example.com/$id',
          readTime: '1 min read',
          publishedAt: DateTime.utc(2026, 7, 23, hour),
        );
      }

      final ranked = rankAndDiversifyArticles(
        [
          article('article-00000001', 'A', 12, 'Newest A'),
          article('article-00000002', 'A', 11, 'Second A'),
          article('article-00000003', 'B', 10, 'Newest B'),
          article('article-00000004', 'C', 9, 'Newest C'),
          article('article-00000005', 'D', 8, 'Newest A'),
        ],
        now: DateTime.utc(2026, 7, 23, 13),
        limit: 4,
      );

      expect(ranked.map((article) => article.headline), [
        'Newest A',
        'Newest B',
        'Newest C',
        'Second A',
      ]);
    },
  );
}
