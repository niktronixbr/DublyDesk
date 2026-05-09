import 'package:flutter/material.dart';

import 'core/services/theme_service.dart';
import 'features/profile/profile_page.dart';
import 'features/schedules/schedule_form_page.dart';
import 'features/schedules/schedule_list_page.dart';
import 'finance_page.dart';

/// Shell de navegação pós-login.
/// Hospeda 4 abas: Escalas | Novo | Ganhos | Perfil.
/// "Novo" abre o formulário via push e não muda o índice da aba.
class HomePage extends StatefulWidget {
  final ThemeService themeService;
  const HomePage({super.key, required this.themeService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  // Key permite acionar reload das escalas após criar via "Novo".
  final _scheduleListKey = GlobalKey<ScheduleListPageState>();

  late final List<Widget> _pages = [
    ScheduleListPage(
      key: _scheduleListKey,
      themeService: widget.themeService,
    ),
    const SizedBox.shrink(), // placeholder para a aba "Novo"
    const FinancePage(),
    ProfilePage(themeService: widget.themeService),
  ];

  Future<void> _abrirNovo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleFormPage()),
    );
    // Recarrega a lista após retornar.
    _scheduleListKey.currentState?.refresh();
  }

  void _onTabTapped(int i) {
    if (i == 1) {
      _abrirNovo();
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note),
            label: 'Escalas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Novo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Ganhos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
