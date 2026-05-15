import 'package:flutter/material.dart';

import '../../core/models/schedule_model.dart';
import '../../core/theme/app_colors.dart';

enum DayStatus {
  vazio,
  futuro,
  pendente,
  naoRealizado,
  concluido,
  somenteCompromisso,
  mistoComCompromisso,
}

Map<DateTime, List<ScheduleModel>> groupByDay(List<ScheduleModel> lista) {
  final map = <DateTime, List<ScheduleModel>>{};
  for (final s in lista) {
    final key = DateTime(s.data.year, s.data.month, s.data.day);
    map.putIfAbsent(key, () => []).add(s);
  }
  return map;
}

List<ScheduleModel> eventsForDay(
  Map<DateTime, List<ScheduleModel>> events,
  DateTime day,
) {
  final key = DateTime(day.year, day.month, day.day);
  return events[key] ?? [];
}

DayStatus statusForDay(List<ScheduleModel> events, DateTime day) {
  if (events.isEmpty) return DayStatus.vazio;

  final trabalhos = events.where((s) => !s.isCompromisso).toList();
  final compromissos = events.where((s) => s.isCompromisso).toList();

  if (trabalhos.isEmpty && compromissos.isNotEmpty) {
    return DayStatus.somenteCompromisso;
  }

  final today = DateTime.now();
  final dayOnly = DateTime(day.year, day.month, day.day);
  final todayOnly = DateTime(today.year, today.month, today.day);
  final isPastOrToday = !dayOnly.isAfter(todayOnly);
  final allDone = trabalhos.every((s) => s.realizado);
  final anyDone = trabalhos.any((s) => s.realizado);

  DayStatus base;
  if (allDone) {
    base = DayStatus.concluido;
  } else if (isPastOrToday && !anyDone) {
    base = DayStatus.naoRealizado;
  } else if (isPastOrToday) {
    base = DayStatus.pendente;
  } else {
    base = DayStatus.futuro;
  }

  if (compromissos.isEmpty) return base;
  return DayStatus.mistoComCompromisso;
}

class DayMarker extends StatelessWidget {
  final DayStatus status;
  const DayMarker({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DayStatus.concluido:
        return const Icon(Icons.check_circle, size: 14, color: AppColors.secondary);
      case DayStatus.pendente:
        return _dot(Colors.amber);
      case DayStatus.naoRealizado:
        return _dot(Colors.red);
      case DayStatus.futuro:
        return _dot(AppColors.secondary);
      case DayStatus.somenteCompromisso:
        return _square(AppColors.primaryLight);
      case DayStatus.mistoComCompromisso:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(AppColors.secondary),
            const SizedBox(width: 2),
            _square(AppColors.primaryLight),
          ],
        );
      case DayStatus.vazio:
        return const SizedBox.shrink();
    }
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _square(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
