// lib/utils/permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// ✅ ฟังก์ชันตรวจสอบและขอสิทธิ์ที่จำเป็นสำหรับ BLE และ Notification
Future<void> ensureBlePermissions() async {
  Map<Permission, PermissionStatus> statuses = {};

  if (Platform.isAndroid) {
    statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise, // ✅ สำหรับ Android 12+
      Permission.locationWhenInUse, // ✅ บางรุ่นต้องใช้ตอนสแกน
      Permission.notification, // ✅ Android 13+
      Permission.ignoreBatteryOptimizations, // ✅ ป้องกัน service ถูกปิด
    ].request();
  } else if (Platform.isIOS) {
    statuses = await [
      Permission.bluetooth,
      Permission.locationWhenInUse,
      Permission.notification, // ✅ สำหรับ iOS 15+
    ].request();
  }

  // ⚠️ แจ้งเตือนถ้ามีสิทธิ์ที่ถูกปฏิเสธถาวร
  if (statuses.values.any((status) => status.isPermanentlyDenied)) {
    await openAppSettings();
  }
}
