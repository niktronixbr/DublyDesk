import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _channelId = 'dublydesk_channel';
  static const String _channelName = 'DublyDesk Notifications';
  static const String _channelDescription =
      'Notificações de escalas de dublagem';

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );

    tz.initializeTimeZones();

    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);

    _initialized = true;
  }

  static Future<void> requestAndroidPermissions() async {
    await init();

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    try {
      await androidImplementation?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de notificações: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await init();

    final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    debugPrint('Tentando agendar notificação:');
    debugPrint('id: $id');
    debugPrint('title: $title');
    debugPrint('body: $body');
    debugPrint('scheduledDate original: $scheduledDate');
    debugPrint('scheduledDate tz: $scheduled');
    debugPrint('now tz: $now');

    if (!scheduled.isAfter(now)) {
      debugPrint(
        'Notificação ignorada porque a data já passou ou é igual ao momento atual.',
      );
      return;
    }

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('Notificação agendada com sucesso.');
    } catch (e) {
      debugPrint('Erro real ao agendar notificação: $e');
      rethrow;
    }
  }

  static Future<void> scheduleAgendaNotification({
    required int id,
    String? title,
    String? titulo,
    String? body,
    String? corpo,
    String? mensagem,
    required DateTime dataHora,
    String? payload,
  }) async {
    final effectiveTitle = title ?? titulo ?? 'Lembrete de escala';
    final effectiveBody =
        body ?? corpo ?? mensagem ?? 'Você tem uma escala agendada.';

    await scheduleNotification(
      id: id,
      title: effectiveTitle,
      body: effectiveBody,
      scheduledDate: dataHora,
      payload: payload,
    );
  }

  /// Agenda lembretes conforme seleção do usuário.
  /// Offsets: 0 = 60min, 1 = 30min, 2 = 5min, 3 = exato
  static Future<void> scheduleDefaultAgendaNotifications({
    required int baseId,
    required String corpo,
    required DateTime dataHora,
    Map<String, bool>? lembretes,
  }) async {
    await init();
    await cancelAgendaNotifications(baseId);

    final l = lembretes ?? {
      '60min': false,
      '30min': true,
      '5min': true,
      'exato': true,
    };

    if (l['60min'] == true) {
      await scheduleAgendaNotification(
        id: _notificationId(baseId, 0),
        titulo: 'Escala em 1 hora',
        corpo: corpo,
        dataHora: dataHora.subtract(const Duration(minutes: 60)),
      );
    }

    if (l['30min'] != false) {
      await scheduleAgendaNotification(
        id: _notificationId(baseId, 1),
        titulo: 'Escala em 30 min',
        corpo: corpo,
        dataHora: dataHora.subtract(const Duration(minutes: 30)),
      );
    }

    if (l['5min'] != false) {
      await scheduleAgendaNotification(
        id: _notificationId(baseId, 2),
        titulo: 'Escala em 5 min',
        corpo: corpo,
        dataHora: dataHora.subtract(const Duration(minutes: 5)),
      );
    }

    if (l['exato'] != false) {
      await scheduleAgendaNotification(
        id: _notificationId(baseId, 3),
        titulo: 'Escala agora',
        corpo: corpo,
        dataHora: dataHora,
      );
    }
  }

  static Future<void> cancelAgendaNotifications(int baseId) async {
    await init();
    await _notifications.cancel(id: _notificationId(baseId, 0));
    await _notifications.cancel(id: _notificationId(baseId, 1));
    await _notifications.cancel(id: _notificationId(baseId, 2));
    await _notifications.cancel(id: _notificationId(baseId, 3));
  }

  static int _notificationId(int baseId, int offset) {
    return baseId * 10 + offset;
  }

  static Future<void> cancelNotification(int id) async {
    await init();
    await _notifications.cancel(id: id);
  }

  static Future<void> cancelAllNotifications() async {
    await init();
    await _notifications.cancelAll();
  }
}