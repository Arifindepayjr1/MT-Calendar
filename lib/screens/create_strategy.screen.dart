import 'package:flutter/material.dart';
import 'package:trader_log/model/strategy.model.dart';
import 'package:trader_log/services/strategy_api_service.dart';

const _bg = Color(0xFF111411);
const _surface = Color(0xFF1A1F1B);
const _mint = Color(0xFFB7F7C4);
const _coral = Color(0xFFFF7C7C);
const _muted = Color(0xFF858D86);
const _border = Color(0xFF303832);
const _ink = Color(0xFFE8ECE8);

const _sessions = <String>[
  'Asian',
  'London',
  'New York',
  'London & NY Overlap',
];

const _intervals = <String>['15M', '5M', '1M'];

class _EntryCondition {
  final TextEditingController controller;
  bool enabled;

  _EntryCondition(String text, this.enabled)
      : controller = TextEditingController(text: text);

  void dispose() => controller.dispose();
}

class _CheckItem {
  final String text;
  bool enabled;

  _CheckItem(this.text, this.enabled);
}

/// Form for drafting a new playbook rulebook.
class CreateStrategyScreen extends StatefulWidget {
  final StrategyApiService api;

  /// Pops with `true` after a successful save. The Strategies tab waits for
  /// that result, reloads drafts and returns the user to the refreshed list.
  const CreateStrategyScreen({
    super.key,
    this.api = const StrategyApiService(),
  });

  @override
  State<CreateStrategyScreen> createState() => _CreateStrategyScreenState();
}

class _CreateStrategyScreenState extends State<CreateStrategyScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _narrativeController = TextEditingController();
  final _tpController = TextEditingController(
      text: 'TP1 at 2R, TP2 at session range extension');
  final _slController =
      TextEditingController(text: 'Stop beyond sweep extreme + 5 pip buffer');
  final _invalidationController = TextEditingController(
      text: 'Invalidate if liquidity pool is reclaimed before displacement');
  final _customRuleController = TextEditingController();

  int _narrativeCount = 0;
  String _draftStatus = 'Draft auto-saved';
  bool _addingCustomRule = false;
  bool _saving = false;

  final Set<StrategyCategory> _categories = {StrategyCategory.ictSmc};
  final Set<String> _sessionsSelected = {'London', 'New York'};
  final Set<String> _intervalsSelected = {'15M', '5M', '1M'};

  final List<_EntryCondition> _entryConditions = [
    _EntryCondition('Mark the macro window on 15M', true),
    _EntryCondition('Confirm liquidity grab / sweep', true),
    _EntryCondition('Wait for displacement + FVG', true),
  ];

  final List<_CheckItem> _disciplineRules = [
    _CheckItem('No entry before macro window opens', true),
    _CheckItem('Risk must be <= 1% per setup', true),
    _CheckItem('Stop loss placed before order submission', true),
    _CheckItem('No revenge trades after two losses', false),
  ];

  @override
  void dispose() {
    for (final condition in _entryConditions) {
      condition.dispose();
    }
    _nameController.dispose();
    _descriptionController.dispose();
    _narrativeController.dispose();
    _tpController.dispose();
    _slController.dispose();
    _invalidationController.dispose();
    _customRuleController.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _draftStatus = 'Draft auto-saved');

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addEntryCondition() {
    setState(() {
      _entryConditions.add(_EntryCondition('New entry trigger', true));
    });
    _markDirty();
  }

  void _submitCustomRule() {
    final text = _customRuleController.text.trim();
    if (text.isEmpty) {
      _snack('Enter a rule before adding it.');
      return;
    }
    setState(() {
      _disciplineRules.add(_CheckItem(text, true));
      _customRuleController.clear();
      _addingCustomRule = false;
    });
    _markDirty();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('Enter a strategy name before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _draftStatus = 'Saving draft…';
    });

    final payload = <String, Object?>{
      'name': name,
      'description': _descriptionController.text.trim(),
      'category': _categories.isEmpty ? 'other' : _categories.first.name,
      'categories': _categories.map((category) => category.name).toList(),
      'narrative': _narrativeController.text.trim(),
      'entryConditions': _entryConditions
          .map(
            (condition) => {
              'text': condition.controller.text.trim(),
              'enabled': condition.enabled,
            },
          )
          .toList(),
      'takeProfitRule': _tpController.text.trim(),
      'stopLossRule': _slController.text.trim(),
      'invalidationRule': _invalidationController.text.trim(),
      'disciplineRules': _disciplineRules
          .map(
            (rule) => {'text': rule.text, 'enabled': rule.enabled},
          )
          .toList(),
      'sessions': _sessionsSelected.toList(),
      'intervals': _intervalsSelected.toList(),
    };

    try {
      await widget.api.createDraft(payload);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _draftStatus = 'Saved to backend';
      });
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _draftStatus = 'Save failed';
      });
      _snack(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _ink, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Strategy',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Draft playbook rulebook',
              style: TextStyle(color: _muted, fontSize: 10.5),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                const Icon(Icons.cloud_done_outlined,
                    color: _mint, size: 14),
                const SizedBox(width: 4),
                Text(
                  _draftStatus,
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              'Basic Setup',
              children: [
                _field(
                  label: 'Strategy name',
                  controller: _nameController,
                  hint: 'e.g. ICT Silver Bullet',
                  fieldKey: const Key('strategy-name-field'),
                ),
                const SizedBox(height: 10),
                _field(
                  label: 'Short description / catchphrase',
                  controller: _descriptionController,
                  hint: 'Time-based liquidity grab and displacement',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Category',
                  style: TextStyle(color: _muted, fontSize: 9.5),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    for (final category in StrategyCategory.values)
                      _categoryChip(category),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Playbook Narrative',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Rationale',
                        style: TextStyle(color: _muted, fontSize: 9.5),
                      ),
                    ),
                    Text(
                      'Markdown supported · $_narrativeCount/800',
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('strategy-narrative-field'),
                  controller: _narrativeController,
                  maxLines: 7,
                  maxLength: 800,
                  onChanged: (value) => setState(() {
                    _narrativeCount = value.length;
                    _draftStatus = 'Draft auto-saved';
                  }),
                  decoration: _inputDecoration(
                    hint: 'Explain the market logic, session context and edge...',
                  ).copyWith(counterText: ''),
                  style: const TextStyle(color: _ink, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Entry Conditions',
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entryConditions.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _entryConditions.removeAt(oldIndex);
                      _entryConditions.insert(newIndex, item);
                    });
                    _markDirty();
                  },
                  itemBuilder: (context, index) =>
                      _entryTile(_entryConditions[index]),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _addEntryCondition,
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('+ Add Entry Condition'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mint,
                    side: const BorderSide(color: _mint),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Risk & Exit Framework',
              children: [
                _field(
                  label: 'Take-profit rule',
                  controller: _tpController,
                  hint: '2R / prior session high',
                ),
                const SizedBox(height: 10),
                _field(
                  label: 'Stop-loss rule',
                  controller: _slController,
                  hint: 'Sweep low - 5 pip buffer',
                ),
                const SizedBox(height: 10),
                _field(
                  label: 'Invalidation rule',
                  controller: _invalidationController,
                  hint: 'Reclaim of liquidity pool before displacement',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Pre-Flight Discipline',
              children: [
                ..._disciplineRules.map(_disciplineTile),
                const SizedBox(height: 6),
                if (_addingCustomRule)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('custom-rule-field'),
                            controller: _customRuleController,
                            decoration: _inputDecoration(
                                hint: 'Custom safeguard rule'),
                            style: const TextStyle(color: _ink, fontSize: 10),
                            onSubmitted: (_) => _submitCustomRule(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Add rule',
                          icon: const Icon(Icons.check_rounded,
                              color: _mint, size: 18),
                          onPressed: _submitCustomRule,
                        ),
                        IconButton(
                          tooltip: 'Cancel',
                          icon: const Icon(Icons.close_rounded,
                              color: _muted, size: 18),
                          onPressed: () => setState(() {
                            _addingCustomRule = false;
                            _customRuleController.clear();
                          }),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _addingCustomRule = !_addingCustomRule),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('+ Add Custom Discipline Rule'),
                  style: TextButton.styleFrom(
                    foregroundColor: _mint,
                    textStyle: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              'Active Sessions & Timeframes',
              children: [
                const Text(
                  'Trading sessions',
                  style: TextStyle(color: _muted, fontSize: 9.5),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    for (final session in _sessions)
                      _stringChip(
                        label: session,
                        selected: _sessionsSelected.contains(session),
                        onToggle: (selected) => setState(() {
                          selected
                              ? _sessionsSelected.add(session)
                              : _sessionsSelected.remove(session);
                          _draftStatus = 'Draft auto-saved';
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chart intervals',
                  style: TextStyle(color: _muted, fontSize: 9.5),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    for (final interval in _intervals)
                      _stringChip(
                        label: interval,
                        selected: _intervalsSelected.contains(interval),
                        onToggle: (selected) => setState(() {
                          selected
                              ? _intervalsSelected.add(interval)
                              : _intervalsSelected.remove(interval);
                          _draftStatus = 'Draft auto-saved';
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _muted,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: _bg,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _bg,
                            ),
                          )
                        : const Text(
                            'Save Strategy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, {required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  InputDecoration _inputDecoration({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted, fontSize: 10.5),
        filled: true,
        fillColor: const Color(0xFF121813),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _mint),
        ),
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    Key? fieldKey,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 9.5)),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            decoration: _inputDecoration(hint: hint),
            style: const TextStyle(color: _ink, fontSize: 11),
            onChanged: (_) => _markDirty(),
          ),
        ],
      );

  Widget _categoryChip(StrategyCategory category) {
    final selected = _categories.contains(category);
    return FilterChip(
      label: Text(_categoryLabel(category)),
      selected: selected,
      showCheckmark: false,
      backgroundColor: _surface,
      selectedColor: _mint.withValues(alpha: 0.16),
      side: BorderSide(color: selected ? _mint : _border),
      labelStyle: TextStyle(
        color: selected ? _mint : _muted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (value) => setState(() {
        value ? _categories.add(category) : _categories.remove(category);
        _draftStatus = 'Draft auto-saved';
      }),
    );
  }

  Widget _stringChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onToggle,
  }) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: _surface,
        selectedColor: _mint.withValues(alpha: 0.16),
        side: BorderSide(color: selected ? _mint : _border),
        labelStyle: TextStyle(
          color: selected ? _mint : _muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        onSelected: onToggle,
      );

  Widget _entryTile(_EntryCondition condition) => Container(
        key: ValueKey(condition),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF121813),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Checkbox(
                value: condition.enabled,
                activeColor: _mint,
                checkColor: _bg,
                onChanged: (value) {
                  setState(() => condition.enabled = value ?? false);
                  _markDirty();
                },
              ),
            ),
            Expanded(
              child: TextField(
                controller: condition.controller,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Entry trigger',
                  hintStyle: TextStyle(color: _muted, fontSize: 10),
                ),
                style: TextStyle(
                  color: condition.enabled ? _ink : _muted,
                  fontSize: 10.5,
                ),
                onChanged: (_) => _markDirty(),
              ),
            ),
            IconButton(
              tooltip: 'Delete condition',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: _coral, size: 17),
              onPressed: () {
                setState(() => _entryConditions.remove(condition));
                _markDirty();
              },
            ),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.drag_handle_rounded,
                  color: _muted, size: 18),
            ),
          ],
        ),
      );

  Widget _disciplineTile(_CheckItem rule) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              child: Checkbox(
                value: rule.enabled,
                activeColor: _mint,
                checkColor: _bg,
                onChanged: (value) {
                  setState(() => rule.enabled = value ?? false);
                  _markDirty();
                },
              ),
            ),
            Expanded(
              child: Text(
                rule.text,
                style: TextStyle(
                  color: rule.enabled ? _ink : _muted,
                  fontSize: 10.5,
                  decoration:
                      rule.enabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      );

  String _categoryLabel(StrategyCategory category) => switch (category) {
        StrategyCategory.ictSmc => 'ICT / SMC',
        StrategyCategory.priceAction => 'Price Action',
        StrategyCategory.trendFollowing => 'Trend Following',
        StrategyCategory.scalping => 'Scalping',
        StrategyCategory.breakout => 'Breakout',
        StrategyCategory.other => 'Other',
      };
}
