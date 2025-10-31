import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 🔔 ตัวแปรหลัก
final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

Future<void> initializeService() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Channel สำหรับ Service
  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    'heart_monitor',
    'Heart Monitor Service',
    description: 'Foreground service for continuous heart rate monitoring',
    importance: Importance.low,
  );

  await _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(serviceChannel);

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _notifications.initialize(initSettings);

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'heart_monitor',
      initialNotificationTitle: 'HeartSense Running',
      initialNotificationContent: 'Monitoring heart rate in background...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  if (kDebugMode) debugPrint('iOS background fetch triggered');
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final settingsBox = await Hive.openBox('settings');
  final historyBox = await Hive.openBox('history');

  DateTime? lastSavedTime;
  final savedTimeStr = settingsBox.get('lastSavedTime');
  if (savedTimeStr != null) {
    lastSavedTime = DateTime.tryParse(savedTimeStr);
  }

  // 🔔 Channel สำหรับ Alert
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'heart_alerts',
    'Heart Alerts',
    description: 'Alerts for abnormal heart rate readings',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(alertChannel);

  // 🔧 ตัวแปร latch ป้องกันแจ้งเตือนซ้ำ
  bool hrAlertLatched = false;
  int overCount = 0;
  int underCount = 0;
  const int HR_HIGH = 120;
  const int HR_RESET = 100;
  const int CONFIRM_OVER = 3;
  const int CONFIRM_UNDER = 3;

  FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

  FlutterBluePlus.scanResults.listen((results) async {
    for (final r in results) {
      if (r.device.platformName.contains('ESP32')) {
        await FlutterBluePlus.stopScan();
        final device = r.device;
        await device.connect(autoConnect: false);
        debugPrint('✅ Connected to ${device.platformName}');

        final services = await device.discoverServices();
        BluetoothCharacteristic? notifyChar;
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toUpperCase() ==
                '6E400003-B5A3-F393-E0A9-E50E24DCCA9E') {
              notifyChar = c;
              break;
            }
          }
        }

        if (notifyChar == null) {
          debugPrint('❌ Characteristic not found!');
          return;
        }

        await notifyChar.setNotifyValue(true);

        notifyChar.onValueReceived.listen((data) async {
          try {
            final line = String.fromCharCodes(data).trim();
            if (line.isEmpty) return;

            final parts = line.split(',');
            final bpm = double.tryParse(parts[0]) ?? 0;
            final temp = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
            final now = DateTime.now();

            // ✅ เฉลี่ยบันทึกทุก 30 นาที
            if (lastSavedTime == null ||
                now.difference(lastSavedTime!).inMinutes >= 30) {
              lastSavedTime = now;
              await settingsBox.put('lastSavedTime', now.toIso8601String());
              await historyBox.add({
                'timestamp': now.toIso8601String(),
                'bpm': bpm,
                'temp': temp,
              });
              debugPrint('💾 Saved at $now → BPM: $bpm, Temp: $temp');
            }

            // ✅ แจ้งเตือน HR สูงเพียงครั้งเดียว
            if (!hrAlertLatched) {
              if (bpm >= HR_HIGH) {
                overCount++;
                underCount = 0;
                if (overCount >= CONFIRM_OVER) {
                  hrAlertLatched = true;
                  overCount = 0;
                  await _notifications.show(
                    10,
                    '⚠️ Heart Rate Too High',
                    'หัวใจเต้นเร็ว $bpm BPM (เกิน 120)',
                    const NotificationDetails(
                      android: AndroidNotificationDetails(
                        'heart_alerts',
                        'Heart Alerts',
                        channelDescription:
                            'Notification for high heart rate alert',
                        importance: Importance.max,
                        priority: Priority.high,
                        playSound: true,
                        enableVibration: true,
                      ),
                      iOS: DarwinNotificationDetails(
                        presentSound: true,
                        presentAlert: true,
                      ),
                    ),
                  );
                }
              } else {
                overCount = 0;
              }
            } else {
              // ✅ Reset เมื่อกลับมาปกติ
              if (bpm < HR_RESET) {
                underCount++;
                if (underCount >= CONFIRM_UNDER) {
                  hrAlertLatched = false;
                  underCount = 0;
                  debugPrint('🟢 Heart rate back to normal');
                }
              } else {
                underCount = 0;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Parse error: $e');
          }
        });
      }
    }
  });

  // ✅ ป้องกันระบบปิด service เอง
  Timer.periodic(const Duration(minutes: 15), (timer) {
    service.invoke('keepAlive', {});
  });
}
