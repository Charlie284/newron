import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:newron/domain/news_models.dart';
import 'package:newron/services/ai_assistant.dart';

void main() {
  final article = NewsArticle(
    id: 'article-1234abcd',
    section: 'Technology',
    headline: 'A documented technology change',
    summary: 'The supplied report describes the change and its limits.',
    source: 'Example News',
    url: 'https://example.com/report',
    readTime: '1 min read',
    publishedAt: DateTime.utc(2026, 7, 23),
  );

  test('parses only grounded brief citations and keyed analyses', () async {
    late Map<String, dynamic> requestBody;
    final assistant = HttpAiAssistant(
      client: MockClient((request) async {
        expect(request.url.path, '/api/brief');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'brief':
                        '**Documented** change with a clear source-attributed caveat.',
                    'citation_ids': [article.id, 'article-deadbeef'],
                    'article_analyses': [
                      {
                        'article_id': article.id,
                        'score': 0.2,
                        'label': 'Center',
                        'reason': 'Uses qualified, attributed language.',
                      },
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await assistant.createBrief(
      topic: 'Technology',
      model: 'google/test:free',
      articles: [article],
    );

    expect(requestBody.keys, containsAll(['model', 'topic', 'articles']));
    expect(requestBody, isNot(contains('messages')));
    expect(
      result.brief,
      'Documented change with a clear source-attributed caveat.',
    );
    expect(result.citationIds, [article.id]);
    expect(result.articleAnalyses[article.id]?.label, 'Center');
  });

  test('rejects an AI brief that cites no displayed article', () async {
    final assistant = HttpAiAssistant(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'brief':
                'This answer is long enough but cites an invented source identifier.',
            'citation_ids': ['article-deadbeef'],
          }),
          200,
        ),
      ),
    );

    expect(
      () => assistant.createBrief(
        topic: 'Technology',
        model: 'google/test:free',
        articles: [article],
      ),
      throwsA(isA<AiRequestException>()),
    );
  });

  test('normalizes markdown control characters from AI text', () {
    expect(
      normalizeAiText(
        '  ### Section\n\n**Summary** with `code`.  ',
        maxLength: 100,
      ),
      'Section\n\nSummary with code.',
    );
  });
}
