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

  // ✅ สร้าง Notification Channel
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

  // ✅ การตั้งค่า Notification เริ่มต้น
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

  final settingsBox = await Hive.openBox('settings');
  final historyBox = await Hive.openBox('history');

  DateTime? lastSavedTime;
  final savedTimeStr = settingsBox.get('lastSavedTime');
  if (savedTimeStr != null) {
    lastSavedTime = DateTime.tryParse(savedTimeStr);
  }

  // ✅ Notification สำหรับเตือนเมื่อหัวใจเต้นผิดปกติ
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

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? notifyChar;

  // ✅ ฟังก์ชันเชื่อมต่อและอ่านค่าจาก ESP32
  Future<void> connectAndRead() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        if (r.device.platformName.contains('ESP32')) {
          await FlutterBluePlus.stopScan();
          connectedDevice = r.device;

          try {
            await connectedDevice!.connect(autoConnect: false);
            debugPrint('✅ Connected to ${r.device.platformName}');
          } catch (e) {
            debugPrint('❌ Connect error: $e');
            return;
          }

          final services = await connectedDevice!.discoverServices();
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

          // ✅ เปิดรับค่าชั่วคราว
          await notifyChar!.setNotifyValue(true);
          debugPrint("📡 Listening for 10 seconds...");

          final sub = notifyChar!.onValueReceived.listen((data) async {
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

            // ✅ เก็บข้อมูลแค่ครั้งเดียวในรอบ 30 นาที
            if (lastSavedTime == null ||
                now.difference(lastSavedTime!).inMinutes >= 30) {
              lastSavedTime = now;
              await settingsBox.put('lastSavedTime', now.toIso8601String());

              await historyBox.add({
                'timestamp': now.toIso8601String(),
                'bpm': bpm,
                'temp': temp,
              });

              debugPrint('💾 Saved data → BPM: $bpm, Temp: $temp');

              // ✅ แจ้งเตือนเล็ก ๆ ว่าบันทึกแล้ว
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
                  ),
                  iOS: DarwinNotificationDetails(
                    presentSound: true,
                    presentAlert: true,
                    presentBadge: true,
                  ),
                ),
              );
            }
          });

          // ✅ ปิดการฟังหลังจาก 10 วินาที
          await Future.delayed(const Duration(seconds: 10));
          await notifyChar!.setNotifyValue(false);
          await sub.cancel();
          debugPrint("🛑 Stop listening and disconnect.");

          await connectedDevice!.disconnect();
          return;
        }
      }
    });
  }

  // ✅ เรียกฟังก์ชันครั้งแรกทันที
  await connectAndRead();

  // ✅ ตั้งเวลาเรียกทุก 30 นาที
  Timer.periodic(const Duration(minutes: 30), (timer) async {
    debugPrint("🔁 Timer triggered — reconnect and read...");
    await connectAndRead();
  });

  // ✅ กันระบบปิด service เอง
  Timer.periodic(const Duration(minutes: 15), (timer) {
    service.invoke('keepAlive', {});
  });
}
