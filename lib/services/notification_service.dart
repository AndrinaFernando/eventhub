import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> showBookingNotification({
    required String bookingId,
    required String title,
    required String body,
  }) async {
    // This implementation provides Android device notifications.
    // Chrome continues to use the app's existing confirmation messages.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      if (!_initialized) {
        final initialized = await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
          ),
        );

        if (initialized != true) return;

        _initialized = true;
      }

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) return;

      final allowed =
          await androidPlugin.requestNotificationsPermission();

      if (allowed != true) return;

      // Reuse the notification ID when this booking is cancelled.
      final notificationId =
          int.parse(bookingId.replaceAll('-', '').substring(0, 8), radix: 16)
              & 0x7fffffff;

      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'eventhub_bookings',
            'Booking updates',
            channelDescription: 'Booking confirmations and cancellations',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (error) {
      // A notification problem must not turn a successful booking
      // into an apparent booking failure.
      debugPrint('Notification could not be displayed: $error');
    }
  }
}