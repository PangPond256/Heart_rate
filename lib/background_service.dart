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
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(serviceChannel);

  // ✅ การตั้งค่าเริ่มต้นของ Notification
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

  // ✅ เปิด Hive boxes
  final settingsBox = await Hive.openBox('settings');
  final historyBox = await Hive.openBox('history');

  // ✅ โหลดเวลาบันทึกล่าสุดจาก Hive
  DateTime? lastSavedTime;
  final savedTimeStr = settingsBox.get('lastSavedTime');
  if (savedTimeStr != null) {
    lastSavedTime = DateTime.tryParse(savedTimeStr);
    debugPrint("🕓 Last saved time loaded: $lastSavedTime");
  }

  // ✅ Channel สำหรับแจ้งเตือนหัวใจเต้นผิดปกติ
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

  // ✅ เริ่มสแกนหา ESP32
  FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

  BluetoothDevice? connectedDevice;

  FlutterBluePlus.scanResults.listen((results) async {
    for (final r in results) {
      if (r.device.platformName.contains('ESP32')) {
        await FlutterBluePlus.stopScan();

        try {
          connectedDevice = r.device;
          await connectedDevice!.connect(autoConnect: false);
          debugPrint('✅ Connected to ${r.device.platformName}');
        } catch (e) {
          debugPrint('❌ Connect error: $e');
          continue;
        }

        // ✅ ค้นหา Service และ Characteristic
        final services = await connectedDevice!.discoverServices();
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
          debugPrint('❌ Notify characteristic not found!');
          return;
        }

        await notifyChar.setNotifyValue(true);

        notifyChar.onValueReceived.listen((data) async {
          try {
            final line = String.fromCharCodes(data).trim();
            if (line.isEmpty) return;

            final parts = line.split(',');
            final bpm = double.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
            final temp = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
            final notifyEnabled = settingsBox.get(
              'notificationsEnabled',
              defaultValue: true,
            );

            final now = DateTime.now();

            // ✅ เก็บข้อมูลทุก 30 นาทีจริง ๆ
            if (lastSavedTime == null ||
                now.difference(lastSavedTime!).inMinutes >= 30) {
              lastSavedTime = now;
              await settingsBox.put('lastSavedTime', now.toIso8601String());

              await historyBox.add({
                'timestamp': now.toIso8601String(),
                'bpm': bpm,
                'temp': temp,
              });

              debugPrint('💾 [BG] Saved at $now → BPM: $bpm, Temp: $temp');
            }

            // ✅ แจ้งเตือนเมื่อค่าผิดปกติ
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
            debugPrint('⚠️ Parse error: $e');
            debugPrint(st.toString());
          }
        });

        // ✅ ตรวจสอบ reconnect
        connectedDevice!.connectionState.listen((state) async {
          if (state == BluetoothConnectionState.disconnected) {
            debugPrint('🔁 Device disconnected — retry in 10s...');
            await Future.delayed(const Duration(seconds: 10));
            try {
              await connectedDevice!.connect(autoConnect: false);
            } catch (_) {}
          }
        });

        break;
      }
    }
  });

  // ✅ ป้องกันไม่ให้ระบบปิด service เอง
  Timer.periodic(const Duration(minutes: 15), (timer) {
    service.invoke('keepAlive', {});
  });
}
