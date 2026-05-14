import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'auth_service.dart';
import 'core/models/schedule_model.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_colors.dart';
import 'features/schedules/schedule_card.dart';
import 'features/schedules/schedule_form_page.dart';
import 'shared/widgets/user_avatar.dart';

enum _DayStatus { vazio, futuro, pendente, naoRealizado, concluido }

class CalendarPage extends StatefulWidget {
  final List<ScheduleModel>? escalas;
  final VoidCallback? onToggleView;
  const CalendarPage({super.key, this.escalas, this.onToggleView});

  @override
  State<CalendarPage> createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  Map<DateTime, List<ScheduleModel>> _events = {};
  List<ScheduleModel> _allSchedules = [];
  String _userName = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
    if (widget.escalas != null && widget.escalas!.isNotEmpty) {
      _allSchedules = widget.escalas!;
      _events = _agrupar(widget.escalas!);
    } else {
      _fetch();
    }
  }

  Future<void> refresh() => _fetch();

  Future<void> _carregarUsuario() async {
    final nome = await AuthService.getUserName();
    final avatar = await AuthService.getAvatarUrl();
    if (!mounted) return;
    setState(() {
      _userName = nome ?? '';
      _avatarUrl = avatar;
    });
  }

  Map<DateTime, List<ScheduleModel>> _agrupar(List<ScheduleModel> lista) {
    final map = <DateTime, List<ScheduleModel>>{};
    for (final s in lista) {
      final key = DateTime(s.data.year, s.data.month, s.data.day);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  Future<void> _fetch() async {
    final result = await ApiService.get('/schedules?limit=1000');
    if (!mounted) return;
    if (result['success'] != true) return;

    final responseData = result['data'];
    final List rawList =
        (responseData is Map && responseData.containsKey('data'))
            ? responseData['data'] as List
            : responseData as List;
    final parsed = rawList
        .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (mounted) {
      setState(() {
        _allSchedules = parsed;
        _events = _agrupar(parsed);
      });
    }
  }

  List<ScheduleModel> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  _DayStatus _statusForDay(DateTime day) {
    final events = _eventsForDay(day);
    if (events.isEmpty) return _DayStatus.vazio;
    final today = DateTime.now();
    final dayOnly = DateTime(day.year, day.month, day.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isPastOrToday = !dayOnly.isAfter(todayOnly);
    final allDone = events.every((s) => s.realizado);
    final anyDone = events.any((s) => s.realizado);
    if (allDone) return _DayStatus.concluido;
    if (isPastOrToday && !anyDone) return _DayStatus.naoRealizado;
    if (isPastOrToday) return _DayStatus.pendente;
    return _DayStatus.futuro;
  }

  Future<void> _toggleRealizado(ScheduleModel s) async {
    if (!s.realizado && DateTime.now().isBefore(s.data)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'A escala ainda não ocorreu. Só é possível marcar como realizada após o horário agendado.',
        ),
      ));
      return;
    }
    final result = await ApiService.put(
      '/schedules/${s.id}',
      {'realizado': !s.realizado},
    );
    if (result['success'] == true) _fetch();
  }

  Future<void> _deletar(ScheduleModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover escala?'),
        content: Text(
          'Deseja remover "${s.projeto.isNotEmpty ? s.projeto : s.produtora}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remover',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.delete('/schedules/${s.id}');
      _fetch();
    }
  }

  Future<void> _abrirEdicao(ScheduleModel s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleFormPage(
          item: s,
          escalasExistentes: _allSchedules,
        ),
      ),
    );
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEvents = _selectedDay == null
        ? const <ScheduleModel>[]
        : _eventsForDay(_selectedDay!);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            UserAvatar(
              size: 40,
              name: _userName,
              avatarUrl: _avatarUrl,
            ),
            const SizedBox(width: 12),
            Text(
              'DublyDesk',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ver como lista',
            icon: const Icon(Icons.view_list_outlined),
            onPressed: widget.onToggleView,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: TableCalendar<ScheduleModel>(
              focusedDay: _focusedDay,
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              locale: 'pt_BR',
              selectedDayPredicate: (day) =>
                  _selectedDay != null && isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() {
                  _focusedDay = focused;
                  _selectedDay = null;
                });
              },
              eventLoader: _eventsForDay,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (ctx, day, events) {
                  if (events.isEmpty) return null;
                  return _DayMarker(status: _statusForDay(day));
                },
              ),
              calendarStyle: CalendarStyle(
                markersMaxCount: 0, // handled by markerBuilder
                todayDecoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle:
                    TextStyle(color: theme.colorScheme.onSurface),
                defaultTextStyle:
                    TextStyle(color: theme.colorScheme.onSurface),
                outsideTextStyle: TextStyle(color: theme.dividerColor),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: theme.textTheme.titleLarge!,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: theme.colorScheme.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              daysOfWeekHeight: 36.0,
            ),
          ),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('Selecione uma data no calendário.'))
                : selectedEvents.isEmpty
                ? const Center(child: Text('Nenhuma escala neste dia.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: selectedEvents.length,
                    itemBuilder: (_, i) {
                      final s = selectedEvents[i];
                      return ScheduleCard(
                        schedule: s,
                        compact: true,
                        onTap: () => _abrirEdicao(s),
                        onDelete: () => _deletar(s),
                        onToggleRealizado: () => _toggleRealizado(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayMarker extends StatelessWidget {
  final _DayStatus status;
  const _DayMarker({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _DayStatus.concluido:
        return const Icon(Icons.check_circle, size: 14, color: AppColors.secondary);
      case _DayStatus.pendente:
        return _dot(Colors.amber);
      case _DayStatus.naoRealizado:
        return _dot(Colors.red);
      case _DayStatus.futuro:
        return _dot(AppColors.secondary);
      case _DayStatus.vazio:
        return const SizedBox.shrink();
    }
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
