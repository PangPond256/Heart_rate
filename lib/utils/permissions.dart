// lib/utils/permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<void> ensureBlePermissions() async {
  if (Platform.isAndroid) {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // บางรุ่นต้องใช้ตอนสแกน
    ].request();
  } else if (Platform.isIOS) {
    await [
      Permission.bluetooth,
      Permission.locationWhenInUse, // เผื่อ iOS บางเวอร์ชัน
    ].request();
  }
}
