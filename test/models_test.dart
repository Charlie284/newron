import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newron/main.dart';

void main() {
  group('NewsArticle', () {
    test('fromJson and toJson should be consistent', () {
      final article = NewsArticle(
        section: 'Technology',
        headline: 'Newron App Launched',
        summary: 'A new AI news app is now available.',
        articleBody: 'Detailed body of the article...',
        source: 'Tech Daily',
        url: 'https://example.com/newron',
        readTime: '3 min read',
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
    });

    test('fromJson should handle null or missing values gracefully', () {
      final json = <String, dynamic>{};
      final article = NewsArticle.fromJson(json);

      expect(article.headline, '');
      expect(article.leaningLabel, 'Center');
      expect(article.leaningScore, 0.0);
    });
  });

  group('NewsDigest', () {
    test('fromJson and toJson should be consistent', () {
      final article = NewsArticle(
        section: 'Politics',
        headline: 'Election Results',
        summary: 'Results are in.',
        articleBody: 'Body...',
        source: 'News Network',
        url: 'https://example.com/news',
        readTime: '5 min',
        accent: Colors.red,
        leaningScore: -0.5,
        leaningLabel: 'Left',
        leaningReason: 'Reasoning...',
      );

      final digest = NewsDigest(
        brief: 'Morning Briefing',
        articles: [article],
        usedModelInference: true,
        updatedAt: DateTime(2026, 4, 26, 10, 0),
        topicSummaries: {'Politics': 'Summary of politics'},
      );

      final json = digest.toJson();
      final fromJson = NewsDigest.fromJson(json);

      expect(fromJson.brief, digest.brief);
      expect(fromJson.articles.length, 1);
      expect(fromJson.articles.first.headline, article.headline);
      expect(fromJson.updatedAt, digest.updatedAt);
      expect(fromJson.topicSummaries['Politics'], 'Summary of politics');
    });
  });
}
