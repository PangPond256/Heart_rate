import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smart_heart/ble/ble_manager.dart';
import 'models/history_model.dart'; // ✅ ต้องมี model นี้ในโฟลเดอร์ models

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

  Future<void> _initBleConnection() async {
    setState(() => _connecting = true);
    try {
      await ble.startScanAndConnect();
      setState(() {
        _connected = true;
        _connecting = false;
      });

      _dataStream = ble.dataStream;
      _dataStream?.listen((data) {
        setState(() {
          _bpm = data.$1;
          _temp = data.$2;
        });
      });

      // ✅ Start auto-save timer
      _startAutoSave();
    } catch (e) {
      setState(() => _connecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Connection failed: $e')));
    }
  }

  void _startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      await _saveData();
    });
  }

  Future<void> _saveData() async {
    if (!_connected || _bpm == 0 || _temp == 0.0) return;

    final box = Hive.box<HistoryModel>('history');
    final record = HistoryModel(
      date: DateTime.now(),
      bpm: _bpm,
      temperature: _temp,
    );

    await box.add(record);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "💾 Data saved — BPM: $_bpm, Temp: ${_temp.toStringAsFixed(1)} °C",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
