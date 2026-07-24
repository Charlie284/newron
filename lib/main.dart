import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/digest_cache.dart';
import 'data/news_repository.dart';
import 'data/rss_sources.dart';
import 'domain/news_models.dart';
import 'services/ai_assistant.dart';

export 'domain/news_models.dart';

void main() {
  runApp(const NewronApp());
}

class NewronApp extends StatefulWidget {
  const NewronApp({
    super.key,
    this.repository,
    this.aiAssistant,
    this.cache,
    this.settingsStore,
  });

  final NewsRepository? repository;
  final AiAssistant? aiAssistant;
  final DigestCache? cache;
  final SettingsStore? settingsStore;

  @override
  State<NewronApp> createState() => _NewronAppState();
}

class _NewronAppState extends State<NewronApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Newron',
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: NewsHomePage(
        repository: widget.repository,
        aiAssistant: widget.aiAssistant,
        cache: widget.cache,
        settingsStore: widget.settingsStore,
        themeMode: _themeMode,
        onThemeModeChanged: (value) => setState(() => _themeMode = value),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const accent = Color(0xFFDE5C3E);
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    surface: isDark ? const Color(0xFF211E1A) : const Color(0xFFF4ECE1),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'NewronSans',
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -1.2,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF2B2722) : const Color(0xFFFFF9F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      labelStyle: base.textTheme.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.repository,
    this.aiAssistant,
    this.cache,
    this.settingsStore,
  });

  final NewsRepository? repository;
  final AiAssistant? aiAssistant;
  final DigestCache? cache;
  final SettingsStore? settingsStore;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  late final NewsRepository _repository;
  late final AiAssistant _aiAssistant;
  late final DigestCache _cache;
  late final SettingsStore _settingsStore;
  late final bool _ownsRepository;
  late final bool _ownsAiAssistant;

  NewsDigest? _digest;
  NewsLoadResult? _loadResult;
  String _selectedTopic = 'Top Stories';
  String? _loadError;
  String? _aiError;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isGeneratingBrief = false;
  int _loadGeneration = 0;
  int _aiGeneration = 0;
  List<AiModelOption> _models = HttpAiAssistant.fallbackModels;
  String _selectedModelId = HttpAiAssistant.fallbackModels.first.id;
  bool _isLoadingModels = false;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _ownsAiAssistant = widget.aiAssistant == null;
    _repository = widget.repository ?? RssNewsRepository();
    _aiAssistant = widget.aiAssistant ?? HttpAiAssistant();
    _cache = widget.cache ?? SharedPreferencesDigestCache();
    _settingsStore = widget.settingsStore ?? SettingsStore();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _aiGeneration += 1;
    if (_ownsRepository) {
      _repository.dispose();
    }
    if (_ownsAiAssistant) {
      _aiAssistant.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final storedModel = await _settingsStore.readModel();
    final cached = await _cache.read(_selectedTopic);
    if (!mounted) {
      return;
    }
    setState(() {
      if (storedModel != null && storedModel.trim().isNotEmpty) {
        _selectedModelId = storedModel;
      }
      _digest = cached;
      _isLoading = cached == null;
    });
    unawaited(_loadModels());
    await _refresh();
  }

  Future<void> _loadModels() async {
    if (_isLoadingModels) {
      return;
    }
    setState(() => _isLoadingModels = true);
    final models = await _aiAssistant.loadModels();
    if (!mounted) {
      return;
    }
    setState(() {
      _models = models;
      if (!_models.any((model) => model.id == _selectedModelId)) {
        _selectedModelId = _models.first.id;
      }
      _isLoadingModels = false;
    });
  }

  Future<void> _selectTopic(String topic) async {
    if (topic == _selectedTopic) {
      return;
    }
    final generation = ++_loadGeneration;
    _aiGeneration += 1;
    setState(() {
      _selectedTopic = topic;
      _digest = null;
      _loadResult = null;
      _loadError = null;
      _aiError = null;
      _isLoading = true;
      _isRefreshing = false;
      _isGeneratingBrief = false;
    });
    final cached = await _cache.read(topic);
    if (!mounted || generation != _loadGeneration) {
      return;
    }
    if (cached != null) {
      setState(() {
        _digest = cached;
        _isLoading = false;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final generation = ++_loadGeneration;
    _aiGeneration += 1;
    setState(() {
      _isRefreshing = _digest != null;
      _isLoading = _digest == null;
      _loadError = null;
      _aiError = null;
      _isGeneratingBrief = false;
    });

    try {
      final result = await _repository.load(_selectedTopic);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      if (result.articles.isEmpty) {
        setState(() {
          _loadResult = result;
          _loadError = _digest == null
              ? 'No live coverage could be loaded. Check the connection and try again.'
              : 'Live coverage could not be refreshed. Saved reporting is still shown.';
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }

      final previousAnalyses = <String, NewsArticle>{
        for (final article in _digest?.articles ?? const <NewsArticle>[])
          if (article.hasAnalysis) article.id: article,
      };
      final articles = result.articles
          .map((article) {
            final analyzed = previousAnalyses[article.id];
            return analyzed == null
                ? article
                : article.copyWith(
                    leaningScore: analyzed.leaningScore,
                    leaningLabel: analyzed.leaningLabel,
                    leaningReason: analyzed.leaningReason,
                  );
          })
          .toList(growable: false);
      final next = NewsDigest(
        articles: articles,
        updatedAt: result.loadedAt,
        topic: _selectedTopic,
      );
      setState(() {
        _digest = next;
        _loadResult = result;
        _isLoading = false;
        _isRefreshing = false;
      });
      await _cache.write(next);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loadError = _digest == null
            ? 'Newron could not reach the news feeds. Check the connection and retry.'
            : 'The refresh failed. Saved reporting is still available.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _generateBrief() async {
    final digest = _digest;
    if (digest == null || digest.articles.isEmpty || _isGeneratingBrief) {
      return;
    }
    final generation = ++_aiGeneration;
    setState(() {
      _isGeneratingBrief = true;
      _aiError = null;
    });
    try {
      final result = await _aiAssistant.createBrief(
        topic: _selectedTopic,
        model: _selectedModelId,
        articles: _visibleArticles(digest),
      );
      if (!mounted || generation != _aiGeneration) {
        return;
      }
      final analyzed = digest.articles
          .map((article) {
            final analysis = result.articleAnalyses[article.id];
            return analysis == null
                ? article
                : article.copyWith(
                    leaningScore: analysis.score,
                    leaningLabel: analysis.label,
                    leaningReason: analysis.reason,
                  );
          })
          .toList(growable: false);
      final next = digest.copyWith(
        brief: result.brief,
        briefCitationIds: result.citationIds,
        articles: analyzed,
        usedModelInference: result.usedModelInference,
      );
      setState(() {
        _digest = next;
        _aiError = result.usedModelInference
            ? null
            : 'The AI provider was unavailable. Showing a source-only fallback; retry when you want AI synthesis.';
        _isGeneratingBrief = false;
      });
      await _cache.write(next);
    } on AiRequestException catch (error) {
      if (!mounted || generation != _aiGeneration) {
        return;
      }
      setState(() {
        _aiError = error.message;
        _isGeneratingBrief = false;
      });
    } catch (_) {
      if (!mounted || generation != _aiGeneration) {
        return;
      }
      setState(() {
        _aiError =
            'The AI brief could not be generated. The source reporting is unchanged.';
        _isGeneratingBrief = false;
      });
    }
  }

  List<NewsArticle> _visibleArticles(NewsDigest digest) {
    if (_selectedTopic == 'Top Stories') {
      return digest.articles;
    }
    final exact = digest.articles
        .where((article) => article.section == _selectedTopic)
        .toList(growable: false);
    return exact.length >= 4 ? exact : digest.articles;
  }

  Future<void> _openOriginal(NewsArticle article) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null || uri.scheme != 'https') {
      _showSnack('This source did not provide a safe HTTPS link.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showSnack('The source link could not be opened.');
      }
    } on Object {
      _showSnack('The source link could not be opened.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFactCheck() async {
    final digest = _digest;
    if (digest?.brief == null || digest!.briefCitationIds.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => _FactCheckSheet(
        assistant: _aiAssistant,
        model: _selectedModelId,
        digest: digest,
      ),
    );
  }

  Future<void> _openExplore(NewsArticle article) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => _ExploreSheet(
        assistant: _aiAssistant,
        model: _selectedModelId,
        article: article,
      ),
    );
  }

  Future<void> _openSources() async {
    final digest = _digest;
    if (digest == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) {
        final sources =
            digest.articles.map((article) => article.source).toSet().toList()
              ..sort();
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            children: [
              Text('Sources', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                _loadResult == null
                    ? 'Sources represented in this saved briefing.'
                    : '${_loadResult!.successfulSources.length} of ${_loadResult!.attemptedSources.length} selected feeds returned readable coverage.',
              ),
              const SizedBox(height: 20),
              for (final source in sources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.article_outlined),
                  title: Text(source),
                  subtitle: Text(
                    '${digest.articles.where((article) => article.source == source).length} article${digest.articles.where((article) => article.source == source).length == 1 ? '' : 's'} shown',
                  ),
                ),
              if (_loadResult?.failures.isNotEmpty ?? false) ...[
                const Divider(height: 32),
                Text(
                  'Unavailable this refresh',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final failure in _loadResult!.failures.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: Text(failure.key),
                    subtitle: Text(failure.value),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedModel =
              _models.any((model) => model.id == _selectedModelId)
              ? _selectedModelId
              : null;
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Appearance, AI model, and local data controls.'),
                  const SizedBox(height: 24),
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {widget.themeMode},
                    onSelectionChanged: (selection) {
                      widget.onThemeModeChanged(selection.first);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'AI model',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reload available AI models',
                        onPressed: _isLoadingModels
                            ? null
                            : () async {
                                await _loadModels();
                                if (context.mounted) {
                                  setSheetState(() {});
                                }
                              },
                        icon: _isLoadingModels
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedModel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Model used for opt-in analysis',
                    ),
                    items: _models
                        .map(
                          (model) => DropdownMenuItem(
                            value: model.id,
                            child: Text(
                              model.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      setState(() => _selectedModelId = value);
                      setSheetState(() {});
                      await _settingsStore.writeModel(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI is off during startup and refresh. Article metadata is sent only after you choose Generate AI brief, Fact check, or Explore.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Local data',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _cache.clear();
                      if (!sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      _showSnack('Saved briefings were cleared.');
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear saved briefings'),
                  ),
                  const SizedBox(height: 28),
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Newron 1.0 · RSS reporting with optional source-grounded AI synthesis. AI labels are interpretive, not objective ratings.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digest = _digest;
    final articles = digest == null
        ? const <NewsArticle>[]
        : _visibleArticles(digest);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, digest)),
              SliverToBoxAdapter(child: _buildTopics(context)),
              if (_isRefreshing)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: _buildBody(context, digest, articles),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NewsDigest? digest) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEWRON',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      digest == null
                          ? 'Independent feeds. Optional AI.'
                          : 'Updated ${formatRelativeTime(digest.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh coverage',
                onPressed: _isLoading || _isRefreshing ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Open settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopics(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: SizedBox(
          height: 58,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: newsCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final topic = newsCategories[index];
              return ChoiceChip(
                label: Text(topic),
                selected: topic == _selectedTopic,
                onSelected: (_) => _selectTopic(topic),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NewsDigest? digest,
    List<NewsArticle> articles,
  ) {
    if (_isLoading && digest == null) {
      return const _LoadingState();
    }
    if (digest == null || articles.isEmpty) {
      return _EmptyState(message: _loadError, onRetry: _refresh);
    }

    final briefing = _BriefingPanel(
      topic: _selectedTopic,
      digest: digest,
      articles: articles,
      isGenerating: _isGeneratingBrief,
      aiError: _aiError,
      onGenerate: _generateBrief,
      onFactCheck: digest.usedModelInference ? _openFactCheck : null,
      onSources: _openSources,
      onOpenCitation: _openOriginal,
    );
    final coverage = _CoverageList(
      topic: _selectedTopic,
      articles: articles,
      onOpen: _openOriginal,
      onExplore: _openExplore,
    );
    final banners = _StatusBanners(
      digest: digest,
      result: _loadResult,
      loadError: _loadError,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banners,
        if (banners.hasContent) const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 880) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 370, child: briefing),
                  const SizedBox(width: 28),
                  Expanded(child: coverage),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [briefing, const SizedBox(height: 28), coverage],
            );
          },
        ),
      ],
    );
  }
}

class _StatusBanners extends StatelessWidget {
  const _StatusBanners({
    required this.digest,
    required this.result,
    required this.loadError,
  });

  final NewsDigest digest;
  final NewsLoadResult? result;
  final String? loadError;

  bool get hasContent =>
      loadError != null ||
      digest.isStale ||
      (result?.hasPartialFailure ?? false);

  @override
  Widget build(BuildContext context) {
    if (!hasContent) {
      return const SizedBox.shrink();
    }
    final messages = <String>[
      ?loadError,
      if (digest.isStale)
        'Saved coverage is ${formatRelativeTime(digest.updatedAt)} old. Refresh before relying on it.',
      if (result?.hasPartialFailure ?? false)
        '${result!.successfulSources.length} of ${result!.attemptedSources.length} selected feeds updated; the source list shows what was unavailable.',
    ];
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                messages.join('\n'),
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingPanel extends StatelessWidget {
  const _BriefingPanel({
    required this.topic,
    required this.digest,
    required this.articles,
    required this.isGenerating,
    required this.aiError,
    required this.onGenerate,
    required this.onFactCheck,
    required this.onSources,
    required this.onOpenCitation,
  });

  final String topic;
  final NewsDigest digest;
  final List<NewsArticle> articles;
  final bool isGenerating;
  final String? aiError;
  final VoidCallback onGenerate;
  final VoidCallback? onFactCheck;
  final VoidCallback onSources;
  final ValueChanged<NewsArticle> onOpenCitation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cited = digest.briefCitationIds
        .map(
          (id) => articles.cast<NewsArticle?>().firstWhere(
            (article) => article?.id == id,
            orElse: () => null,
          ),
        )
        .whereType<NewsArticle>()
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(topic, style: theme.textTheme.headlineSmall),
                ),
                Icon(
                  digest.usedModelInference
                      ? Icons.auto_awesome_outlined
                      : Icons.newspaper_outlined,
                  semanticLabel: digest.usedModelInference
                      ? 'AI synthesis'
                      : 'Source overview',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectionArea(
              child: Text(
                digest.brief ?? buildLocalOverview(articles, topic),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (digest.usedModelInference) ...[
              const SizedBox(height: 14),
              Text(
                'AI synthesis from the linked articles. It can be wrong; verify important claims in the originals.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (cited.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Cited reporting', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final article in cited)
                TextButton.icon(
                  onPressed: () => onOpenCitation(article),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(article.source, overflow: TextOverflow.ellipsis),
                ),
            ],
            if (isGenerating) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text('Generating a source-grounded brief…'),
              ),
            ],
            if (aiError != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  aiError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                digest.usedModelInference
                    ? 'Regenerate AI brief'
                    : 'Generate AI brief',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onSources,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Sources'),
                ),
                TextButton.icon(
                  onPressed: onFactCheck,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Fact check'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageList extends StatelessWidget {
  const _CoverageList({
    required this.topic,
    required this.articles,
    required this.onOpen,
    required this.onExplore,
  });

  final String topic;
  final List<NewsArticle> articles;
  final ValueChanged<NewsArticle> onOpen;
  final ValueChanged<NewsArticle> onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Coverage',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text('${articles.length} reports'),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < articles.length; index++) ...[
          _ArticleCard(
            article: articles[index],
            onOpen: () => onOpen(articles[index]),
            onExplore: () => onExplore(articles[index]),
          ),
          if (index != articles.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.onOpen,
    required this.onExplore,
  });

  final NewsArticle article;
  final VoidCallback onOpen;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  article.source,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text('• ${formatArticleDate(article.publishedAt)}'),
                Text('• ${article.section}'),
              ],
            ),
            const SizedBox(height: 10),
            SelectionArea(
              child: Text(article.headline, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            SelectionArea(
              child: Text(article.summary, style: theme.textTheme.bodyMedium),
            ),
            if (article.hasAnalysis) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI framing view: ${article.leaningLabel}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.leaningReason,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 19),
                  label: const Text('Read original'),
                ),
                TextButton.icon(
                  onPressed: onExplore,
                  icon: const Icon(Icons.manage_search, size: 20),
                  label: const Text('Explore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading current reporting',
      child: Column(
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 24),
          Icon(
            Icons.newspaper_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading current reporting…',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Up to 12 selected feeds, with a five-second limit per feed.',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Coverage unavailable',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message ??
                    'No readable articles were returned for this section.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactCheckSheet extends StatefulWidget {
  const _FactCheckSheet({
    required this.assistant,
    required this.model,
    required this.digest,
  });

  final AiAssistant assistant;
  final String model;
  final NewsDigest digest;

  @override
  State<_FactCheckSheet> createState() => _FactCheckSheetState();
}

class _FactCheckSheetState extends State<_FactCheckSheet> {
  FactCheckResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = await widget.assistant.factCheck(
        topic: widget.digest.topic,
        model: widget.model,
        brief: widget.digest.brief!,
        citationIds: widget.digest.briefCitationIds,
        articles: widget.digest.articles,
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } on AiRequestException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cited = _result == null
        ? const <NewsArticle>[]
        : widget.digest.articles
              .where((article) => _result!.sourceIds.contains(article.id))
              .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fact check',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'This checks the displayed AI brief against the same supplied articles. It does not independently prove every real-world claim.',
              ),
              const SizedBox(height: 20),
              if (_result == null && _error == null) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text('Comparing the brief with cited reporting…'),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_result != null) ...[
                SelectionArea(
                  child: Text(
                    _result!.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sources used',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final article in cited)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(article.source),
                    subtitle: Text(article.headline, maxLines: 2),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreSheet extends StatefulWidget {
  const _ExploreSheet({
    required this.assistant,
    required this.model,
    required this.article,
  });

  final AiAssistant assistant;
  final String model;
  final NewsArticle article;

  @override
  State<_ExploreSheet> createState() => _ExploreSheetState();
}

class _ExploreSheetState extends State<_ExploreSheet> {
  final _controller = TextEditingController();
  FactCheckResult? _result;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _controller.text.trim();
    if (question.length < 4 || _isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.assistant.explore(
        model: widget.model,
        question: question,
        article: widget.article,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } on AiRequestException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore this report',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.article.headline,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                enabled: !_isLoading,
                maxLength: 240,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Question about this article',
                  hintText: 'What context or uncertainty should I notice?',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: const Icon(Icons.manage_search),
                label: const Text('Analyze supplied report'),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 22),
                SelectionArea(
                  child: Text(
                    _result!.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Grounded in: ${widget.article.source}. Verify against the original report.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String buildLocalOverview(List<NewsArticle> articles, String topic) {
  if (articles.isEmpty) {
    return 'No current reports are available.';
  }
  final sources = articles.map((article) => article.source).toSet().length;
  final lead = articles.take(3).map((article) => article.headline).toList();
  return '$sources independent source${sources == 1 ? '' : 's'} are represented in this $topic view. Leading reports: ${lead.join('; ')}. Open the originals below for complete context.';
}

String formatRelativeTime(DateTime value, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hr ago';
  }
  return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
}

String formatArticleDate(DateTime? value, {DateTime? now}) {
  if (value == null) {
    return 'Time not supplied';
  }
  return formatRelativeTime(value, now: now);
}
