import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/history_model.dart';
import 'ble/heart_ble_service.dart'; // ✅ ใช้ BLE จริง
import 'utils/permissions.dart'; // ✅ ขอสิทธิ์ Bluetooth ก่อนสแกน

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _ble = HeartBleService();
  StreamSubscription<(int, double)>? _sub;

  bool _isMeasuring = false;
  int _heartRate = 0;
  double _progress = 0.0;
  double _temp = 36.7;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ble.disconnect(); // ✅ ตัดการเชื่อมต่อเมื่อออกจากหน้า
    _controller.dispose();
    super.dispose();
  }

  // ✅ เริ่มวัดจริงด้วย BLE (เชื่อมต่อ ESP32)
  Future<void> _startMeasurement() async {
    if (_isMeasuring) return;

    setState(() {
      _isMeasuring = true;
      _progress = 0.0;
    });

    try {
      await ensureBlePermissions(); // ✅ ขอสิทธิ์ Bluetooth
      await _ble.startScanAndConnect();

      _sub = _ble.dataStream?.listen(
        (data) async {
          final (bpm, temp) = data;

          setState(() {
            _heartRate = bpm;
            _temp = temp;
            _progress = (_progress + 0.05).clamp(0.0, 1.0);
          });

          // ✅ บันทึกค่าจริงลง Hive
          final box = Hive.box<HistoryModel>('history');
          await box.add(
            HistoryModel(date: DateTime.now(), bpm: bpm, temperature: temp),
          );

          if (_progress >= 1.0) {
            await _finalizeMeasurement();
          }
        },
        onError: (err) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('BLE Error: $err')));
        },
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Connected to ESP32')));
    } catch (e) {
      setState(() => _isMeasuring = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    }
  }

  // ✅ หยุดการวัด
  Future<void> _stopMeasurement() async {
    await _sub?.cancel();
    await _ble.disconnect();
    setState(() => _isMeasuring = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Measurement stopped')));
  }

  // ✅ บันทึกค่าครั้งสุดท้ายและ reset state
  Future<void> _finalizeMeasurement() async {
    await _sub?.cancel();
    await _ble.disconnect();

    setState(() {
      _isMeasuring = false;
      _progress = 1.0;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved to history')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(title: const Text("Measurement")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ❤️ Animated Heart
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => Transform.scale(
                        scale: 1 + 0.1 * _controller.value,
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.redAccent,
                          size: 120,
                        ),
                      ),
                    ),

                    // แสดงค่าที่อ่านได้
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          _isMeasuring
                              ? '$_heartRate BPM • ${_temp.toStringAsFixed(1)} °C'
                              : 'Ready',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),

                    // Progress Circle
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: _isMeasuring ? _progress : 0,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            color: _isMeasuring
                                ? Colors.redAccent
                                : const Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          _isMeasuring ? "Measuring..." : "Press Start",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    // ปุ่มเริ่มวัด / หยุด
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isMeasuring
                            ? _stopMeasurement
                            : _startMeasurement,
                        icon: Icon(
                          _isMeasuring ? Icons.stop : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isMeasuring ? "Stop & Save" : "Start Measurement",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isMeasuring
                              ? Colors.redAccent
                              : const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: const Size(double.infinity, 60),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ Drawer Menu เหมือน Dashboard
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Main Menu",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _menuItem(
                context,
                Icons.dashboard_outlined,
                "Dashboard",
                '/dashboard',
              ),
              _menuItem(
                context,
                Icons.show_chart_outlined,
                "History",
                '/history',
              ),
              _menuItem(
                context,
                Icons.favorite_outline,
                "Measurement",
                '/measurement',
              ),
              _menuItem(context, Icons.person_outline, "Profile", '/profile'),
              _menuItem(
                context,
                Icons.settings_outlined,
                "Settings",
                '/settings',
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Close Menu",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1E3A8A)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
