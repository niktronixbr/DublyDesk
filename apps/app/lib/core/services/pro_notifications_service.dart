import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/entitlement_model.dart';

class ProNotificationsService {
  static const _channelId = 'pro_trial';
  static const _channelName = 'Trial Pro';

  static const _idDay7 = 9001;
  static const _idDay3 = 9002;
  static const _idDay1 = 9003;

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Agenda 3 notificações ancoradas em [entitlement.until], em D-7, D-3, D-1.
  /// Cancela agendamentos antigos primeiro pra evitar duplicação.
  /// Silencia qualquer erro para não crashar em ambientes sem plataforma
  /// inicializada (ex.: testes unitários).
  static Future<void> scheduleTrialReminders(EntitlementModel ent) async {
    try {
      await cancelAll();
      if (!ent.trial || ent.until == null) return;

      final scheduledAt = ent.until!;
      final remind7 = scheduledAt.subtract(const Duration(days: 7));
      final remind3 = scheduledAt.subtract(const Duration(days: 3));
      final remind1 = scheduledAt.subtract(const Duration(days: 1));

      final now = DateTime.now();
      if (remind7.isAfter(now)) {
        await _schedule(
          _idDay7,
          remind7,
          'Trial Pro: 7 dias restantes',
          'Aproveite as features Pro antes do fim do trial.',
        );
      }
      if (remind3.isAfter(now)) {
        await _schedule(
          _idDay3,
          remind3,
          'Trial Pro: 3 dias restantes',
          'Seu trial termina em breve. Continue ou cancele a qualquer momento.',
        );
      }
      if (remind1.isAfter(now)) {
        await _schedule(
          _idDay1,
          remind1,
          'Trial Pro: amanhã expira',
          'Seu trial expira amanhã. Renovação automática se não cancelar.',
        );
      }
    } catch (e) {
      debugPrint('ProNotificationsService.scheduleTrialReminders error: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancel(id: _idDay7);
      await _plugin.cancel(id: _idDay3);
      await _plugin.cancel(id: _idDay1);
    } catch (e) {
      debugPrint('ProNotificationsService.cancelAll error: $e');
    }
  }

  static Future<void> _schedule(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Avisos do trial Pro',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('ProNotificationsService.schedule error: $e');
    }
  }
}
