import 'dart:async';
import 'package:flutter/widgets.dart'; // ✅ ต้องมี
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 🔔 ตัวแปรหลัก
final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();
final AudioPlayer _player = AudioPlayer();

/// ✅ เริ่มต้น Background Service
Future<void> initializeService() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ ป้องกัน crash
  await Hive.initFlutter(); // ✅ ให้ Hive พร้อมใช้ใน isolate

  // ตั้งค่า Notification สำหรับ Android & iOS
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await _notifications.initialize(initSettings);

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
  WidgetsFlutterBinding.ensureInitialized(); // ✅ สำคัญมาก
  await Hive.initFlutter(); // ✅ เพื่อใช้ Hive ได้ใน isolate

  // ✅ ตั้งค่า Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'heart_alerts',
    'Heart Alerts',
    description: 'Alert channel for abnormal heart rates',
    importance: Importance.max,
  );

  await _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // ✅ เริ่มสแกนหาอุปกรณ์ ESP32
  FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

  FlutterBluePlus.scanResults.listen((results) async {
    for (final r in results) {
      // ✅ ใช้ platformName แทน name (ป้องกัน deprecated)
      if (r.device.platformName.contains('ESP32')) {
        await FlutterBluePlus.stopScan();
        await r.device.connect(autoConnect: false);

        // ค้นหา Service และ Characteristic
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

        notifyChar.onValueReceived.listen((data) async {
          try {
            final line = String.fromCharCodes(data).trim();
            if (line.isEmpty) return;

            final parts = line.split(',');
            final bpm = double.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
            final temp = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

            // ✅ อ่านค่า settings ก่อนแจ้งเตือน
            final box = await Hive.openBox('settings');
            final notifyEnabled = box.get(
              'notificationsEnabled',
              defaultValue: true,
            );

            if (!notifyEnabled) {
              debugPrint('🔕 Notifications disabled by user.');
              return;
            }

            // ✅ ตรวจจับค่าผิดปกติ
            if (bpm < 50 || bpm > 120) {
              await _player.stop();
              await _player.play(AssetSource('sounds/alert.mp3'));

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
  Timer.periodic(const Duration(minutes: 15), (timer) {
    service.invoke('keepAlive', {});
  });
}
