import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'core/models/schedule_model.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_colors.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class CalendarPage extends StatefulWidget {
  /// Escalas já carregadas pela tela anterior, evita uma chamada extra à API
  /// quando a página é aberta a partir da lista de escalas.
  final List<ScheduleModel>? escalas;

  const CalendarPage({super.key, this.escalas});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<ScheduleModel>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    if (widget.escalas != null && widget.escalas!.isNotEmpty) {
      _events = _agrupar(widget.escalas!);
    } else {
      _fetch();
    }
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
    final result = await ApiService.get('/schedules');
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

    setState(() => _events = _agrupar(parsed));
  }

  List<ScheduleModel> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEvents = _eventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
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
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              eventLoader: _eventsForDay,
              calendarStyle: CalendarStyle(
                todayDecoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle:
                    TextStyle(color: theme.colorScheme.onSurface),
                defaultTextStyle:
                    TextStyle(color: theme.colorScheme.onSurface),
                outsideTextStyle:
                    TextStyle(color: theme.dividerColor),
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
            child: selectedEvents.isEmpty
                ? const Center(child: Text('Nenhuma escala neste dia.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: selectedEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = selectedEvents[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.projeto,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${s.produtora} · ${s.horaInicio} – ${s.horaFim}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _moeda.format(s.valorTotal),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
