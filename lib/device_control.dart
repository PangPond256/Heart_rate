import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:smart_heart/ble/ble_manager.dart';
import 'models/history_model.dart'; // ✅ ตรวจสอบให้แน่ใจว่ามีไฟล์นี้ในโฟลเดอร์ models

class DeviceControlPage extends StatefulWidget {
  const DeviceControlPage({Key? key}) : super(key: key);

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  final ble = BleManager().ble;
  Stream<(int bpm, double temp)>? _dataStream;

  int _bpm = 0;
  double _temp = 0.0;
  bool _connecting = false;
  bool _connected = false;

  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _initBleConnection();
  }

  /// ✅ เชื่อมต่อ BLE
  Future<void> _initBleConnection() async {
    setState(() => _connecting = true);
    try {
      await ble.startScanAndConnect();
      setState(() {
        _connected = true;
        _connecting = false;
      });

      // ✅ ฟังข้อมูลจาก BLE
      _dataStream = ble.dataStream;
      _dataStream?.listen((data) {
        setState(() {
          _bpm = data.$1;
          _temp = data.$2;
        });
      });

      // ✅ เริ่มตั้งเวลาบันทึกอัตโนมัติทุก 30 นาที
      _startAutoSave();
    } catch (e) {
      setState(() => _connecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Connection failed: $e')));
    }
  }

  /// ✅ ตั้งเวลาให้บันทึกอัตโนมัติทุก 30 นาที
  void _startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      await _saveData();
    });
  }

  /// ✅ ฟังก์ชันบันทึกข้อมูล (ไม่ซ้ำวัน)
  Future<void> _saveData() async {
    if (!_connected || _bpm == 0 || _temp == 0.0) return;

    final box = Hive.box<HistoryModel>('history');
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // 🔍 ตรวจว่ามีข้อมูลของวันนี้อยู่ไหม
    final HistoryModel? existing = box.values.cast<HistoryModel?>().firstWhere(
      (item) => DateFormat('yyyy-MM-dd').format(item!.date) == todayKey,
      orElse: () => null,
    );

    if (existing != null) {
      // 🔄 ถ้ามีแล้ว → อัปเดตข้อมูลแทน
      existing
        ..bpm = _bpm
        ..temperature = _temp
        ..date = now;
      await existing.save();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🔄 Updated today’s record — BPM: $_bpm, Temp: ${_temp.toStringAsFixed(1)} °C",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // 🆕 ถ้ายังไม่มี ⇒ เพิ่มใหม่
      final record = HistoryModel(date: now, bpm: _bpm, temperature: _temp);
      await box.add(record);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "💾 New record saved — BPM: $_bpm, Temp: ${_temp.toStringAsFixed(1)} °C",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // 🧹 เก็บแค่ 7 วันล่าสุด
    if (box.length > 7) {
      final sorted = box.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      await sorted.first.delete();
    }
  }

  /// ✅ ฟังก์ชันส่งคำสั่งไปยังอุปกรณ์ BLE
  Future<void> _sendCommand(String cmd) async {
    try {
      await ble.sendCommand(cmd);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('📤 Command sent: $cmd')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⚠️ Failed to send command: $e')));
    }
  }

  /// ✅ ส่วนแสดงผล UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Control')),
      body: Center(
        child: _connecting
            ? const CircularProgressIndicator()
            : _connected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('❤️ BPM: $_bpm', style: const TextStyle(fontSize: 26)),
                  Text(
                    '🌡️ Temp: ${_temp.toStringAsFixed(1)} °C',
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _sendCommand("START"),
                    child: const Text('Start Measurement'),
                  ),
                  ElevatedButton(
                    onPressed: () => _sendCommand("STOP"),
                    child: const Text('Stop Measurement'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveData,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Now'),
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: _initBleConnection,
                child: const Text('Connect Device'),
              ),
      ),
    );
  }

  /// ✅ ยกเลิก Timer เมื่อออกจากหน้า
  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
