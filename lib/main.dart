import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NewronApp());
}

class NewronApp extends StatefulWidget {
  const NewronApp({super.key});

  @override
  State<NewronApp> createState() => _NewronAppState();
}

class _NewronAppState extends State<NewronApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFE3D4BF);
    const ink = Color(0xFF171717);
    const accent = Color(0xFFEE6C4D);
    const night = Color(0xFF24211D);
    const cloud = Color(0xFFE6DCCF);
    const warmSurface = Color(0xFFD0B89B);
    const nightSurface = Color(0xFF332E28);
    final displayText = GoogleFonts.cormorantGaramondTextTheme();
    final bodyText = GoogleFonts.manropeTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Newron',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: canvas,
        ),
        textTheme: bodyText.copyWith(
          displaySmall: displayText.displaySmall?.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 0.92,
            letterSpacing: -0.5,
            color: ink,
          ),
          headlineSmall: displayText.headlineSmall?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: -0.2,
            color: ink,
          ),
          titleLarge: bodyText.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: ink,
          ),
          bodyLarge: bodyText.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: const Color(0xFF2F2822),
          ),
          bodyMedium: bodyText.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: const Color(0xFF55473B),
          ),
        ),
        chipTheme: const ChipThemeData(backgroundColor: warmSurface),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: night,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: night,
        ),
        textTheme: bodyText.copyWith(
          displaySmall: displayText.displaySmall?.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 0.92,
            letterSpacing: -0.5,
            color: cloud,
          ),
          headlineSmall: displayText.headlineSmall?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: -0.2,
            color: cloud,
          ),
          titleLarge: bodyText.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: cloud,
          ),
          bodyLarge: bodyText.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: const Color(0xFFD8CBB8),
          ),
          bodyMedium: bodyText.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: const Color(0xFFB8AA97),
          ),
        ),
        chipTheme: const ChipThemeData(backgroundColor: nightSurface),
      ),
      home: NewsHomePage(onToggleTheme: _toggleTheme),
    );
  }
}

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  static const int _maxFetchedArticles = 24;
  static const int _maxFallbackTopicArticles = 8;
  static const int _maxFocusSourceArticles = 6;
  static const int _maxItemsPerRssFeed = 3;

  Future<String?>? _selectionSummaryFuture;
  String? _lastSelection;
  Future<String?>? _focusSummaryFuture;
  NewsDigest? _displayDigest;
  Map<String, String> _topicSummaries = <String, String>{};
  final Set<String> _typedTexts = <String>{};
  double _leaningPreference = 0;
  String _selectedTopic = 'Top Stories';
  String _selectedModelId = _fallbackModelOptions.first.id;
  String? _selectedFocusTerm;
  bool _isRefreshing = true;
  bool _isLoadingModelOptions = false;
  List<_ModelOption> _availableModelOptions = _fallbackModelOptions;

  static const _cacheKey = 'newron_cached_digest_v1';
  static const _modelKey = 'newron_selected_model_v1';

  static const categories = <String>[
    'Top Stories',
    'World',
    'Politics',
    'Business',
    'Technology',
    'Science',
    'Health',
    'Sports',
    'Policy',
  ];

  static const _fallbackModelOptions = <_ModelOption>[
    _ModelOption(
      id: 'google/gemma-4-31b-it:free',
      label: 'Gemma 4 31B',
      subtitle: 'Google free • 262K context',
    ),
    _ModelOption(
      id: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super',
      subtitle: 'NVIDIA free • 262K context',
    ),
    _ModelOption(
      id: 'minimax/minimax-m2.5:free',
      label: 'MiniMax M2.5',
      subtitle: 'MiniMax free • 196K context',
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapDigest());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _bootstrapDigest() async {
    final preferences = await SharedPreferences.getInstance();
    final storedModelId = preferences.getString(_modelKey);
    final cachedDigest = await _readCachedDigest();
    if (!mounted) {
      return;
    }

    if (storedModelId != null &&
        _availableModelOptions.any((option) => option.id == storedModelId)) {
      _selectedModelId = storedModelId;
    }

    unawaited(_loadModelOptions());

    if (cachedDigest != null) {
      setState(() {
        _displayDigest = cachedDigest;
        _topicSummaries = Map<String, String>.from(cachedDigest.topicSummaries);
        _selectionSummaryFuture = Future<String?>.value(
          _bestVisibleSummary(cachedDigest),
        );
        _selectedFocusTerm = null;
        _focusSummaryFuture = null;
      });
    }

    await _refreshDigest();
  }

  String get _selectedModelLabel {
    for (final option in _availableModelOptions) {
      if (option.id == _selectedModelId) {
        return '${option.label} • ${option.subtitle}';
      }
    }
    return _selectedModelId;
  }

  Future<void> _loadModelOptions() async {
    if (_isLoadingModelOptions) {
      return;
    }

    setState(() {
      _isLoadingModelOptions = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://royal-union-f92a.charlh048.workers.dev/v1/models'),
        headers: const {
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://newron.local',
          'X-Title': 'Newron News App',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return;
      }

      final data = payload['data'];
      if (data is! List) {
        return;
      }

      final options =
          data
              .whereType<Map<String, dynamic>>()
              .where(_isUsableTextModel)
              .map(_modelOptionFromPayload)
              .toList(growable: false)
            ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
            );

      if (options.isEmpty || !mounted) {
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      final storedModelId = preferences.getString(_modelKey);
      final resolvedSelectedModelId =
          storedModelId != null &&
              options.any((option) => option.id == storedModelId)
          ? storedModelId
          : (options.any((option) => option.id == _selectedModelId)
                ? _selectedModelId
                : options.first.id);

      setState(() {
        _availableModelOptions = options;
        _selectedModelId = resolvedSelectedModelId;
      });
    } catch (_) {
      // Keep the fallback list if the live catalog cannot be loaded.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModelOptions = false;
        });
      }
    }
  }

  bool _isUsableTextModel(Map<String, dynamic> model) {
    final id = model['id']?.toString().toLowerCase() ?? '';
    // Since our worker only provides id and object, we filter by keywords
    final nonTextKeywords = ['lyria', 'video', 'image', 'ocr', 'embedding'];
    return !nonTextKeywords.any((keyword) => id.contains(keyword));
  }

  _ModelOption _modelOptionFromPayload(Map<String, dynamic> model) {
    final id = (model['id'] ?? '').toString();
    // Use the ID to create a readable label
    final parts = id.split('/');
    final labelPart = parts.length > 1 ? parts[1] : id;
    final cleanLabel = labelPart
        .replaceAll('-it:free', '')
        .replaceAll(':free', '')
        .replaceAll('-instruct', '')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');

    return _ModelOption(
      id: id,
      label: cleanLabel.isEmpty ? id : cleanLabel,
      subtitle: 'Free model via Worker',
    );
  }

  String? _formatContextLength(dynamic value) {
    if (value is! num) {
      return null;
    }
    final count = value.toInt();
    if (count >= 1000) {
      final compact = (count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1);
      return '${compact}K context';
    }
    return '$count context';
  }

  Future<void> _setSelectedModel(String modelId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modelKey, modelId);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedModelId = modelId;
      _topicSummaries = <String, String>{};
      _selectedFocusTerm = null;
      _focusSummaryFuture = null;
      if (_displayDigest != null) {
        _selectionSummaryFuture = _summarizeTopicSelection(
          _selectedTopic,
          _leaningPreference,
          _applySelectionFor(
            _displayDigest!.articles,
            topic: _selectedTopic,
            bias: _leaningPreference,
          ),
        );
      }
    });

    if (_displayDigest != null) {
      final rebasedDigest = _displayDigest!.copyWith(
        topicSummaries: const <String, String>{},
      );
      await _writeCachedDigest(rebasedDigest);
      if (!mounted) {
        return;
      }
      setState(() {
        _displayDigest = rebasedDigest;
      });
      unawaited(_primeTopicSummaries(rebasedDigest));
    }
  }

  Future<void> _openSettingsSheet() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark
        ? const Color(0xFF302A24)
        : const Color(0xFFD8C2A6);
    final cardColor = isDark
        ? const Color(0xFF3B342D)
        : const Color(0xFFE3D0B7);
    final muted = isDark ? const Color(0xFFB8AA97) : const Color(0xFF5A493C);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetColor,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text('Settings', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Tune the look, refresh behavior, speech tools, and local data.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: 'Appearance',
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Theme'),
                          subtitle: Text(
                            isDark ? 'Warm charcoal mode' : 'Tan paper mode',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                          trailing: FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onToggleTheme();
                            },
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                            label: Text(isDark ? 'Light' : 'Dark'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Briefing',
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('AI model'),
                          subtitle: Text(
                            _isLoadingModelOptions
                                ? 'Loading free text models from OpenRouter...'
                                : _selectedModelLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoadingModelOptions)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Reload models',
                                onPressed: _isLoadingModelOptions
                                    ? null
                                    : _loadModelOptions,
                                icon: const Icon(Icons.sync_rounded),
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      _availableModelOptions.any(
                                        (option) =>
                                            option.id == _selectedModelId,
                                      )
                                      ? _selectedModelId
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  hint: const Text('Choose'),
                                  items: _availableModelOptions
                                      .map(
                                        (option) => DropdownMenuItem<String>(
                                          value: option.id,
                                          child: SizedBox(
                                            width: 180,
                                            child: Text(
                                              option.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) async {
                                    if (value == null ||
                                        value == _selectedModelId) {
                                      return;
                                    }
                                    await _setSelectedModel(value);
                                    if (!context.mounted) {
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Bias lens'),
                          subtitle: Text(
                            _sliderLabel(_leaningPreference),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _updateSelection(bias: -0.8);
                                  },
                                  child: const Text('Left'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _updateSelection(bias: 0);
                                  },
                                  child: const Text('Center'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _updateSelection(bias: 0.8);
                                  },
                                  child: const Text('Right'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Refresh now'),
                          subtitle: Text(
                            'Pull fresh articles and rebuild the long summary.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                          trailing: const Icon(Icons.refresh_rounded),
                          onTap: () {
                            Navigator.of(context).pop();
                            _refreshDigest();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Data',
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Saved briefing cache'),
                          subtitle: Text(
                            _displayDigest == null
                                ? 'No local snapshot is currently saved.'
                                : 'A saved snapshot is kept so the last briefing can show while fresh reporting loads.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Clear local cache'),
                          subtitle: Text(
                            'Remove the saved briefing snapshot from this device.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                          trailing: const Icon(Icons.delete_outline_rounded),
                          onTap: () async {
                            await _clearCachedDigest();
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pop();
                            _showSpeechMessage('Saved briefing cache cleared.');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'About',
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Sources'),
                          subtitle: Text(
                            'TheNewsAPI, NewsData.io, and a broad RSS feed layer are merged into one live stream.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Privacy boundary'),
                          subtitle: Text(
                            'Sensitive patterns are redacted before model prompts are sent.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearCachedDigest() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cacheKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _topicSummaries = <String, String>{};
    });
  }

  void _showSpeechMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSourcesSheet(List<NewsArticle> articles) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark
        ? const Color(0xFF302A24)
        : const Color(0xFFD8C2A6);
    final muted = isDark ? const Color(0xFFB8AA97) : const Color(0xFF5A493C);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetColor,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Sources Given To The Model',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'These are the articles used for the current $_selectedTopic summary.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 18),
                ...articles.asMap().entries.map((entry) {
                  final article = entry.value;
                  final bodyPreview = _truncateForPrompt(
                    article.articleBody.isNotEmpty
                        ? article.articleBody
                        : article.summary,
                    260,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ${article.headline}',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${article.source} • ${article.section}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (article.url.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(article.url, style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 8),
                        Text(article.summary, style: theme.textTheme.bodyLarge),
                        if (bodyPreview.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            bodyPreview,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFactCheckSheet(List<NewsArticle> articles) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark
        ? const Color(0xFF302A24)
        : const Color(0xFFD8C2A6);
    final muted = isDark ? const Color(0xFFB8AA97) : const Color(0xFF5A493C);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetColor,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.8,
            child: FutureBuilder<String?>(
              future: _factCheckSelection(
                topic: _selectedTopic,
                bias: _leaningPreference,
                articles: articles,
              ),
              builder: (context, snapshot) {
                final factCheck = snapshot.data;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text('Fact Check', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'This checks the current summary against the articles loaded for this selection only.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      Text(
                        'Checking where the sources agree, where they differ, and what still looks uncertain...',
                        style: theme.textTheme.bodyLarge,
                      )
                    else
                      Text(
                        factCheck ??
                            'No AI fact check is available for this selection yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshDigest() async {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
        _typedTexts.clear();
      });
    }

    final freshDigest = await _loadFreshDigest();
    if (!mounted) {
      return;
    }

    if (freshDigest != null) {
      final refreshedSummary = await _summarizeTopicSelection(
        _selectedTopic,
        _leaningPreference,
        _applySelectionFor(
          freshDigest.articles,
          topic: _selectedTopic,
          bias: _leaningPreference,
        ),
      );
      final nextTopicSummaries = <String, String>{
        ...freshDigest.topicSummaries,
      };
      if (refreshedSummary != null) {
        nextTopicSummaries[_selectedTopic] = refreshedSummary;
      }
      final cachedDigest = freshDigest.copyWith(
        topicSummaries: nextTopicSummaries,
      );
      await _writeCachedDigest(cachedDigest);
      setState(() {
        _displayDigest = cachedDigest;
        _topicSummaries = nextTopicSummaries;
        _selectionSummaryFuture = Future<String?>.value(refreshedSummary);
        _selectedFocusTerm = null;
        _focusSummaryFuture = null;
        _isRefreshing = false;
      });
      unawaited(_primeTopicSummaries(cachedDigest));
      return;
    }

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<NewsDigest?> _loadFreshDigest() async {
    final rawArticles = await _fetchArticles();
    if (rawArticles.isEmpty) {
      return null;
    }

    final digest = await _fetchDigest(rawArticles);
    return digest ??
        NewsDigest(
          brief: null,
          articles: rawArticles,
          usedModelInference: false,
          updatedAt: DateTime.now(),
        );
  }

  Future<List<NewsArticle>> _fetchArticles() async {
    try {
      final articleSets = await Future.wait([
        _fetchTheNewsArticles(),
        _fetchNewsDataArticles(),
        _fetchRssArticles(),
      ]);
      return _deduplicateArticles(
        articleSets.expand((articles) => articles).toList(growable: false),
      ).take(_maxFetchedArticles).toList(growable: false);
    } catch (_) {
      return const <NewsArticle>[];
    }
  }

  Future<List<NewsArticle>> _fetchTheNewsArticles() async {
    if (AppSecrets.theNewsApiToken.isEmpty) {
      return const <NewsArticle>[];
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.thenewsapi.com/v1/news/top?api_token=${AppSecrets.theNewsApiToken}&locale=us&language=en&categories=general,politics,business,tech,science,sports,health&limit=$_maxFetchedArticles',
        ),
      );
      if (response.statusCode != 200) {
        return const <NewsArticle>[];
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const <NewsArticle>[];
      }

      final data = payload['data'];
      if (data is! List) {
        return const <NewsArticle>[];
      }

      return Future.wait(
        data
            .whereType<Map<String, dynamic>>()
            .toList(growable: false)
            .asMap()
            .entries
            .map((entry) async {
              final item = entry.value;
              final summary = _normalizeText(
                '${item['description'] ?? item['snippet'] ?? ''}',
              );
              final source = _normalizeText(
                '${item['source'] ?? 'TheNewsAPI'}',
              );
              final url = _normalizeText('${item['url'] ?? ''}');
              final articleBody = await _fetchArticleBody(url);
              final articleContext = _bestArticleContext(summary, articleBody);
              final heuristicScore = _heuristicLeaningScore(
                source,
                articleContext,
              );
              final headline = _normalizeText('${item['title'] ?? 'Untitled'}');
              return NewsArticle(
                section: _theNewsSection(
                  item,
                  source,
                  headline,
                  summary,
                  articleBody,
                ),
                headline: headline,
                summary: summary.isEmpty
                    ? 'No summary returned by TheNewsAPI.'
                    : summary,
                articleBody: articleBody,
                source: source,
                url: url,
                readTime: _estimateReadTime(summary),
                accent: _accentForIndex(entry.key),
                leaningScore: heuristicScore,
                leaningLabel: _leaningLabel(heuristicScore),
                leaningReason: articleBody.isNotEmpty
                    ? 'Estimated from source, headline framing, and extracted article text.'
                    : 'Estimated from source tone, headline framing, and snippet.',
              );
            }),
      );
    } catch (_) {
      return const <NewsArticle>[];
    }
  }

  Future<List<NewsArticle>> _fetchNewsDataArticles() async {
    if (AppSecrets.newsDataApiKey.isEmpty) {
      return const <NewsArticle>[];
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://newsdata.io/api/1/latest?apikey=${AppSecrets.newsDataApiKey}&country=us&language=en&removeduplicate=1&size=10',
        ),
      );
      if (response.statusCode != 200) {
        return const <NewsArticle>[];
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const <NewsArticle>[];
      }

      final results = payload['results'];
      if (results is! List) {
        return const <NewsArticle>[];
      }

      return Future.wait(
        results
            .whereType<Map<String, dynamic>>()
            .toList(growable: false)
            .asMap()
            .entries
            .map((entry) async {
              final item = entry.value;
              final summary = _normalizeText('${item['description'] ?? ''}');
              final source = _normalizeText(
                '${item['source_id'] ?? item['source_name'] ?? 'NewsData.io'}',
              );
              final url = _normalizeText('${item['link'] ?? ''}');
              final content = _normalizeText('${item['content'] ?? ''}');
              final articleBody = content.isNotEmpty
                  ? content
                  : await _fetchArticleBody(url);
              final section = _newsDataSection(item, source);
              final articleContext = _bestArticleContext(summary, articleBody);
              final heuristicScore = _heuristicLeaningScore(
                source,
                articleContext,
              );

              return NewsArticle(
                section: section,
                headline: _normalizeText('${item['title'] ?? 'Untitled'}'),
                summary: summary.isEmpty
                    ? 'No summary returned by NewsData.io.'
                    : summary,
                articleBody: articleBody,
                source: source,
                url: url,
                readTime: _estimateReadTime(
                  articleBody.isNotEmpty ? articleBody : summary,
                ),
                accent: _accentForIndex(entry.key + _maxFetchedArticles),
                leaningScore: heuristicScore,
                leaningLabel: _leaningLabel(heuristicScore),
                leaningReason: articleBody.isNotEmpty
                    ? 'Estimated from source, framing, and NewsData article content.'
                    : 'Estimated from source, framing, and NewsData summary text.',
              );
            }),
      );
    } catch (_) {
      return const <NewsArticle>[];
    }
  }

  Future<List<NewsArticle>> _fetchRssArticles() async {
    final articleSets = await Future.wait(
      _rssSources.map(_fetchSingleRssSource),
    );
    return articleSets.expand((articles) => articles).toList(growable: false);
  }

  Future<List<NewsArticle>> _fetchSingleRssSource(_RssSource source) async {
    try {
      final response = await _fetchTextResponse(source.feedUrl);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <NewsArticle>[];
      }

      final items = _parseRssItems(response.body);
      return items
          .take(_maxItemsPerRssFeed)
          .toList(growable: false)
          .asMap()
          .entries
          .map((entry) {
            final item = entry.value;
            final headline = _normalizeText(item.title);
            final summary = _normalizeText(
              item.description.isEmpty
                  ? 'No summary returned by RSS feed.'
                  : item.description,
            );
            final articleBody = _normalizeText(
              item.content.isNotEmpty ? item.content : item.description,
            );
            final section = item.category != null
                ? (_normalizeTopicLabel(item.category!) ??
                      _inferTopicFromText('$headline $summary $articleBody') ??
                      source.topic)
                : (_inferTopicFromText('$headline $summary $articleBody') ??
                      source.topic);
            final articleContext = _bestArticleContext(summary, articleBody);
            final heuristicScore = _heuristicLeaningScore(
              source.name,
              articleContext,
            );

            return NewsArticle(
              section: section,
              headline: headline.isEmpty ? 'Untitled' : headline,
              summary: summary,
              articleBody: articleBody,
              source: source.name,
              url: item.link,
              readTime: _estimateReadTime(
                articleBody.isNotEmpty ? articleBody : summary,
              ),
              accent: _accentForIndex(entry.key + source.name.length),
              leaningScore: heuristicScore,
              leaningLabel: _leaningLabel(heuristicScore),
              leaningReason: articleBody.isNotEmpty
                  ? 'Estimated from RSS source, headline framing, and feed content.'
                  : 'Estimated from RSS source, headline framing, and feed summary.',
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const <NewsArticle>[];
    }
  }

  List<_RssItem> _parseRssItems(String xml) {
    final itemBlocks = RegExp(
      r'<item\b[^>]*>([\s\S]*?)</item>',
      caseSensitive: false,
    ).allMatches(xml);
    if (itemBlocks.isNotEmpty) {
      return itemBlocks
          .map((match) => _parseRssBlock(match.group(1) ?? ''))
          .whereType<_RssItem>()
          .toList(growable: false);
    }

    final entryBlocks = RegExp(
      r'<entry\b[^>]*>([\s\S]*?)</entry>',
      caseSensitive: false,
    ).allMatches(xml);
    return entryBlocks
        .map((match) => _parseAtomBlock(match.group(1) ?? ''))
        .whereType<_RssItem>()
        .toList(growable: false);
  }

  _RssItem? _parseRssBlock(String block) {
    final title = _extractXmlTag(block, 'title');
    final link = _extractXmlTag(block, 'link');
    final description =
        _extractXmlTag(block, 'description') ??
        _extractXmlTag(block, 'summary');
    final content =
        _extractXmlTag(block, 'content:encoded') ??
        _extractXmlTag(block, 'content');
    final category = _extractXmlTag(block, 'category');

    if ((title == null || title.trim().isEmpty) &&
        (description == null || description.trim().isEmpty)) {
      return null;
    }

    return _RssItem(
      title: title ?? 'Untitled',
      link: link ?? '',
      description: description ?? '',
      content: content ?? '',
      category: category,
    );
  }

  _RssItem? _parseAtomBlock(String block) {
    final title = _extractXmlTag(block, 'title');
    final description =
        _extractXmlTag(block, 'summary') ?? _extractXmlTag(block, 'content');
    final content = _extractXmlTag(block, 'content') ?? '';
    final categoryMatch = RegExp(
      r'<category\b[^>]*term="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(block);
    final linkMatch = RegExp(
      r'<link\b[^>]*href="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(block);

    if ((title == null || title.trim().isEmpty) &&
        (description == null || description.trim().isEmpty)) {
      return null;
    }

    return _RssItem(
      title: title ?? 'Untitled',
      link: linkMatch?.group(1) ?? '',
      description: description ?? '',
      content: content,
      category: categoryMatch?.group(1),
    );
  }

  String? _extractXmlTag(String xml, String tagName) {
    final match = RegExp(
      '<$tagName\\b[^>]*>([\\s\\S]*?)</$tagName>',
      caseSensitive: false,
    ).firstMatch(xml);
    if (match == null) {
      return null;
    }
    return _normalizeText(match.group(1) ?? '');
  }

  List<NewsArticle> _deduplicateArticles(List<NewsArticle> articles) {
    final seenUrls = <String>{};
    final seenHeadlineFingerprints = <String>{};
    final deduplicated = <NewsArticle>[];

    for (final article in articles) {
      final normalizedUrl = article.url.trim().toLowerCase();
      if (normalizedUrl.isNotEmpty && !seenUrls.add(normalizedUrl)) {
        continue;
      }

      final headlineFingerprint = _headlineFingerprint(article.headline);
      if (headlineFingerprint.isNotEmpty &&
          _isNearDuplicateHeadline(
            headlineFingerprint,
            seenHeadlineFingerprints,
          )) {
        continue;
      }

      if (headlineFingerprint.isNotEmpty) {
        seenHeadlineFingerprints.add(headlineFingerprint);
      }
      deduplicated.add(article);
    }

    return deduplicated;
  }

  String _headlineFingerprint(String headline) {
    final cleaned = headline
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return '';
    }

    const stopwords = <String>{
      'a',
      'an',
      'and',
      'are',
      'as',
      'at',
      'be',
      'by',
      'for',
      'from',
      'in',
      'into',
      'is',
      'it',
      'of',
      'on',
      'or',
      'over',
      'says',
      'that',
      'the',
      'to',
      'with',
    };

    final tokens =
        cleaned
            .split(' ')
            .where((token) => token.length > 2 && !stopwords.contains(token))
            .take(8)
            .toList(growable: false)
          ..sort();
    return tokens.join(' ');
  }

  bool _isNearDuplicateHeadline(
    String fingerprint,
    Set<String> existingFingerprints,
  ) {
    if (fingerprint.isEmpty) {
      return false;
    }

    final fingerprintTokens = fingerprint
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();

    for (final existing in existingFingerprints) {
      final existingTokens = existing
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toSet();
      final overlap = fingerprintTokens.intersection(existingTokens).length;
      final baseline = fingerprintTokens.length < existingTokens.length
          ? fingerprintTokens.length
          : existingTokens.length;
      if (baseline > 0 && overlap >= baseline - 1) {
        return true;
      }
    }

    return false;
  }

  String _newsDataSection(Map<String, dynamic> item, String source) {
    final category = item['category'];
    if (category is List && category.isNotEmpty) {
      final firstCategory = _normalizeText('${category.first}');
      if (firstCategory.isNotEmpty) {
        return _titleCase(firstCategory);
      }
    }
    if (category is String && category.trim().isNotEmpty) {
      return _titleCase(_normalizeText(category));
    }
    return _sectionForSource(source);
  }

  String _theNewsSection(
    Map<String, dynamic> item,
    String source,
    String headline,
    String summary,
    String articleBody,
  ) {
    final categories = item['categories'];
    if (categories is List && categories.isNotEmpty) {
      final mapped = _normalizeTopicLabel(
        _normalizeText('${categories.first}'),
      );
      if (mapped != null) {
        return mapped;
      }
    }
    if (categories is String && categories.trim().isNotEmpty) {
      final mapped = _normalizeTopicLabel(_normalizeText(categories));
      if (mapped != null) {
        return mapped;
      }
    }

    final inferred = _inferTopicFromText(
      '$headline $summary ${_truncateForPrompt(articleBody, 600)}',
    );
    if (inferred != null) {
      return inferred;
    }

    return _sectionForSource(source);
  }

  Future<NewsDigest?> _fetchDigest(List<NewsArticle> articles) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://royal-union-f92a.charlh048.workers.dev/v1/chat/completions',
        ),
        headers: {
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://newron.local',
          'X-Title': 'Newron News App',
        },
        body: jsonEncode({
          'model': _selectedModelId,
          'web_search': true, // Enable research tools for main digest
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are building a research-augmented news digest for the Newron app. Infer political leaning from all provided context. Use your search tools to find the latest updates if the provided info is thin. Consolidate overlapping stories. Return strict JSON with keys "brief" and "articles". "brief" must be 2 concise sentences. "articles" must match input order, each with keys "headline", "leaning_score", "leaning_label", and "leaning_reason".',
            },
            {
              'role': 'user',
              'content':
                  'Analyze these news items and use your tools to find missing context:\n${_articlesPrompt(articles)}',
            },
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final choice = choices.first;
      if (choice is! Map<String, dynamic>) {
        return null;
      }

      final message = choice['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }

      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        return null;
      }

      final decoded = _decodeModelJson(content);
      if (decoded == null) {
        return null;
      }

      final brief = decoded['brief'];
      final articleMaps = decoded['articles'];
      if (brief is! String || articleMaps is! List) {
        return null;
      }

      final enrichedArticles = <NewsArticle>[];
      for (var index = 0; index < articles.length; index++) {
        final baseArticle = articles[index];
        final item = index < articleMaps.length ? articleMaps[index] : null;
        if (item is! Map<String, dynamic>) {
          enrichedArticles.add(baseArticle);
          continue;
        }

        final score = _clampScore(item['leaning_score']);
        final label = item['leaning_label'] is String
            ? _normalizeLabel(item['leaning_label'] as String)
            : _leaningLabel(score);
        final reason = item['leaning_reason'] is String
            ? (item['leaning_reason'] as String).trim()
            : 'Estimated from framing, topic selection, and wording.';

        enrichedArticles.add(
          baseArticle.copyWith(
            leaningScore: score,
            leaningLabel: label,
            leaningReason: reason,
          ),
        );
      }

      return NewsDigest(
        brief: brief.trim().isEmpty ? null : brief.trim(),
        articles: enrichedArticles,
        usedModelInference: true,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _summarizeTopicSelection(
    String topic,
    double bias,
    List<NewsArticle> articles,
  ) async {
    if (articles.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://royal-union-f92a.charlh048.workers.dev/v1/chat/completions',
        ),
        headers: {
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://newron.local',
          'X-Title': 'Newron News App',
        },
        body: jsonEncode({
          'model': _selectedModelId,
          'web_search': true, // Enable research tools for topic summaries
          'messages': [
            {
              'role': 'system',
              'content':
                  'You write fun, smart, research-augmented news briefings. Use your tools to find the most recent developments on this topic. Organize it into 6 short sections with emoji headers. Each section should have 2 to 4 sentences. Use a lively voice and keep everything plain text only.',
            },
            {
              'role': 'user',
              'content':
                  'Topic: $topic\nBias lens: ${_sliderLabel(bias)}\nLocal Articles: ${_articlesPrompt(articles)}',
            },
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final choice = choices.first;
      if (choice is! Map<String, dynamic>) {
        return null;
      }

      final message = choice['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }

      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        return null;
      }

      return _normalizeExternalText(content);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _summarizeFocusTerm(
    String focusTerm,
    List<NewsArticle> articles,
  ) async {
    final relatedArticles = _articlesForFocusTerm(articles, focusTerm);
    if (relatedArticles.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://royal-union-f92a.charlh048.workers.dev/v1/chat/completions',
        ),
        headers: {
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://newron.local',
          'X-Title': 'Newron News App',
        },
        body: jsonEncode({
          'model': _selectedModelId,
          'web_search': true, // Signal to the worker to use DDGS/Search
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a research assistant for the Newron news app. Use the provided web search results and articles to explain the requested topic in 3-4 concise paragraphs. Use a smart, lively voice and include emojis. Focus on facts and recent developments. Plain text only.',
            },
            {
              'role': 'user',
              'content':
                  'Topic to research: $focusTerm\nBias lens: ${_sliderLabel(_leaningPreference)}\nLocal Articles: ${_articlesPrompt(relatedArticles)}',
            },
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final choice = choices.first;
      if (choice is! Map<String, dynamic>) {
        return null;
      }

      final message = choice['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }

      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        return null;
      }

      return _normalizeExternalText(content);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _factCheckSelection({
    required String topic,
    required double bias,
    required List<NewsArticle> articles,
  }) async {
    if (articles.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://royal-union-f92a.charlh048.workers.dev/v1/chat/completions',
        ),
        headers: {
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://newron.local',
          'X-Title': 'Newron News App',
        },
        body: jsonEncode({
          'model': _selectedModelId,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a careful fact-check assistant for a text-only briefing app. Using only the provided articles, write a plain-text fact check in 4 short sections with emoji headers: what most sources agree on, what is still disputed or unclear, what looks overstated or weakly supported, and the bottom line. Be concrete and cautious. Do not claim verification outside the provided reporting. Do not mention that you are an AI.',
            },
            {
              'role': 'user',
              'content':
                  'Topic: $topic\nBias lens requested by user: ${_sliderLabel(bias)}\nFact-check the current summary against these articles only:\n${_articlesPrompt(articles)}',
            },
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final choice = choices.first;
      if (choice is! Map<String, dynamic>) {
        return null;
      }

      final message = choice['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }

      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        return null;
      }

      return _normalizeExternalText(content);
    } catch (_) {
      return null;
    }
  }

  Future<_TextResponse> _fetchTextResponse(String url) async {
    try {
      if (!kIsWeb) {
        final response = await http
            .get(
              Uri.parse(url),
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
              },
            )
            .timeout(const Duration(seconds: 12));
        return _TextResponse(
          statusCode: response.statusCode,
          body: response.body,
        );
      }

      final proxiedUrl =
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      final response = await http
          .get(Uri.parse(proxiedUrl))
          .timeout(const Duration(seconds: 12));
      return _TextResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    } catch (_) {
      return const _TextResponse(statusCode: 500, body: '');
    }
  }

  Map<String, dynamic>? _decodeModelJson(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (match == null) {
        return null;
      }
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  String _articlesPrompt(List<NewsArticle> articles) {
    return articles
        .asMap()
        .entries
        .map((entry) {
          final article = entry.value;
          final sanitizedHeadline = _sanitizeForModel(article.headline);
          final sanitizedSource = _sanitizeForModel(article.source);
          final sanitizedSummary = _sanitizeForModel(article.summary);
          final sanitizedBody = _sanitizeForModel(
            _truncateForPrompt(article.articleBody, 2200),
          );
          return '${entry.key + 1}. Headline: $sanitizedHeadline\n'
              'Source: $sanitizedSource\n'
              'Snippet: $sanitizedSummary\n'
              'Article body excerpt: $sanitizedBody\n';
        })
        .join('\n');
  }

  String _sanitizeForModel(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '[redacted email]',
        )
        .replaceAll(
          RegExp(
            r'\b(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{3}\)?[\s.-]?)\d{3}[\s.-]?\d{4}\b',
          ),
          '[redacted phone]',
        )
        .replaceAll(RegExp(r'\b(?:\d[ -]*?){13,19}\b'), '[redacted number]')
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '[redacted ip]')
        .replaceAll(
          RegExp(
            r'\b(?:sk|pk|rk|api|token)[-_a-zA-Z0-9]{12,}\b',
            caseSensitive: false,
          ),
          '[redacted credential]',
        )
        .replaceAll(
          RegExp(r'https?://\S+', caseSensitive: false),
          '[redacted url]',
        )
        .replaceAll(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), '[redacted id]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _emptyTopicSummary(String topic) {
    return 'There is not enough distinct current reporting in $topic yet to build an AI summary.';
  }

  Future<String> _fetchArticleBody(String? url) async {
    if (url == null || url.isEmpty) {
      return '';
    }

    try {
      final response = await _fetchTextResponse(url);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }

      final html = response.body;
      final paragraphMatches = RegExp(
        r'<p\b[^>]*>([\s\S]*?)</p>',
        caseSensitive: false,
      ).allMatches(html);

      final paragraphs = paragraphMatches
          .map((match) => _normalizeText(match.group(1) ?? ''))
          .where((paragraph) => paragraph.length > 60)
          .take(8)
          .toList(growable: false);

      if (paragraphs.isNotEmpty) {
        return paragraphs.join(' ');
      }

      final articleMatch = RegExp(
        r'<article\b[^>]*>([\s\S]*?)</article>',
        caseSensitive: false,
      ).firstMatch(html);
      if (articleMatch == null) {
        return '';
      }

      return _normalizeText(articleMatch.group(1) ?? '');
    } catch (_) {
      return '';
    }
  }

  String _normalizeText(String value) {
    return _stripInvalidUtf16(
      value
          .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&apos;', "'")
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }

  String _normalizeExternalText(String value) {
    return _stripInvalidUtf16(value).trim();
  }

  String _stripInvalidUtf16(String value) {
    if (value.isEmpty) {
      return value;
    }

    final units = value.codeUnits;
    final sanitized = <int>[];
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      final isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
      final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;

      if (isHighSurrogate) {
        if (index + 1 < units.length) {
          final next = units[index + 1];
          if (next >= 0xDC00 && next <= 0xDFFF) {
            sanitized.add(unit);
            sanitized.add(next);
            index++;
          }
        }
        continue;
      }

      if (isLowSurrogate) {
        continue;
      }

      sanitized.add(unit);
    }

    return String.fromCharCodes(sanitized);
  }

  String _bestArticleContext(String description, String articleBody) {
    if (articleBody.isNotEmpty) {
      return articleBody;
    }
    return description;
  }

  String _truncateForPrompt(String value, int maxLength) {
    if (value.isEmpty) {
      return 'Unavailable';
    }
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.characters.take(maxLength).toString()}...';
  }

  String _sectionForSource(String source) {
    final lowered = source.toLowerCase();
    if (lowered.contains('tech') || lowered.contains('verge')) {
      return 'Technology';
    }
    if (lowered.contains('policy') || lowered.contains('government')) {
      return 'Policy';
    }
    if (lowered.contains('market') || lowered.contains('business')) {
      return 'Markets';
    }
    if (lowered.contains('research') || lowered.contains('science')) {
      return 'Research';
    }
    if (lowered.contains('sport') || lowered.contains('espn')) {
      return 'Sports';
    }
    if (lowered.contains('health') || lowered.contains('medical')) {
      return 'Health';
    }
    if (lowered.contains('world') || lowered.contains('international')) {
      return 'World';
    }
    return 'Live Feed';
  }

  String _estimateReadTime(String description) {
    final wordCount = _normalizeText(
      description,
    ).split(' ').where((word) => word.isNotEmpty).length;
    final minutes = (wordCount / 120).ceil().clamp(1, 6);
    return '$minutes min read';
  }

  Color _accentForIndex(int index) {
    const palette = <Color>[
      Color(0xFFEE6C4D),
      Color(0xFF2A9D8F),
      Color(0xFF264653),
      Color(0xFFE9C46A),
      Color(0xFFD62828),
    ];
    return palette[index % palette.length];
  }

  double _heuristicLeaningScore(String source, String context) {
    final combined = '${source.toLowerCase()} ${context.toLowerCase()}';
    if (combined.contains('fox') || combined.contains('national review')) {
      return 0.65;
    }
    if (combined.contains('msnbc') || combined.contains('guardian')) {
      return -0.65;
    }
    if (combined.contains('government') || combined.contains('policy')) {
      return -0.15;
    }
    return 0;
  }

  double _clampScore(Object? value) {
    if (value is num) {
      return value.toDouble().clamp(-1.0, 1.0);
    }
    if (value is String) {
      return (double.tryParse(value) ?? 0).clamp(-1.0, 1.0);
    }
    return 0;
  }

  String _normalizeLabel(String value) {
    final lowered = value.trim().toLowerCase();
    if (lowered.startsWith('left')) {
      return 'Left';
    }
    if (lowered.startsWith('right')) {
      return 'Right';
    }
    return 'Center';
  }

  String _leaningLabel(double score) {
    if (score <= -0.2) {
      return 'Left';
    }
    if (score >= 0.2) {
      return 'Right';
    }
    return 'Center';
  }

  String _sliderLabel(double value) {
    if (value <= -0.35) {
      return 'Left';
    }
    if (value >= 0.35) {
      return 'Right';
    }
    return 'Center';
  }

  List<NewsArticle> _applySelection(List<NewsArticle> articles) {
    return _applySelectionFor(
      articles,
      topic: _selectedTopic,
      bias: _leaningPreference,
    );
  }

  List<NewsArticle> _applySelectionFor(
    List<NewsArticle> articles, {
    required String topic,
    required double bias,
  }) {
    final topicArticles = _filterByTopic(articles, topic);
    return _filteredArticles(topicArticles, bias: bias);
  }

  List<NewsArticle> _filterByTopic(List<NewsArticle> articles, String topic) {
    if (topic == 'Top Stories') {
      return articles;
    }

    final scored =
        articles
            .map(
              (article) =>
                  (article: article, score: _topicMatchScore(article, topic)),
            )
            .where((entry) => entry.score > 0)
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.map((entry) => entry.article).toList(growable: false);
  }

  List<String> _topicKeywords(String topic) {
    return switch (topic) {
      'World' => ['world', 'international', 'foreign', 'global'],
      'Politics' => [
        'politic',
        'election',
        'congress',
        'white house',
        'senate',
      ],
      'Business' => [
        'business',
        'market',
        'economy',
        'company',
        'trade',
        'stock',
      ],
      'Technology' => [
        'tech',
        'software',
        'ai',
        'apple',
        'google',
        'microsoft',
      ],
      'Science' => ['science', 'research', 'study', 'space', 'climate'],
      'Health' => ['health', 'medical', 'disease', 'hospital', 'drug'],
      'Sports' => ['sport', 'nfl', 'nba', 'mlb', 'soccer', 'olympic'],
      'Policy' => ['policy', 'regulation', 'law', 'court', 'government'],
      _ => <String>[],
    };
  }

  int _topicMatchScore(NewsArticle article, String topic) {
    final section = article.section.toLowerCase();
    final topicLower = topic.toLowerCase();
    final haystack =
        '${article.section} ${article.headline} ${article.summary} ${article.articleBody}'
            .toLowerCase();
    var score = 0;

    if (section == topicLower) {
      score += 6;
    } else if (section.contains(topicLower)) {
      score += 4;
    }

    for (final keyword in _topicKeywords(topic)) {
      if (haystack.contains(keyword)) {
        score += 2;
      }
    }

    return score;
  }

  String? _normalizeTopicLabel(String value) {
    final lowered = value.toLowerCase();
    if (lowered.contains('politic')) {
      return 'Politics';
    }
    if (lowered.contains('business') || lowered.contains('finance')) {
      return 'Business';
    }
    if (lowered.contains('tech')) {
      return 'Technology';
    }
    if (lowered.contains('science')) {
      return 'Science';
    }
    if (lowered.contains('health')) {
      return 'Health';
    }
    if (lowered.contains('sport')) {
      return 'Sports';
    }
    if (lowered.contains('policy') || lowered.contains('government')) {
      return 'Policy';
    }
    if (lowered.contains('world') || lowered.contains('international')) {
      return 'World';
    }
    return null;
  }

  String? _inferTopicFromText(String text) {
    final lowered = text.toLowerCase();
    var bestTopic = 'Top Stories';
    var bestScore = 0;

    for (final topic in categories.where((topic) => topic != 'Top Stories')) {
      final score = _topicKeywords(topic).where(lowered.contains).length;
      if (score > bestScore) {
        bestScore = score;
        bestTopic = topic;
      }
    }

    return bestScore > 0 ? bestTopic : null;
  }

  List<String> _focusTermsForArticles(List<NewsArticle> articles) {
    final scoreByTerm = <String, int>{};

    for (final article in articles) {
      final terms = _extractArticleTerms(article);
      for (final term in terms) {
        scoreByTerm.update(term, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final rankedTerms = scoreByTerm.entries.toList()
      ..sort((a, b) {
        final scoreComparison = b.value.compareTo(a.value);
        if (scoreComparison != 0) {
          return scoreComparison;
        }
        return a.key.compareTo(b.key);
      });

    return rankedTerms
        .map((entry) => entry.key)
        .take(6)
        .toList(growable: false);
  }

  List<String> _extractArticleTerms(NewsArticle article) {
    final candidates = <String>{};
    final titleMatches = RegExp(
      r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b',
    ).allMatches(article.headline);

    for (final match in titleMatches) {
      final value = (match.group(0) ?? '').trim();
      if (_isUsefulFocusTerm(value)) {
        candidates.add(value);
      }
    }

    final tokenMatches = RegExp(
      r"\b[A-Za-z][A-Za-z'-]{3,}\b",
    ).allMatches('${article.headline} ${article.summary}');
    for (final match in tokenMatches) {
      final token = _titleCase((match.group(0) ?? '').trim());
      if (_isUsefulFocusTerm(token)) {
        candidates.add(token);
      }
      if (candidates.length >= 10) {
        break;
      }
    }

    return candidates.take(6).toList(growable: false);
  }

  bool _isUsefulFocusTerm(String value) {
    const blocked = <String>{
      'The',
      'That',
      'This',
      'With',
      'From',
      'What',
      'When',
      'Where',
      'After',
      'Before',
      'Under',
      'About',
      'Against',
      'United States',
      'Breaking News',
      'Top Stories',
    };

    if (value.length < 4 || blocked.contains(value)) {
      return false;
    }

    final lowered = value.toLowerCase();
    const stopwords = <String>{
      'news',
      'story',
      'stories',
      'latest',
      'video',
      'update',
      'updates',
      'report',
      'reports',
      'analysis',
      'today',
      'says',
    };

    if (stopwords.contains(lowered)) {
      return false;
    }

    return true;
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  List<NewsArticle> _articlesForFocusTerm(
    List<NewsArticle> articles,
    String focusTerm,
  ) {
    final loweredTerm = focusTerm.toLowerCase();
    final matches = articles
        .where((article) {
          final haystack =
              '${article.headline} ${article.summary} ${article.articleBody}'
                  .toLowerCase();
          return haystack.contains(loweredTerm);
        })
        .toList(growable: false);
    if (matches.isNotEmpty) {
      return matches.take(_maxFocusSourceArticles).toList(growable: false);
    }
    return articles.take(_maxFocusSourceArticles).toList(growable: false);
  }

  void _selectFocusTerm(String focusTerm) {
    final digest = _displayDigest;
    if (digest == null) {
      return;
    }

    final selectedArticles = _applySelection(digest.articles);
    setState(() {
      if (_selectedFocusTerm == focusTerm) {
        _selectedFocusTerm = null;
        _focusSummaryFuture = null;
        return;
      }
      _selectedFocusTerm = focusTerm;
      _focusSummaryFuture = _summarizeFocusTerm(focusTerm, selectedArticles);
    });
  }

  void _updateSelection({String? topic, double? bias}) {
    final digest = _displayDigest;
    final nextTopic = topic ?? _selectedTopic;
    final nextBias = bias ?? _leaningPreference;
    final biasChanged = bias != null && bias != _leaningPreference;

    setState(() {
      if (topic != null) {
        _selectedTopic = topic;
      }
      if (bias != null) {
        _leaningPreference = bias;
      }
      if (biasChanged) {
        _topicSummaries = <String, String>{};
      }
      if (digest != null) {
        final cachedSummary = _topicSummaries[nextTopic];
        if (cachedSummary != null && !biasChanged) {
          _selectionSummaryFuture = Future<String?>.value(cachedSummary);
        } else {
          _selectionSummaryFuture = _summarizeTopicSelection(
            nextTopic,
            nextBias,
            _applySelectionFor(
              digest.articles,
              topic: nextTopic,
              bias: nextBias,
            ),
          );
        }
      }
      _selectedFocusTerm = null;
      _focusSummaryFuture = null;
    });

    if (digest != null && biasChanged) {
      final rebasedDigest = digest.copyWith(
        topicSummaries: const <String, String>{},
      );
      unawaited(_writeCachedDigest(rebasedDigest));
      unawaited(_primeTopicSummaries(rebasedDigest));
    }
  }

  Future<void> _primeTopicSummaries(NewsDigest digest) async {
    for (final topic in categories) {
      if (!mounted) {
        return;
      }
      if (_topicSummaries.containsKey(topic)) {
        continue;
      }

      final articles = _applySelectionFor(
        digest.articles,
        topic: topic,
        bias: _leaningPreference,
      );
      if (articles.isEmpty) {
        continue;
      }

      final summary = await _summarizeTopicSelection(
        topic,
        _leaningPreference,
        articles,
      );
      if (!mounted || summary == null) {
        continue;
      }

      final updatedTopicSummaries = <String, String>{
        ..._topicSummaries,
        topic: summary,
      };
      final updatedDigest = (_displayDigest ?? digest).copyWith(
        topicSummaries: updatedTopicSummaries,
      );
      await _writeCachedDigest(updatedDigest);
      if (!mounted) {
        return;
      }
      setState(() {
        _topicSummaries = updatedTopicSummaries;
        _displayDigest = updatedDigest;
        if (_selectedTopic == topic) {
          _selectionSummaryFuture = Future<String?>.value(summary);
        }
      });
    }
  }

  String? _bestVisibleSummary(NewsDigest digest) {
    final cachedTopicSummary = digest.topicSummaries[_selectedTopic];
    if (cachedTopicSummary != null && cachedTopicSummary.isNotEmpty) {
      return cachedTopicSummary;
    }

    final stateTopicSummary = _topicSummaries[_selectedTopic];
    if (stateTopicSummary != null && stateTopicSummary.isNotEmpty) {
      return stateTopicSummary;
    }

    final selectedArticles = _applySelection(digest.articles);
    if (selectedArticles.isEmpty) {
      return _selectedTopic == 'Top Stories'
          ? digest.brief
          : _emptyTopicSummary(_selectedTopic);
    }
    return digest.brief;
  }

  Future<void> _writeCachedDigest(NewsDigest digest) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cacheKey);
    await preferences.setString(_cacheKey, jsonEncode(digest.toJson()));
  }

  Future<NewsDigest?> _readCachedDigest() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final payload = jsonDecode(raw);
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      return NewsDigest.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  List<NewsArticle> _filteredArticles(
    List<NewsArticle> articles, {
    required double bias,
  }) {
    final filtered = articles
        .where((article) => (article.leaningScore - bias).abs() <= 0.75)
        .toList(growable: false);

    if (filtered.isNotEmpty) {
      return filtered;
    }

    final sorted = [...articles]
      ..sort(
        (a, b) => (a.leaningScore - bias).abs().compareTo(
          (b.leaningScore - bias).abs(),
        ),
      );
    return sorted.take(_maxFallbackTopicArticles).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panel = isDark ? const Color(0xFF36302A) : const Color(0xFF171717);
    final chipBg = isDark ? const Color(0xFF4A4239) : const Color(0xFFD0B89B);

    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final digest = _displayDigest;
            final allArticles = digest?.articles ?? const <NewsArticle>[];
            final visibleArticles = _applySelection(allArticles);
            final focusTerms = _focusTermsForArticles(visibleArticles);
            final brief = digest?.brief;
            final hasArticles = allArticles.isNotEmpty;

            return RefreshIndicator(
              onRefresh: _refreshDigest,
              child: SelectionArea(
                onSelectionChanged: (selection) {
                  _lastSelection = selection?.plainText;
                },
                contextMenuBuilder: (context, selectableRegionState) {
                  final buttonItems =
                      selectableRegionState.contextMenuButtonItems;
                  buttonItems.insert(
                    0,
                    ContextMenuButtonItem(
                      label: 'Go Deeper',
                      onPressed: () {
                        selectableRegionState.hideToolbar();
                        if (_lastSelection != null &&
                            _lastSelection!.isNotEmpty) {
                          _selectFocusTerm(_lastSelection!.trim());
                        }
                      },
                    ),
                  );
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableRegionState.contextMenuAnchors,
                    buttonItems: buttonItems,
                  );
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'NEWRON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _openSettingsSheet,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        IconButton(
                          onPressed: _isRefreshing ? null : _refreshDigest,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          onPressed: widget.onToggleTheme,
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          ),
                        ),
                        if (_isRefreshing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final topic = categories[index];
                          final isActive = topic == _selectedTopic;
                          return ChoiceChip(
                            label: Text(topic),
                            selected: isActive,
                            onSelected: (_) => _updateSelection(topic: topic),
                            backgroundColor: chipBg,
                            selectedColor: panel,
                            labelStyle: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(_selectedTopic, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: hasArticles
                              ? () => _openSourcesSheet(visibleArticles)
                              : null,
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('Sources'),
                        ),
                        TextButton.icon(
                          onPressed: hasArticles
                              ? () => _openFactCheckSheet(visibleArticles)
                              : null,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Fact check'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (hasArticles)
                      FutureBuilder<String?>(
                        future: _selectionSummaryFuture,
                        builder: (context, summarySnapshot) {
                          final isWaiting =
                              summarySnapshot.connectionState ==
                              ConnectionState.waiting;

                          if (isWaiting) {
                            return Text(
                              'Researching and building summary...',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withOpacity(0.7),
                                fontSize: 17,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          final summary =
                              summarySnapshot.data ??
                              (visibleArticles.isEmpty
                                  ? (_selectedTopic == 'Top Stories'
                                        ? (brief ??
                                              'No AI summary is available yet.')
                                        : _emptyTopicSummary(_selectedTopic))
                                  : (brief ??
                                        'No AI summary is available yet.'));
                          return TypewriterText(
                            text: summary,
                            animate: !_typedTexts.contains(summary),
                            onComplete: () => _typedTexts.add(summary),
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 17,
                              height: 1.6,
                            ),
                            key: ValueKey(summary),
                          );
                        },
                      ),
                    if (!hasArticles)
                      Text(
                        'Building the latest summary...',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 17,
                          height: 1.6,
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_selectedFocusTerm != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedFocusTerm!,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedFocusTerm = null;
                                _focusSummaryFuture = null;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<String?>(
                        future: _focusSummaryFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text(
                              'Searching the web and analyzing...',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color
                                    ?.withOpacity(0.7),
                                fontSize: 16,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }
                          final focusSummary =
                              snapshot.data ??
                              'No AI explainer is available for this thread yet.';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TypewriterText(
                                text: focusSummary,
                                animate: !_typedTexts.contains(focusSummary),
                                onComplete: () => _typedTexts.add(focusSummary),
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                  height: 1.6,
                                ),
                                key: ValueKey(
                                  'focus:${_selectedFocusTerm!}:$focusSummary',
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Sources',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._articlesForFocusTerm(
                                visibleArticles,
                                _selectedFocusTerm!,
                              ).map(
                                (article) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${article.source}: ${article.headline}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      hasArticles
                          ? _isRefreshing
                                ? 'Showing saved coverage while newer reporting loads.'
                                : '${visibleArticles.length} articles informed this summary across live sources.'
                          : 'Background loading is still in progress.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class NewsDigest {
  const NewsDigest({
    required this.brief,
    required this.articles,
    required this.usedModelInference,
    required this.updatedAt,
    this.topicSummaries = const <String, String>{},
  });

  final String? brief;
  final List<NewsArticle> articles;
  final bool usedModelInference;
  final DateTime updatedAt;
  final Map<String, String> topicSummaries;

  NewsDigest copyWith({
    String? brief,
    List<NewsArticle>? articles,
    bool? usedModelInference,
    DateTime? updatedAt,
    Map<String, String>? topicSummaries,
  }) {
    return NewsDigest(
      brief: brief ?? this.brief,
      articles: articles ?? this.articles,
      usedModelInference: usedModelInference ?? this.usedModelInference,
      updatedAt: updatedAt ?? this.updatedAt,
      topicSummaries: topicSummaries ?? this.topicSummaries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brief': brief,
      'articles': articles.map((article) => article.toJson()).toList(),
      'usedModelInference': usedModelInference,
      'updatedAt': updatedAt.toIso8601String(),
      'topicSummaries': topicSummaries,
    };
  }

  factory NewsDigest.fromJson(Map<String, dynamic> json) {
    final articleList = json['articles'];
    final topicSummaries = json['topicSummaries'];
    return NewsDigest(
      brief: json['brief'] as String?,
      articles: articleList is List
          ? articleList
                .whereType<Map<String, dynamic>>()
                .map(NewsArticle.fromJson)
                .toList(growable: false)
          : const <NewsArticle>[],
      usedModelInference: json['usedModelInference'] == true,
      updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime.now(),
      topicSummaries: topicSummaries is Map
          ? topicSummaries.map((key, value) => MapEntry('$key', '$value'))
          : const <String, String>{},
    );
  }
}

class _TextResponse {
  const _TextResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ModelOption {
  const _ModelOption({
    required this.id,
    required this.label,
    required this.subtitle,
  });

  final String id;
  final String label;
  final String subtitle;
}

class _RssItem {
  const _RssItem({
    required this.title,
    required this.link,
    required this.description,
    required this.content,
    this.category,
  });

  final String title;
  final String link;
  final String description;
  final String content;
  final String? category;
}

class _RssSource {
  const _RssSource({
    required this.name,
    required this.feedUrl,
    required this.topic,
  });

  final String name;
  final String feedUrl;
  final String topic;
}

const _rssSources = <_RssSource>[
  _RssSource(
    name: 'CBS News',
    feedUrl: 'https://www.cbsnews.com/latest/rss/main',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Los Angeles Times',
    feedUrl: 'https://www.latimes.com/local/rss2.0.xml',
    topic: 'World',
  ),
  _RssSource(
    name: 'Mercury News',
    feedUrl: 'https://www.mercurynews.com/feed',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'MinnPost',
    feedUrl: 'https://www.minnpost.com/feed',
    topic: 'Policy',
  ),
  _RssSource(name: 'WTOP', feedUrl: 'https://wtop.com/feed', topic: 'Politics'),
  _RssSource(
    name: 'New York Daily News',
    feedUrl: 'https://www.nydailynews.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Newsweek',
    feedUrl: 'https://www.newsweek.com/rss',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'Yahoo News',
    feedUrl: 'https://www.yahoo.com/news/rss',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Boston.com',
    feedUrl: 'https://www.boston.com/feed',
    topic: 'Sports',
  ),
  _RssSource(
    name: 'WGN-TV',
    feedUrl: 'https://wgntv.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'KTLA',
    feedUrl: 'https://ktla.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'ABC7 San Francisco',
    feedUrl: 'https://abc7news.com/feed',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'ABC13 Houston',
    feedUrl: 'https://abc13.com/feed',
    topic: 'Business',
  ),
  _RssSource(
    name: 'KXAN',
    feedUrl: 'https://www.kxan.com/feed',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'FOX31 Denver',
    feedUrl: 'https://kdvr.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'WFLA',
    feedUrl: 'https://www.wfla.com/feed',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'KRON4',
    feedUrl: 'https://www.kron4.com/feed',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'WSVN Miami',
    feedUrl: 'https://wsvn.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'WIVB Buffalo',
    feedUrl: 'https://www.wivb.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: '7News Boston',
    feedUrl: 'https://whdh.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'NEWS10 ABC',
    feedUrl: 'https://www.news10.com/feed',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'Observer',
    feedUrl: 'https://observer.com/feed',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Pioneer Press',
    feedUrl: 'https://www.twincities.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'PhillyVoice',
    feedUrl: 'https://www.phillyvoice.com/feed',
    topic: 'Health',
  ),
  _RssSource(
    name: 'Times of San Diego',
    feedUrl: 'https://timesofsandiego.com/feed',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'Miami Today',
    feedUrl: 'https://miamitodaynews.com/feed',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Texas Observer',
    feedUrl: 'https://www.texasobserver.org/feed',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'Denver Westword',
    feedUrl: 'https://www.westword.com/denver/Rss.xml',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Detroit Metro Times',
    feedUrl: 'https://www.metrotimes.com/detroit/Rss.xml',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Forest Hills Times',
    feedUrl: 'https://foresthillstimes.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Published Reporter',
    feedUrl: 'https://www.publishedreporter.com/feed',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'New York Post',
    feedUrl: 'https://nypost.com/feed',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Breitbart',
    feedUrl: 'https://feeds.feedburner.com/breitbart',
    topic: 'Politics',
  ),
  _RssSource(
    name: 'NYT Home',
    feedUrl: 'https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Washington Post World',
    feedUrl: 'http://feeds.washingtonpost.com/rss/world',
    topic: 'World',
  ),
  _RssSource(
    name: 'BBC World',
    feedUrl: 'http://feeds.bbci.co.uk/news/world/rss.xml',
    topic: 'World',
  ),
  _RssSource(
    name: 'Guardian World',
    feedUrl: 'https://www.theguardian.com/world/rss',
    topic: 'World',
  ),
  _RssSource(
    name: 'CNN World',
    feedUrl: 'http://rss.cnn.com/rss/edition_world.rss',
    topic: 'World',
  ),
  _RssSource(
    name: 'CNBC Top News',
    feedUrl: 'https://www.cnbc.com/id/100003114/device/rss/rss.html',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Investing.com',
    feedUrl: 'https://www.investing.com/rss/news.rss',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Forbes Business',
    feedUrl: 'https://www.forbes.com/business/feed/',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Fortune',
    feedUrl: 'https://fortune.com/feed',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Yahoo Finance',
    feedUrl: 'https://finance.yahoo.com/news/rssindex',
    topic: 'Business',
  ),
  _RssSource(
    name: 'Scientific American',
    feedUrl: 'http://rss.sciam.com/ScientificAmerican-Global',
    topic: 'Science',
  ),
  _RssSource(
    name: 'ScienceDaily',
    feedUrl: 'https://www.sciencedaily.com/rss/all.xml',
    topic: 'Science',
  ),
  _RssSource(
    name: 'Nature',
    feedUrl: 'https://www.nature.com/nature.rss',
    topic: 'Science',
  ),
  _RssSource(
    name: 'Phys.org',
    feedUrl: 'https://phys.org/rss-feed/',
    topic: 'Science',
  ),
  _RssSource(
    name: 'Wired Science',
    feedUrl: 'https://www.wired.com/feed/category/science/latest/rss',
    topic: 'Science',
  ),
  _RssSource(
    name: 'NASA Breaking News',
    feedUrl: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
    topic: 'Science',
  ),
  _RssSource(
    name: 'Space.com',
    feedUrl: 'https://www.space.com/feeds/all',
    topic: 'Science',
  ),
  _RssSource(
    name: 'Ars Technica',
    feedUrl: 'http://feeds.arstechnica.com/arstechnica/index',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'CNET News',
    feedUrl: 'https://www.cnet.com/rss/news/',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'Gizmodo',
    feedUrl: 'https://gizmodo.com/rss',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'The Verge',
    feedUrl: 'https://www.theverge.com/rss/index.xml',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'TechCrunch',
    feedUrl: 'http://feeds.feedburner.com/TechCrunch',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'Engadget',
    feedUrl: 'https://www.engadget.com/rss.xml',
    topic: 'Technology',
  ),
  _RssSource(
    name: 'BBC Sport',
    feedUrl: 'http://feeds.bbci.co.uk/sport/rss.xml',
    topic: 'Sports',
  ),
  _RssSource(
    name: 'Sky Sports',
    feedUrl: 'http://feeds.skynews.com/feeds/rss/sports.xml',
    topic: 'Sports',
  ),
  _RssSource(
    name: 'Yahoo Sports',
    feedUrl: 'https://sports.yahoo.com/rss/',
    topic: 'Sports',
  ),
  _RssSource(
    name: 'ESPN',
    feedUrl: 'https://www.espn.com/espn/rss/news',
    topic: 'Sports',
  ),
  _RssSource(
    name: 'CBC Top Stories',
    feedUrl: 'https://www.cbc.ca/cmlink/rss-topstories',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'CTV Top Stories',
    feedUrl:
        'https://www.ctvnews.ca/rss/ctvnews-ca-top-stories-public-rss-1.822009',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Toronto Star',
    feedUrl:
        'https://www.thestar.com/content/thestar/feed.RSSManagerServlet.articles.topstories.rss',
    topic: 'Top Stories',
  ),
  _RssSource(
    name: 'Deutsche Welle',
    feedUrl: 'https://rss.dw.com/rdf/rss-en-all',
    topic: 'World',
  ),
  _RssSource(
    name: 'France24',
    feedUrl: 'https://www.france24.com/en/rss',
    topic: 'World',
  ),
  _RssSource(
    name: 'Le Monde',
    feedUrl: 'https://www.lemonde.fr/rss/une.xml',
    topic: 'World',
  ),
  _RssSource(
    name: 'Japan Times',
    feedUrl: 'https://www.japantimes.co.jp/feed/topstories/',
    topic: 'World',
  ),
  _RssSource(
    name: 'Kyodo News',
    feedUrl: 'https://english.kyodonews.net/rss/all.xml',
    topic: 'World',
  ),
  _RssSource(
    name: 'Mexico News Daily',
    feedUrl: 'https://mexiconewsdaily.com/feed/',
    topic: 'World',
  ),
  _RssSource(
    name: 'Premium Times Nigeria',
    feedUrl: 'https://www.premiumtimesng.com/feed',
    topic: 'World',
  ),
  _RssSource(
    name: 'Inquirer Philippines',
    feedUrl: 'https://www.inquirer.net/fullfeed',
    topic: 'World',
  ),
  _RssSource(
    name: 'Express Tribune',
    feedUrl: 'https://tribune.com.pk/feed/home',
    topic: 'World',
  ),
  _RssSource(
    name: 'Ukrainska Pravda',
    feedUrl: 'https://www.pravda.com.ua/rss/',
    topic: 'World',
  ),
  _RssSource(
    name: 'Moscow Times',
    feedUrl: 'https://www.themoscowtimes.com/rss/news',
    topic: 'World',
  ),
  _RssSource(
    name: 'News24 South Africa',
    feedUrl: 'http://feeds.news24.com/articles/news24/TopStories/rss',
    topic: 'World',
  ),
  _RssSource(
    name: 'Axios',
    feedUrl: 'https://api.axios.com/feed/',
    topic: 'Politics',
  ),
];

class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.animate = true,
    this.onComplete,
  });

  final String text;
  final TextStyle style;
  final bool animate;
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  late int _visibleLength;

  int get _totalCharacters => widget.text.characters.length;

  @override
  void initState() {
    super.initState();
    _visibleLength = widget.animate ? 0 : _totalCharacters;
    if (widget.animate) {
      _restart();
    } else {
      // If not animating, it's already "complete"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (widget.animate) {
        _restart();
      } else {
        _timer?.cancel();
        setState(() {
          _visibleLength = _totalCharacters;
        });
        widget.onComplete?.call();
      }
    }
  }

  void _restart() {
    _timer?.cancel();
    _visibleLength = 0;

    if (widget.text.isEmpty) {
      widget.onComplete?.call();
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 14), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _visibleLength = (_visibleLength + 2).clamp(0, _totalCharacters);
      });

      if (_visibleLength >= _totalCharacters) {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleText = widget.text.characters.take(_visibleLength).toString();
    final showCursor = _visibleLength < _totalCharacters;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: visibleText),
          if (showCursor)
            const TextSpan(
              text: '|',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
        ],
      ),
      style: widget.style,
    );
  }
}

class NewsArticle {
  const NewsArticle({
    required this.section,
    required this.headline,
    required this.summary,
    required this.articleBody,
    required this.source,
    required this.url,
    required this.readTime,
    required this.accent,
    required this.leaningScore,
    required this.leaningLabel,
    required this.leaningReason,
  });

  final String section;
  final String headline;
  final String summary;
  final String articleBody;
  final String source;
  final String url;
  final String readTime;
  final Color accent;
  final double leaningScore;
  final String leaningLabel;
  final String leaningReason;

  NewsArticle copyWith({
    String? section,
    String? headline,
    String? summary,
    String? articleBody,
    String? source,
    String? url,
    String? readTime,
    Color? accent,
    double? leaningScore,
    String? leaningLabel,
    String? leaningReason,
  }) {
    return NewsArticle(
      section: section ?? this.section,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      articleBody: articleBody ?? this.articleBody,
      source: source ?? this.source,
      url: url ?? this.url,
      readTime: readTime ?? this.readTime,
      accent: accent ?? this.accent,
      leaningScore: leaningScore ?? this.leaningScore,
      leaningLabel: leaningLabel ?? this.leaningLabel,
      leaningReason: leaningReason ?? this.leaningReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'section': section,
      'headline': headline,
      'summary': summary,
      'articleBody': articleBody,
      'source': source,
      'url': url,
      'readTime': readTime,
      'accent': accent.toARGB32(),
      'leaningScore': leaningScore,
      'leaningLabel': leaningLabel,
      'leaningReason': leaningReason,
    };
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      section: '${json['section'] ?? ''}',
      headline: '${json['headline'] ?? ''}',
      summary: '${json['summary'] ?? ''}',
      articleBody: '${json['articleBody'] ?? ''}',
      source: '${json['source'] ?? ''}',
      url: '${json['url'] ?? ''}',
      readTime: '${json['readTime'] ?? ''}',
      accent: Color((json['accent'] as num?)?.toInt() ?? 0xFFEE6C4D),
      leaningScore: (json['leaningScore'] as num?)?.toDouble() ?? 0,
      leaningLabel: '${json['leaningLabel'] ?? 'Center'}',
      leaningReason: '${json['leaningReason'] ?? ''}',
    );
  }
}

class AppSecrets {
  const AppSecrets._();

  // News API tokens (Optional: The app will fallback to RSS + Web Search if empty)
  static const theNewsApiToken = '';
  static const newsDataApiKey = '';
}
