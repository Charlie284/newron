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

  test('keeps decimal model versions readable', () async {
    final assistant = HttpAiAssistant(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {'id': 'inclusionai/ling-3.0-flash:free'},
            ],
          }),
          200,
        ),
      ),
    );

    final models = await assistant.loadModels();

    expect(models.single.label, 'Ling 3.0 Flash');
  });

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
    expect(result.usedModelInference, isTrue);
  });

  test('labels the gateway source-only fallback as non-AI', () async {
    final assistant = HttpAiAssistant(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'brief':
                'Leading supplied reports describe a documented change and preserve the original context.',
            'citation_ids': [article.id],
            'article_analyses': const [],
            'generated_by': 'source_fallback',
          }),
          200,
        ),
      ),
    );

    final result = await assistant.createBrief(
      topic: 'Technology',
      model: 'inclusionai/ling-3.0-flash:free',
      articles: [article],
    );

    expect(result.usedModelInference, isFalse);
    expect(result.citationIds, [article.id]);
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

  test('bounds a generated brief to five source records', () async {
    final articles = List.generate(
      7,
      (index) => article.copyWith(
        id: 'article-${(index + 1).toRadixString(16).padLeft(8, '0')}',
      ),
    );
    final assistant = HttpAiAssistant(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body['articles'],
          isA<List>().having((value) => value.length, 'length', 5),
        );
        return http.Response(
          jsonEncode({
            'brief':
                'This bounded source-grounded briefing remains traceable to the displayed reporting.',
            'citation_ids': [articles.first.id],
            'article_analyses': const [],
          }),
          200,
        );
      }),
    );

    final result = await assistant.createBrief(
      topic: 'Technology',
      model: 'inclusionai/ling-3.0-flash:free',
      articles: articles,
    );

    expect(result.citationIds, [articles.first.id]);
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
