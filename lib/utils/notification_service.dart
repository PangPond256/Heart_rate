// lib/utils/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// ✅ เริ่มต้นระบบแจ้งเตือน (เรียกใน main.dart)
  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // ✅ สร้างช่องแจ้งเตือนหลัก
    const AndroidNotificationChannel defaultChannel =
        AndroidNotificationChannel(
          'heart_monitor',
          'Heart Monitor Service',
          description: 'Foreground service for heart rate monitoring',
          importance: Importance.low,
        );

    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      'heart_alerts',
      'Heart Alerts',
      description: 'Notifications for abnormal heart rate',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(defaultChannel);
    await androidPlugin?.createNotificationChannel(alertChannel);
  }

  /// 🔔 ฟังก์ชันแสดงแจ้งเตือนทั่วไป
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'heart_monitor',
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    bool playSound = false,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'General Notifications',
          importance: importance,
          priority: priority,
          playSound: playSound,
          enableVibration: playSound,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound,
        ),
      ),
    );
  }
}
