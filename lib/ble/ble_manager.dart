import 'heart_ble_service.dart';

/// ✅ BLE Manager - Singleton (สร้างแค่หนึ่งครั้งทั่วแอป)
class BleManager {
  // สร้าง instance เดียวเท่านั้น (Singleton)
  static final BleManager _instance = BleManager._internal();

  // ตัวเรียกใช้งาน (ใช้ BleManager() ได้จากทุกหน้า)
  factory BleManager() => _instance;

  // constructor ภายใน
  BleManager._internal();

  // ✅ สร้างอ็อบเจกต์ HeartBleService แค่ครั้งเดียว
  final HeartBleService ble = HeartBleService();

  /// ✅ ฟังก์ชัน init() (เพื่อให้ main.dart เรียกใช้ได้โดยไม่ error)
  void init() {
    // ถ้าต้องการเพิ่มการ setup เช่น auto reconnect, permission check
    // สามารถเพิ่มได้ในนี้
  }
}
