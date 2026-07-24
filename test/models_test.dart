import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newron/main.dart';

void main() {
  group('NewsArticle', () {
    test('fromJson and toJson should be consistent', () {
      final article = NewsArticle(
        id: 'article-12345678',
        section: 'Technology',
        headline: 'Newron App Launched',
        summary: 'A new AI news app is now available.',
        source: 'Tech Daily',
        url: 'https://example.com/newron',
        readTime: '3 min read',
        publishedAt: DateTime.utc(2026, 4, 26, 9),
        accent: Colors.blue,
        leaningScore: 0.1,
        leaningLabel: 'Center',
        leaningReason: 'Objective reporting.',
      );

      final json = article.toJson();
      final fromJson = NewsArticle.fromJson(json);

      expect(fromJson.headline, article.headline);
      expect(fromJson.section, article.section);
      expect(fromJson.accent.toARGB32(), article.accent.toARGB32());
      expect(fromJson.leaningScore, article.leaningScore);
      expect(fromJson.publishedAt, article.publishedAt);
    });

    test('fromJson should handle null or missing values gracefully', () {
      final json = <String, dynamic>{};
      final article = NewsArticle.fromJson(json);

      expect(article.headline, '');
      expect(article.leaningLabel, 'Not analyzed');
      expect(article.leaningScore, 0.0);
    });
  });

  group('NewsDigest', () {
    test('fromJson and toJson should be consistent', () {
      final article = NewsArticle(
        id: 'article-abcdef12',
        section: 'Politics',
        headline: 'Election Results',
        summary: 'Results are in.',
        source: 'News Network',
        url: 'https://example.com/news',
        readTime: '5 min',
        publishedAt: DateTime.utc(2026, 4, 26, 8),
        accent: Colors.red,
        leaningScore: -0.5,
        leaningLabel: 'Left',
        leaningReason: 'Reasoning...',
      );

      final digest = NewsDigest(
        brief: 'Morning Briefing',
        articles: [article],
        usedModelInference: true,
        updatedAt: DateTime.utc(2026, 4, 26, 10, 0),
        topic: 'Politics',
        briefCitationIds: const ['article-abcdef12'],
      );

      final json = digest.toJson();
      final fromJson = NewsDigest.fromJson(json);

      expect(fromJson.brief, digest.brief);
      expect(fromJson.articles.length, 1);
      expect(fromJson.articles.first.headline, article.headline);
      expect(fromJson.updatedAt, digest.updatedAt);
      expect(fromJson.topic, 'Politics');
      expect(fromJson.briefCitationIds, ['article-abcdef12']);
    });
  });
}
