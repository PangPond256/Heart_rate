import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hive/hive.dart';
import 'models/history_model.dart';
import 'ble/heart_ble_service.dart';
import 'utils/permissions.dart';
import 'drawer.dart';

class HeartSenseDashboard extends StatefulWidget {
  const HeartSenseDashboard({super.key});

  @override
  State<HeartSenseDashboard> createState() => _HeartSenseDashboardState();
}

class _HeartSenseDashboardState extends State<HeartSenseDashboard>
    with SingleTickerProviderStateMixin {
  final _ble = HeartBleService();
  StreamSubscription<(int, double)>? _sub;
  late AnimationController _heartController;

  int _bpm = 0;
  double _temp = 0.0;
  double _avgBpm = 0;
  double _maxBpm = 0;
  double _minBpm = 0;

  bool _isConnected = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ble.disconnect();
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final box = Hive.box<HistoryModel>('history');
      if (box.isEmpty) return;

      final data = box.values.map((e) => e.bpm).toList();
      setState(() {
        _avgBpm = data.reduce((a, b) => a + b) / data.length;
        _maxBpm = data.reduce((a, b) => a > b ? a : b).toDouble();
        _minBpm = data.reduce((a, b) => a < b ? a : b).toDouble();
      });
    } catch (e) {
      debugPrint("⚠️ Hive not ready: $e");
    }
  }

  Future<void> _connectBle() async {
    if (_isScanning || _isConnected) return;

    setState(() => _isScanning = true);
    try {
      await ensureBlePermissions(); // ✅ ขอสิทธิ์ก่อนเริ่มสแกน
      await _ble.startScanAndConnect();
      setState(() {
        _isConnected = true;
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Connected to ESP32')));
      }

      _sub = _ble.dataStream?.listen(
        (data) async {
          final (bpm, temp) = data;
          setState(() {
            _bpm = bpm;
            _temp = temp;
          });

          // ✅ บันทึกค่าลง Hive อัตโนมัติทุกเฟรม
          final box = Hive.box<HistoryModel>('history');
          await box.add(
            HistoryModel(date: DateTime.now(), bpm: bpm, temperature: temp),
          );

          _loadStats(); // อัปเดตสรุปสถิติ
        },
        onError: (err) async {
          debugPrint('BLE stream error: $err');
          setState(() {
            _isConnected = false;
          });
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) _connectBle(); // ✅ auto-reconnect
        },
      );
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
      }
    }
  }

  String _healthStatus() {
    if (_bpm == 0) return 'No Data';
    if (_bpm < 60) return 'Low Heart Rate';
    if (_bpm > 100) return 'High Heart Rate';
    return 'Normal Range';
  }

  Color _statusColor() {
    if (_bpm < 60) return Colors.orange;
    if (_bpm > 100) return Colors.redAccent;
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      drawer: MainDrawer(
        onSelect: (route) {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
      ),
      appBar: AppBar(
        title: const Text("HeartSense Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: "Reconnect BLE",
            onPressed: _connectBle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ❤️ Real-time Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark
                    ? []
                    : [const BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _heartController,
                    builder: (_, __) => Transform.scale(
                      scale: 1 + 0.08 * _heartController.value,
                      child: Icon(
                        LucideIcons.heartPulse,
                        color: _statusColor(),
                        size: 70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_bpm BPM',
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _healthStatus(),
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 🌡️ Real-time Temperature
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.thermostat, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        "${_temp.toStringAsFixed(1)} °C",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isConnected ? null : _connectBle,
                    icon: Icon(
                      _isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_searching,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isConnected
                          ? "Connected to ESP32"
                          : (_isScanning
                                ? "Scanning..."
                                : "Connect BLE Device"),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 📊 Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? []
                    : [const BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Summary",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    "Average",
                    "${_avgBpm.toStringAsFixed(0)} BPM",
                  ),
                  _buildSummaryRow("Max", "${_maxBpm.toStringAsFixed(0)} BPM"),
                  _buildSummaryRow("Min", "${_minBpm.toStringAsFixed(0)} BPM"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
