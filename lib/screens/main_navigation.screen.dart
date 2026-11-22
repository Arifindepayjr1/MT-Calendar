import 'package:flutter/material.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/screens/calendar.screen.dart';
import 'package:trader_log/screens/home.screen.dart';
import 'package:trader_log/screens/settings.screen.dart';
import 'package:trader_log/screens/strategies.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';
import 'package:trader_log/services/strategy_api_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final StrategyApiService strategyApi;
  final AuthStore? authStore;

  const MainNavigationScreen({
    super.key,
    this.strategyApi = const StrategyApiService(),
    this.authStore,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final AuthStore _authStore = widget.authStore ?? AuthStore();
  int _selectedIndex = 0;
  List<Trade> _trades = const [];
  String _accountName = 'Alex';
  String _brokerAndNumber = 'IC Markets (MT5 #482910)';
  String _currency = 'USD';
  double _initialDeposit = 5000;
  final Map<String, String> _dayNotes = {};
  final Map<String, Journal> _journals = {};

  @override
  void initState() {
    super.initState();
    _authStore.initialize();
  }

  static const List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationItem(
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    _NavigationItem(
      label: 'Strategies',
      icon: Icons.layers_outlined,
      selectedIcon: Icons.layers_rounded,
    ),
    _NavigationItem(
      label: 'Statistics',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
    ),
    _NavigationItem(
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  void _acceptImport(HomeImportData data) {
    setState(() {
      _trades = data.trades;
      _accountName = data.accountName;
      _brokerAndNumber = data.brokerAndNumber;
      _currency = data.currency;
      _initialDeposit = data.initialDeposit;
    });
  }

  void _selectSection(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final strategyApi = widget.strategyApi.withToken(
      () => _authStore.token,
    );
    final sections = <Widget>[
      HomeScreen(onImported: _acceptImport),
      CalendarScreen(
        trades: _trades,
        accountName: _accountName,
        brokerAndNumber: _brokerAndNumber,
        currency: _currency,
        initialDeposit: _initialDeposit,
        dayNotes: _dayNotes,
        journals: _journals,
        onDayNoteChanged: (key, note) => setState(() => _dayNotes[key] = note),
        onJournalChanged: (id, journal) =>
            setState(() => _journals[id] = journal),
        onGoHome: () => _selectSection(0),
      ),
      StrategiesScreen(
        accountName: _accountName,
        api: strategyApi,
      ),
      const _PrimarySectionScreen(
        title: 'Statistics',
        description:
            'Explore your win rate, trade breakdowns, and P&L over time.',
        icon: Icons.bar_chart_rounded,
      ),
      SettingsScreen(
        authStore: _authStore,
        authApi: const AuthApiService(),
        onAuthChanged: () => setState(() {}),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF101310),
      body: IndexedStack(index: _selectedIndex, children: sections),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101310),
        border: Border(top: BorderSide(color: Color(0xFF303832))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(_navigationItems.length, (index) {
              final item = _navigationItems[index];
              final isSelected = index == _selectedIndex;
              return Expanded(
                child: _NavigationDestinationButton(
                  item: item,
                  isSelected: isSelected,
                  onPressed: () => _selectSection(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _NavigationDestinationButton extends StatelessWidget {
  final _NavigationItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _NavigationDestinationButton({
    required this.item,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? const Color(0xFFB7F7C4)
        : const Color(0xFF858D86);
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          splashColor: const Color(0xFFB7F7C4).withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: 52,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFB7F7C4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    size: 23,
                    color: isSelected
                        ? const Color(0xFF101310)
                        : const Color(0xFF858D86),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimarySectionScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _PrimarySectionScreen({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101310),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101310),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE8ECE8),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F1B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF303832)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 32, color: const Color(0xFFB7F7C4)),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE8ECE8),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF858D86),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F1B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF303832)),
                  ),
                  child: const Text(
                    'No data to display yet',
                    style: TextStyle(
                      color: Color(0xFF858D86),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
}
