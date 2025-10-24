import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceControlPage extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceControlPage({super.key, required this.device});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  BluetoothCharacteristic? controlChar;
  bool deviceOn = false;

  @override
  void initState() {
    super.initState();
    _initDevice();
  }

  Future<void> _initDevice() async {
    // ค้นหา service และ characteristic ที่ใช้สั่งงานอุปกรณ์
    var services = await widget.device.discoverServices();
    for (var s in services) {
      for (var c in s.characteristics) {
        if (c.uuid.toString().contains("abcd1234")) {
          controlChar = c;
        }
      }
    }
    setState(() {});
  }

  Future<void> _sendCommand(String cmd) async {
    if (controlChar == null) return;
    await controlChar!.write(cmd.codeUnits, withoutResponse: false);
    setState(() {
      deviceOn = cmd == "ON";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ควบคุมอุปกรณ์"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              deviceOn ? Icons.power : Icons.power_off,
              color: deviceOn ? Colors.green : Colors.grey,
              size: 120,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _sendCommand("ON"),
              icon: const Icon(Icons.flash_on),
              label: const Text("เปิดอุปกรณ์"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _sendCommand("OFF"),
              icon: const Icon(Icons.flash_off),
              label: const Text("ปิดอุปกรณ์"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(
              deviceOn ? "สถานะ: เปิดอยู่" : "สถานะ: ปิดอยู่",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
