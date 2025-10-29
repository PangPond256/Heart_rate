import 'package:flutter/material.dart';
import 'package:smart_heart/ble/ble_manager.dart'; // ✅ Only this import

class DeviceControlPage extends StatefulWidget {
  const DeviceControlPage({Key? key}) : super(key: key);

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  final ble = BleManager().ble; // ✅ Shared BLE instance
  Stream<(int bpm, double temp)>? _dataStream;
  int _bpm = 0;
  double _temp = 0.0;
  bool _connecting = false;
  bool _connected = false;

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
    } catch (e) {
      setState(() => _connecting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Connection failed: $e')));
    }
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
    // ⚠️ Do NOT disconnect BLE here (shared connection)
    super.dispose();
  }
}
