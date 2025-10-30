import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:smart_heart/ble/ble_manager.dart';
import 'models/history_model.dart';

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
  DateTime? _lastSavedTime; // ✅ เวลาบันทึกล่าสุดจริง (เก็บไว้ใน Hive ด้วย)

  @override
  void initState() {
    super.initState();
    _initBleConnection();
  }

  /// ✅ เชื่อมต่อกับอุปกรณ์ BLE
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

      // ✅ เริ่มตั้งเวลาเก็บข้อมูลทุก 30 นาที
      _startAutoSave();
    } catch (e) {
      setState(() => _connecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Connection failed: $e')));
    }
  }

  /// ✅ ตั้งเวลาให้บันทึกทุก 30 นาที
  void _startAutoSave() async {
    _saveTimer?.cancel(); // ป้องกัน Timer ซ้ำ

    final settingsBox = await Hive.openBox('settings');
    final lastSavedStr = settingsBox.get('lastSavedTime');
    if (lastSavedStr != null) {
      _lastSavedTime = DateTime.tryParse(lastSavedStr);
    }

    _saveTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final now = DateTime.now();
      if (_lastSavedTime == null ||
          now.difference(_lastSavedTime!).inMinutes >= 30) {
        await _saveData();
        _lastSavedTime = now;
        await settingsBox.put('lastSavedTime', now.toIso8601String());
        setState(() {}); // เพื่ออัปเดตข้อความ "Last saved"
      }
    });
  }

  /// ✅ ฟังก์ชันบันทึกข้อมูล (ทุก 30 นาที)
  Future<void> _saveData() async {
    if (!_connected || _bpm == 0 || _temp == 0.0) return;

    final box = Hive.box<HistoryModel>('history');
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // 🔍 ตรวจว่ามีข้อมูลของวันนี้หรือยัง
    final HistoryModel? existing = box.values.cast<HistoryModel?>().firstWhere(
      (item) => DateFormat('yyyy-MM-dd').format(item!.date) == todayKey,
      orElse: () => null,
    );

    if (existing != null) {
      existing
        ..bpm = _bpm
        ..temperature = _temp
        ..date = now;
      await existing.save();

      debugPrint("🔄 Updated today's record — BPM: $_bpm, Temp: $_temp");
    } else {
      final record = HistoryModel(date: now, bpm: _bpm, temperature: _temp);
      await box.add(record);
      debugPrint("💾 New record saved — BPM: $_bpm, Temp: $_temp");
    }

    // 🧹 เก็บแค่ 7 วันล่าสุด
    if (box.length > 7) {
      final sorted = box.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      await sorted.first.delete();
    }
  }

  /// ✅ ฟังก์ชันส่งคำสั่ง BLE
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

  /// ✅ UI
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
                  const SizedBox(height: 20),
                  if (_lastSavedTime != null)
                    Text(
                      "🕒 Last saved: ${DateFormat('HH:mm:ss').format(_lastSavedTime!)}",
                      style: const TextStyle(color: Colors.grey),
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

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
