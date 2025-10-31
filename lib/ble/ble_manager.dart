// 📁 lib/ble/ble_manager.dart
import 'package:flutter/material.dart';
import 'heart_ble_service.dart';

/// ✅ BLE Manager - Singleton (มี instance เดียวทั่วแอป)
class BleManager {
  // 🧩 Singleton instance
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  // ✅ บริการ BLE หลัก
  final HeartBleService ble = HeartBleService();

  // 🧠 state การเชื่อมต่อ
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// 🔧 เริ่มต้นการทำงาน (เรียกจาก main.dart)
  void init() {
    debugPrint('🚀 BLE Manager initialized');
  }

  /// 🔗 สแกนและเชื่อมต่ออุปกรณ์
  Future<void> connect() async {
    try {
      debugPrint('🔍 เริ่มสแกนหาอุปกรณ์...');
      await ble.startScanAndConnect();
      _isConnected = true;
      debugPrint('✅ BLE Connected!');
    } catch (e) {
      _isConnected = false;
      debugPrint('❌ Connect failed: $e');
      rethrow;
    }
  }

  /// 🔌 ตัดการเชื่อมต่อ BLE
  Future<void> disconnect() async {
    try {
      await ble.disconnect();
      _isConnected = false;
      debugPrint('🔌 BLE disconnected successfully');
    } catch (e) {
      debugPrint('❌ Disconnect failed: $e');
    }
  }

  /// 📡 ส่งคำสั่งไปยังอุปกรณ์ BLE (เช่น RESET, DISCONNECT, PING)
  Future<void> sendCommand(String command) async {
    try {
      if (!_isConnected) throw Exception('BLE is not connected');
      await ble.sendCommand(command);
      debugPrint('📤 Command sent: $command');
    } catch (e) {
      debugPrint('❌ Send command failed: $e');
    }
  }

  /// 🔁 รีเชื่อมต่ออัตโนมัติ (optional)
  Future<void> reconnectIfNeeded() async {
    if (!_isConnected) {
      debugPrint('🧩 BLE not connected, trying to reconnect...');
      await connect();
    }
  }

  // ------------------------------------------------------------------
  // 💓 ส่วนเสริมสำหรับ Smartwatch รุ่นล่าสุด
  // ------------------------------------------------------------------

  /// 🩺 ส่ง PING เพื่อให้บอร์ดรู้ว่ายังเชื่อมต่ออยู่ (ทุก 10–20 วิ)
  Future<void> sendPing() async {
    await sendCommand("PING");
  }

  /// 🔁 รีเซ็ตบอร์ดจากในแอป (ใช้แทนปุ่มรีเซ็ต)
  Future<void> sendReset() async {
    await sendCommand("RESET");
  }

  /// 🔌 ตัดการเชื่อมต่อจากฝั่งบอร์ด (บอร์ดจะรีสตาร์ต BLE เอง)
  Future<void> sendDisconnect() async {
    await sendCommand("DISCONNECT");
  }
}
