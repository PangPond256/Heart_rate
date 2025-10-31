// lib/utils/permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// ✅ ฟังก์ชันขอสิทธิ์ BLE + Notification (Android/iOS)
Future<bool> ensureBlePermissions() async {
  Map<Permission, PermissionStatus> statuses = {};

  if (Platform.isAndroid) {
    // ดึงเวอร์ชัน Android ปัจจุบัน เช่น "13", "14"
    final version =
        int.tryParse(
          Platform.operatingSystemVersion
              .split(' ')
              .firstWhere((x) => int.tryParse(x) != null, orElse: () => '12'),
        ) ??
        12;

    if (version >= 12) {
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.notification, // Android 13+
        Permission.ignoreBatteryOptimizations,
      ].request();
    } else {
      statuses = await [
        Permission.bluetooth,
        Permission.locationWhenInUse,
        Permission.notification,
      ].request();
    }
  } else if (Platform.isIOS) {
    statuses = await [
      Permission.bluetooth,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();
  }

  // ถ้ามีสิทธิ์ที่ไม่อนุญาต
  if (statuses.values.any((s) => !s.isGranted)) {
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      await openAppSettings();
    }
    return false;
  }

  return true;
}

/// ✅ ฟังก์ชันขอสิทธิ์เข้าถึงรูปภาพ (Gallery)
Future<bool> ensureGalleryPermission() async {
  PermissionStatus status;

  if (Platform.isAndroid) {
    // Android 13 (API 33+) ใช้ READ_MEDIA_IMAGES
    final version =
        int.tryParse(
          Platform.operatingSystemVersion
              .split(' ')
              .firstWhere((x) => int.tryParse(x) != null, orElse: () => '12'),
        ) ??
        12;

    if (version >= 13) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
    }
  } else {
    status = await Permission.photos.request();
  }

  if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  }

  return status.isGranted;
}
