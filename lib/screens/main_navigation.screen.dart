import 'package:flutter/material.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/screens/calendar.screen.dart';
import 'package:trader_log/screens/home.screen.dart';
import 'package:trader_log/screens/settings.screen.dart';
import 'package:trader_log/screens/statistics.screen.dart';
import 'package:trader_log/screens/strategies.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';
import 'package:trader_log/services/strategy_api_service.dart';
import 'package:trader_log/services/trade_import_store.dart';

class MainNavigationScreen extends StatefulWidget {
  final StrategyApiService strategyApi;
  final AuthStore? authStore;
  final TradeImportStore? importStore;

  const MainNavigationScreen({
    super.key,
    this.strategyApi = const StrategyApiService(),
    this.authStore,
    this.importStore,
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
    widget.importStore?.initialize();
  }

  /// Imported MT5 data is read from the device store first so it is identical
  /// before login, after login, and after a restart.
  List<Trade> get _activeTrades =>
      widget.importStore?.data?.trades ?? _trades;
  String get _activeAccountName =>
      widget.importStore?.data?.accountName ?? _accountName;
  String get _activeBrokerAndNumber =>
      widget.importStore?.data?.brokerAndNumber ?? _brokerAndNumber;
  String get _activeCurrency =>
      widget.importStore?.data?.currency ?? _currency;
  double get _activeInitialDeposit =>
      widget.importStore?.data?.initialDeposit ?? _initialDeposit;

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
    final importStore = widget.importStore;
    if (importStore == null) return _buildRoot(context);
    return AnimatedBuilder(
      animation: importStore,
      builder: (context, _) => _buildRoot(context),
    );
  }

  Widget _buildRoot(BuildContext context) {
    final strategyApi = widget.strategyApi.withToken(
      () => _authStore.token,
    );
    final sections = <Widget>[
      HomeScreen(
        onImported: _acceptImport,
        importStore: widget.importStore,
        journals: _journals,
        dayNotes: _dayNotes,
        strategyApi: strategyApi,
      ),
      CalendarScreen(
        trades: _activeTrades,
        accountName: _activeAccountName,
        brokerAndNumber: _activeBrokerAndNumber,
        currency: _activeCurrency,
        initialDeposit: _activeInitialDeposit,
        dayNotes: _dayNotes,
        journals: _journals,
        onDayNoteChanged: (key, note) => setState(() => _dayNotes[key] = note),
        onJournalChanged: (id, journal) =>
            setState(() => _journals[id] = journal),
        onGoHome: () => _selectSection(0),
        strategyApi: strategyApi,
      ),
      StrategiesScreen(
        accountName: _activeAccountName,
        api: strategyApi,
      ),
      StatisticsScreen(
        trades: _activeTrades,
        accountName: _activeAccountName,
        brokerAndNumber: _activeBrokerAndNumber,
        currency: _activeCurrency,
        initialDeposit: _activeInitialDeposit,
        journals: _journals,
        strategyApi: strategyApi,
      ),
      SettingsScreen(
        authStore: _authStore,
        authApi: const AuthApiService(),
        onAuthChanged: () => setState(() {}),
        importStore: widget.importStore,
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


