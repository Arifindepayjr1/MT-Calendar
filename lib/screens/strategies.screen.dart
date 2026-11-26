import 'package:flutter/material.dart';
import 'package:trader_log/model/strategy.model.dart';
import 'package:trader_log/model/strategy_draft.model.dart';
import 'package:trader_log/model/strategy_playbook.model.dart';
import 'package:trader_log/screens/create_strategy.screen.dart';
import 'package:trader_log/screens/strategy_detail.screen.dart';
import 'package:trader_log/services/strategy_api_service.dart';
import 'package:trader_log/widgets/home_app_bar.dart';

const _bg = Color(0xFF111411);
const _surface = Color(0xFF1A1F1B);
const _mint = Color(0xFFB7F7C4);
const _coral = Color(0xFFFF7C7C);
const _muted = Color(0xFF858D86);
const _border = Color(0xFF303832);
const _ink = Color(0xFFE8ECE8);
const String _dollar = r'$';

/// One card in the All Setups list. Saved user drafts are first-class setups,
/// alongside the shared backend playbooks.
class _SetupEntry {
  final StrategyPlaybook? playbook;
  final StrategyDraft? draft;

  const _SetupEntry._(this.playbook, this.draft);

  factory _SetupEntry.playbook(StrategyPlaybook playbook) =>
      _SetupEntry._(playbook, null);

  factory _SetupEntry.draft(StrategyDraft draft) => _SetupEntry._(null, draft);

  String get name => playbook?.name ?? draft!.name;

  StrategyCategory get category =>
      playbook?.category ?? draft?.category ?? StrategyCategory.other;

  bool matches(PlaybookFilter filter) => switch (filter) {
        PlaybookFilter.all => true,
        PlaybookFilter.ictSmc => category == StrategyCategory.ictSmc,
        PlaybookFilter.priceAction => category == StrategyCategory.priceAction,
      };
}

/// Mobile playbook overview for the persistent Strategies tab.
class StrategiesScreen extends StatefulWidget {
  final String accountName;
  final StrategyApiService api;

  const StrategiesScreen({
    super.key,
    required this.accountName,
    this.api = const StrategyApiService(),
  });

  @override
  State<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends State<StrategiesScreen> {
  StrategyOverview? _overview;
  List<StrategyDraft> _drafts = const <StrategyDraft>[];
  bool _loading = true;
  String? _error;
  String? _draftError;
  final Set<String> _favorites = <String>{};

  Iterable<StrategyPlaybook> get _playbooks =>
      _overview?.playbooks ?? const <StrategyPlaybook>[];

  /// User setups come first so a freshly saved strategy is immediately visible
  /// at the top of All Setups. The backend already returns drafts newest-first.
  Iterable<_SetupEntry> get _allSetups => [
        for (final draft in _drafts) _SetupEntry.draft(draft),
        for (final playbook in _playbooks) _SetupEntry.playbook(playbook),
      ];

  Iterable<_SetupEntry> get _visible =>
      _allSetups.where((entry) => entry.matches(_filter));

  PlaybookFilter _filter = PlaybookFilter.all;
  bool _showEmptyPreview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StrategiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Signing in or out replaces the token provider. Reload drafts so a user
    // sees their own saved strategies immediately without restarting the app.
    if (oldWidget.api.hasToken != widget.api.hasToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _draftError = null;
    });

    StrategyOverview? overview;
    try {
      overview = await widget.api.fetchOverview();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
      return;
    }

    List<StrategyDraft> drafts = const <StrategyDraft>[];
    String? draftError;
    if (widget.api.hasToken) {
      try {
        drafts = await widget.api.fetchDrafts();
      } catch (error) {
        drafts = const <StrategyDraft>[];
        draftError = 'Could not load your saved strategies: $error';
      }
    }

    if (!mounted) return;
    setState(() {
      _overview = overview;
      _drafts = drafts;
      _draftError = draftError;
      _favorites
        ..clear()
        ..addAll(
          overview!.playbooks
              .where((playbook) => playbook.favorite)
              .map((playbook) => playbook.id),
        );
      _loading = false;
    });
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateStrategyScreen(api: widget.api),
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
    if (!mounted) return;
    _notify('Strategy saved to your account.');
  }

  void _openDetails(StrategyPlaybook playbook) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StrategyDetailScreen(
          strategyId: playbook.id,
          playbookName: playbook.name,
          api: widget.api,
        ),
      ),
    );
  }

  void _openSavedSetup(StrategyDraft draft) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StrategyDetailScreen.fromDraft(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: HomeAppBar(accountName: widget.accountName, backgroundColor: _bg),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _mint),
      );
    }
    if (_error != null || _overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: _muted, size: 34),
              const SizedBox(height: 10),
              const Text(
                'Could not load strategies.',
                style: TextStyle(color: _ink, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? 'No strategy data was returned.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _mint,
                  foregroundColor: _bg,
                ),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _heading(),
        const SizedBox(height: 16),
        _summary(),
        const SizedBox(height: 16),
        _draftErrorBanner(),
        _filters(),
        const SizedBox(height: 12),
        ..._visible.map(_setupCard),
        const SizedBox(height: 4),
        _tipCard(),
        const SizedBox(height: 12),
        _emptyStateAccordion(),
      ],
    );
  }

  Widget _draftErrorBanner() {
    final error = _draftError;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _coral.withValues(alpha: 0.4)),
        ),
        child: Text(
          error,
          style: const TextStyle(color: _coral, fontSize: 10, height: 1.35),
        ),
      ),
    );
  }

  String _categoryLabel(StrategyCategory? category) => switch (category) {
        StrategyCategory.ictSmc => 'ICT / SMC',
        StrategyCategory.priceAction => 'Price Action',
        StrategyCategory.trendFollowing => 'Trend Following',
        StrategyCategory.scalping => 'Scalping',
        StrategyCategory.breakout => 'Breakout',
        StrategyCategory.other => 'Other',
        null => 'Other',
      };

  String _formatSavedAt(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _heading() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Strategies',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Manage your trading setups and rules',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _mint,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openCreate,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                child: Text(
                  '+ Create',
                  style: TextStyle(
                    color: _bg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _summary() {
    final overview = _overview!;
    return Row(
      children: [
        Expanded(
          child: _metric(
            'Setups',
            '${_allSetups.length}',
            'Active Sets',
            _ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'Executions',
            '${overview.executions}',
            'Logged',
            _ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'Net Return',
            _formatMoney(overview.netReturn),
            '${overview.winRate.toStringAsFixed(1)}% Win',
            _mint,
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, String caption, Color valueColor) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 8.5),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                caption,
                style: const TextStyle(color: _muted, fontSize: 8),
              ),
            ),
          ],
        ),
      );

  Widget _filters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in PlaybookFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChip(filter),
              ),
          ],
        ),
      );

  Widget _filterChip(PlaybookFilter filter) {
    final active = filter == _filter;
    final count = _allSetups.where((entry) => entry.matches(filter)).length;
    final label = switch (filter) {
      PlaybookFilter.all => '● ${filter.label} ($count)',
      PlaybookFilter.ictSmc => '${filter.label} ($count)',
      PlaybookFilter.priceAction => '${filter.label} ($count)',
    };
    return Material(
      color: active ? _mint : _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _mint : _border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? _bg : _muted,
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _setupCard(_SetupEntry entry) => entry.playbook != null
      ? _playbookCard(entry.playbook!)
      : _savedSetupCard(entry.draft!);

  Widget _savedSetupCard(StrategyDraft draft) {
    final narrative = draft.narrative?.trim() ?? '';
    final description = draft.description?.trim() ?? '';
    final summary = narrative.isNotEmpty
        ? narrative
        : description.isNotEmpty
            ? description
            : 'Your private rulebook saved to this account.';
    final activeEntries =
        draft.entryConditions.where((condition) => condition.enabled).length;
    final activeRules =
        draft.disciplineRules.where((rule) => rule.enabled).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openSavedSetup(draft),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        draft.name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: _muted, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _mint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _mint.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'YOUR SETUP',
                        style: TextStyle(
                          color: _mint,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _tag(_categoryLabel(draft.category)),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('Entry rules',
                        '$activeEntries/${draft.entryConditions.length}'),
                    _stat('Discipline',
                        '$activeRules/${draft.disciplineRules.length}'),
                    _stat('Saved', _formatSavedAt(draft.savedAt)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playbookCard(StrategyPlaybook playbook) {
    final favorite = _favorites.contains(playbook.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetails(playbook),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        playbook.name,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (favorite)
                      IconButton(
                        tooltip: 'Remove favorite',
                        icon: const Icon(Icons.star_rounded,
                            color: _mint, size: 18),
                        onPressed: () =>
                            setState(() => _favorites.remove(playbook.id)),
                      ),
                    IconButton(
                      tooltip: 'Edit ${playbook.name}',
                      icon: const Icon(Icons.edit_outlined,
                          color: _muted, size: 17),
                      onPressed: () => _notify('Edit ${playbook.name}'),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More options',
                      color: _surface,
                      iconColor: _muted,
                      onSelected: (action) =>
                          _notify('$action ${playbook.name}'),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'Duplicate', child: Text('Duplicate')),
                        PopupMenuItem(value: 'Archive', child: Text('Archive')),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Open ${playbook.name}',
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: _muted, size: 20),
                      onPressed: () => _openDetails(playbook),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in playbook.tags)
                      _tag(tag,
                          review: playbook.reviewNeeded && tag.contains('Review')),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  playbook.description,
                  style:
                      const TextStyle(color: _muted, fontSize: 11, height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('Volume', '${playbook.executions} Tr'),
                    _stat('Win Rate', '${playbook.winRate.toStringAsFixed(1)}%'),
                    _stat('Avg R', '${_signed(playbook.avgR, 1)}R'),
                    _stat(
                      'Net P&L',
                      _formatMoney(playbook.netPnl),
                      color: playbook.netPnl < 0 ? _coral : _mint,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [for (final badge in playbook.badges) _badge(badge)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, {bool review = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: review
              ? _coral.withValues(alpha: 0.12)
              : const Color(0xFF121813),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: review ? _coral.withValues(alpha: 0.4) : _border,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: review ? _coral : _muted,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _stat(String label, String value, {Color color = _ink}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 8)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _badge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF121813),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border),
        ),
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
      );

  Widget _tipCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tips_and_updates_outlined,
                color: _mint, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'DISCIPLINE RULE: ',
                      style: TextStyle(
                        color: _mint,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Assign strategies directly inside your MT5 Trade Details to track your discipline edge across sessions.',
                      style:
                          TextStyle(color: _muted, fontSize: 10, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _emptyStateAccordion() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  setState(() => _showEmptyPreview = !_showEmptyPreview),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  _showEmptyPreview
                      ? '👁 Hide Empty State Preview (Zero Playbooks) ⌃'
                      : '👁 View Empty State Preview (Zero Playbooks) ⌵',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: !_showEmptyPreview
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121613),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.layers_outlined, color: _muted, size: 30),
                        SizedBox(height: 8),
                        Text(
                          'No playbooks yet',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Create a strategy to start tracking your setups and rules.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
}

String _signed(double value, int digits) =>
    '${value < 0 ? '-' : '+'}${value.abs().toStringAsFixed(digits)}';

String _formatMoney(double value) {
  final sign = value < 0 ? '-' : '+';
  final absolute = value.abs();
  final digits = absolute == absolute.roundToDouble() ? 0 : 2;
  final parts = absolute.toStringAsFixed(digits).split('.');
  final whole = parts.first;
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '$sign$_dollar$grouped$decimals';
}
