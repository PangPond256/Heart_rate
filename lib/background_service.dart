import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 🔔 ตัวแปรหลัก
final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

/// ✅ เริ่มต้น Background Service
Future<void> initializeService() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // ✅ Notification Channel สำหรับ Foreground Service
  const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
    'heart_monitor',
    'Heart Monitor Service',
    description: 'Foreground service for continuous heart rate monitoring',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(serviceChannel);

  // ✅ ตั้งค่า Notification Initialization
  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await notifications.initialize(initSettings);

  // ✅ ตั้งค่า Background Service
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'heart_monitor',
      initialNotificationTitle: 'Heart Monitor Active',
      initialNotificationContent: 'Monitoring your heart rate...',
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

/// ✅ สำหรับ iOS Background Handler
@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  if (kDebugMode) debugPrint('iOS background fetch triggered');
  return true;
}

/// ✅ ฟังก์ชันเริ่มเมื่อ Service ทำงาน
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final player = AudioPlayer();
  await player.setReleaseMode(ReleaseMode.stop);

  // ✅ สร้างช่องแจ้งเตือน BPM ผิดปกติ (พร้อมเสียง)
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'heart_alerts',
    'Heart Alerts',
    description: 'Alert channel for abnormal heart rates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('alert'),
  );

  await _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  // ✅ เปิด Hive Box ที่ใช้เก็บข้อมูล
  final settingsBox = await Hive.openBox('settings');
  final historyBox = await Hive.openBox('history');

  // ✅ โหลดเวลาบันทึกล่าสุดจาก Hive
  DateTime? lastSavedTime;
  final lastSavedStr = settingsBox.get('lastSavedTime');
  if (lastSavedStr != null) {
    lastSavedTime = DateTime.tryParse(lastSavedStr);
  }

  // ✅ เริ่มสแกนหาอุปกรณ์ ESP32
  FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

  FlutterBluePlus.scanResults.listen((results) async {
    for (final r in results) {
      if (r.device.platformName.contains('ESP32')) {
        await FlutterBluePlus.stopScan();
        await r.device.connect(autoConnect: false);

        // ✅ ค้นหา Service และ Characteristic
        final services = await r.device.discoverServices();
        BluetoothCharacteristic? notifyChar;

        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toUpperCase() ==
                '6E400003-B5A3-F393-E0A9-E50E24DCCA9E') {
              notifyChar = c;
              break;
            }
          }
          if (notifyChar != null) break;
        }

        if (notifyChar == null) {
          debugPrint('❌ Characteristic not found!');
          return;
        }

        await notifyChar.setNotifyValue(true);

        // ✅ เมื่อได้รับค่าจาก ESP32
        notifyChar.onValueReceived.listen((data) async {
          try {
            final line = String.fromCharCodes(data).trim();
            if (line.isEmpty) return;

            final parts = line.split(',');
            final bpm = double.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
            final temp =
                double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

            final notifyEnabled = settingsBox.get(
              'notificationsEnabled',
              defaultValue: true,
            );

            final now = DateTime.now();

            // ✅ เก็บข้อมูลทุก 30 นาที (null-safe)
            if (lastSavedTime == null ||
                now.difference(lastSavedTime!).inMinutes >= 30) {
              lastSavedTime = now;
              await settingsBox.put('lastSavedTime', now.toIso8601String());

              await historyBox.add({
                'timestamp': now.toIso8601String(),
                'bpm': bpm,
                'temp': temp,
              });

              debugPrint('🕒 [BG] Saved at $now | BPM: $bpm | Temp: $temp');

              // 🧹 เก็บแค่ 7 วันล่าสุด
              if (historyBox.length > 7) {
                final entries = historyBox.toMap().entries.toList();
                entries.sort((a, b) {
                  final timeA = DateTime.tryParse(a.value['timestamp'] ?? '') ??
                      DateTime.now();
                  final timeB = DateTime.tryParse(b.value['timestamp'] ?? '') ??
                      DateTime.now();
                  return timeA.compareTo(timeB);
                });

                await historyBox.delete(entries.first.key);
                debugPrint(
                    '🧹 Deleted oldest record (${entries.first.value['timestamp']})');
              }
            }

            // ✅ แจ้งเตือนค่าผิดปกติ
            if (notifyEnabled && (bpm < 50 || bpm > 120)) {
              await player.stop();
              await player.play(AssetSource('sounds/alert.mp3'));

              await _notifications.show(
                0,
                '⚠️ Abnormal Heart Rate',
                'Your heart rate is ${bpm.toStringAsFixed(1)} BPM at ${temp.toStringAsFixed(1)} °C',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heart_alerts',
                    'Heart Alerts',
                    channelDescription:
                        'Notification when heart rate is abnormal',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: true,
                    enableVibration: true,
                    sound: RawResourceAndroidNotificationSound('alert'),
                    visibility: NotificationVisibility.public,
                  ),
                  iOS: DarwinNotificationDetails(
                    presentSound: true,
                    presentAlert: true,
                    presentBadge: true,
                  ),
                ),
              );
            }
          } catch (e, st) {
            debugPrint('Parse error: $e');
            debugPrint(st.toString());
          }
        });

        break;
      }
    }
  });

  // ✅ ป้องกันไม่ให้ระบบปิด service เอง
  Timer.periodic(const Duration(minutes: 15), (_) {
    service.invoke('keepAlive', {});
  });
}
