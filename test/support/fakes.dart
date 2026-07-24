import 'package:newron/data/digest_cache.dart';
import 'package:newron/data/news_repository.dart';
import 'package:newron/domain/news_models.dart';
import 'package:newron/services/ai_assistant.dart';

class FakeNewsRepository implements NewsRepository {
  final calls = <String>[];

  @override
  Future<NewsLoadResult> load(String topic) async {
    calls.add(topic);
    final section = topic == 'Top Stories' ? 'Technology' : topic;
    final articles = List.generate(6, (index) {
      final hex = (index + 1).toRadixString(16).padLeft(8, '0');
      return NewsArticle(
        id: 'article-$hex',
        section: section,
        headline: '$topic documented report ${index + 1}',
        summary: 'A concise source summary with qualifications and context.',
        source: 'Source ${index + 1}',
        url: 'https://example.com/$topic/$index',
        readTime: '1 min read',
        publishedAt: DateTime.now().subtract(Duration(hours: index + 1)),
      );
    });
    return NewsLoadResult(
      articles: articles,
      attemptedSources: const ['Source 1', 'Source 2', 'Source 3'],
      successfulSources: const ['Source 1', 'Source 2', 'Source 3'],
      failures: const {},
      loadedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {}
}

class MemoryDigestCache implements DigestCache {
  final values = <String, NewsDigest>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<NewsDigest?> read(String topic) async => values[topic];

  @override
  Future<void> write(NewsDigest digest) async {
    values[digest.topic] = digest;
  }
}

class FakeAiAssistant implements AiAssistant {
  int createBriefCalls = 0;
  int factCheckCalls = 0;
  int exploreCalls = 0;
  bool useModelInference = true;

  @override
  Future<List<AiModelOption>> loadModels() async {
    return const [
      AiModelOption(
        id: 'test/model:free',
        label: 'Test Model',
        subtitle: 'Test model',
      ),
    ];
  }

  @override
  Future<AiBriefResult> createBrief({
    required String topic,
    required String model,
    required List<NewsArticle> articles,
  }) async {
    createBriefCalls += 1;
    return AiBriefResult(
      brief:
          'The supplied reporting documents the lead development while preserving uncertainty and source attribution.',
      citationIds: [articles.first.id],
      articleAnalyses: {
        articles.first.id: const ArticleAnalysis(
          score: 0,
          label: 'Center',
          reason:
              'The report attributes claims and includes qualifying language.',
        ),
      },
      usedModelInference: useModelInference,
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
    factCheckCalls += 1;
    return FactCheckResult(
      summary: 'The displayed brief is supported by the cited supplied report.',
      sourceIds: [articles.first.id],
    );
  }

  @override
  Future<FactCheckResult> explore({
    required String model,
    required String question,
    required NewsArticle article,
  }) async {
    exploreCalls += 1;
    return FactCheckResult(
      summary:
          'The supplied report does not answer every part of the question.',
      sourceIds: [article.id],
    );
  }

  @override
  void dispose() {}
}

class MemorySettingsStore extends SettingsStore {
  String? model;

  @override
  Future<String?> readModel() async => model;

  @override
  Future<void> writeModel(String modelId) async {
    model = modelId;
  }
}
