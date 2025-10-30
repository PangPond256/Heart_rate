// lib/background_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(serviceChannel);

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await notifications.initialize(initSettings);

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

  final player = AudioPlayer();
  await player.setReleaseMode(ReleaseMode.stop);

  final settingsBox = await Hive.openBox('settings');
  final historyBox = await Hive.openBox('history');

  DateTime? lastSavedTime;
  final savedTimeStr = settingsBox.get('lastSavedTime');
  if (savedTimeStr != null) {
    lastSavedTime = DateTime.tryParse(savedTimeStr);
  }

  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'heart_alerts',
    'Heart Alerts',
    description: 'Alerts for abnormal heart rate readings',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('alert'),
  );

  await _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(alertChannel);

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

            // ✅ เงื่อนไขบันทึกทุก 30 นาที
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

              await _notifications.show(
                1,
                '✅ Data Saved',
                'Heart data recorded at ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heart_monitor',
                    'Heart Monitor Service',
                    importance: Importance.low,
                    priority: Priority.low,
                  ),
                ),
              );
            }

            // ✅ ตรวจจับค่าผิดปกติ (เตือนทันที)
            final notifyEnabled = settingsBox.get(
              'notificationsEnabled',
              defaultValue: true,
            );
            if (notifyEnabled && (bpm < 50 || bpm > 120)) {
              await player.stop();
              await player.play(AssetSource('sounds/alert.mp3'));
              await _notifications.show(
                0,
                '⚠️ Abnormal Heart Rate',
                'Heart rate: ${bpm.toStringAsFixed(1)} BPM — Temp: ${temp.toStringAsFixed(1)} °C',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heart_alerts',
                    'Heart Alerts',
                    channelDescription: 'Notification for abnormal heart rate',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: true,
                    enableVibration: true,
                    sound: RawResourceAndroidNotificationSound('alert'),
                  ),
                  iOS: DarwinNotificationDetails(
                    presentSound: true,
                    presentAlert: true,
                    presentBadge: true,
                  ),
                ),
              );
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
