import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'core/services/theme_service.dart';
import 'features/profile/profile_page.dart';
import 'features/schedules/schedule_form_page.dart';
import 'features/schedules/schedule_list_page.dart';
import 'finance_page.dart';

/// Shell de navegação pós-login.
/// Hospeda 4 abas: Escalas (calendário) | Novo | Ganhos | Perfil.
/// "Novo" abre o formulário via push e não muda o índice da aba.
class HomePage extends StatefulWidget {
  final ThemeService themeService;
  const HomePage({super.key, required this.themeService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _showListMode = false;

  final _calendarKey = GlobalKey<CalendarPageState>();
  final _financeKey = GlobalKey<FinancePageState>();
  final _listKey = GlobalKey<ScheduleListPageState>();

  late final List<Widget> _pages = [
    CalendarPage(
      key: _calendarKey,
      onToggleView: () => setState(() => _showListMode = true),
    ),
    const SizedBox.shrink(), // placeholder para a aba "Novo"
    FinancePage(key: _financeKey),
    ProfilePage(themeService: widget.themeService),
    ScheduleListPage(
      key: _listKey,
      onToggleView: () => setState(() => _showListMode = false),
    ),
  ];

  int get _effectiveIndex => _index == 0 && _showListMode ? 4 : _index;

  Future<void> _abrirNovo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleFormPage()),
    );
    _calendarKey.currentState?.refresh();
    _financeKey.currentState?.refresh();
    _listKey.currentState?.refresh();
  }

  void _onTabTapped(int i) {
    if (i == 1) {
      _abrirNovo();
      return;
    }
    if (i == 2 && _index != 2) {
      _financeKey.currentState?.refresh();
    }
    if (i != 0) setState(() => _showListMode = false);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _effectiveIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Escalas',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Novo',
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_money_outlined),
            selectedIcon: Icon(Icons.attach_money),
            label: 'Ganhos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
