import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:smart_heart/models/history_model.dart';
import 'package:smart_heart/database/local_db.dart';

/// ✅ Heart BLE Service (เวอร์ชันใหม่ รองรับ ESP32 รีเซ็ตตัวเองได้)
class HeartBleService {
  static const String defaultDeviceName = 'HeartSense-ESP32';
  static const String defaultServiceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String defaultNotifyCharUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String defaultCommandCharUuid =
      '6E400004-B5A3-F393-E0A9-E50E24DCCA9E'; // ✅ ใช้แทน 6E400002

  HeartBleService({
    this.targetDeviceName = defaultDeviceName,
    this.serviceUuid = defaultServiceUuid,
    this.notifyCharUuid = defaultNotifyCharUuid,
    this.commandCharUuid = defaultCommandCharUuid,
    this.scanTimeout = const Duration(seconds: 8),
    this.connectTimeout = const Duration(seconds: 10),
  });

  final String targetDeviceName;
  final String serviceUuid;
  final String notifyCharUuid;
  final String commandCharUuid;
  final Duration scanTimeout;
  final Duration connectTimeout;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _cmdChar;
  Stream<(int bpm, double temp)>? dataStream;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  bool _connected = false;

  DateTime? _lastSavedTime;
  double _accTemp = 0;
  int _accBpm = 0;
  int _count = 0;

  bool _uuidEq(Guid guid, String uuidStr) =>
      guid.toString().toUpperCase() == uuidStr.toUpperCase();

  bool _advHasService(AdvertisementData adv, String svcUuid) {
    final target = svcUuid.toUpperCase();
    for (final u in adv.serviceUuids) {
      if (u.toString().toUpperCase() == target) return true;
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // 🔍 เริ่มสแกนและเชื่อมต่อ Smartwatch
  // --------------------------------------------------------------------------
  Future<void> startScanAndConnect() async {
    if (_connected && _device != null) return;

    final btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      throw StateError('Bluetooth is OFF');
    }

    final completer = Completer<void>();
    await FlutterBluePlus.startScan(timeout: scanTimeout);

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        final adv = r.advertisementData;
        final name = r.device.platformName.trim();
        final advName = adv.advName.trim();

        final nameMatch =
            name == targetDeviceName || advName == targetDeviceName;
        final svcMatch = _advHasService(adv, serviceUuid);

        if (nameMatch || svcMatch) {
          try {
            await FlutterBluePlus.stopScan();
            _device = r.device;

            final state = await _device!.connectionState.first;
            if (state != BluetoothConnectionState.connected) {
              await _device!.connect(timeout: connectTimeout);
            }

            debugPrint('✅ Connected to ${_device!.platformName}');
            _connected = true;

            await _discoverAndSubscribe();

            if (!completer.isCompleted) completer.complete();
            break;
          } catch (e) {
            debugPrint('❌ Connect failed: $e');
            _connected = false;
            _device = null;
            await FlutterBluePlus.startScan(timeout: scanTimeout);
          }
        }
      }
    });

    Future.delayed(scanTimeout + const Duration(seconds: 2), () async {
      if (!completer.isCompleted) {
        await FlutterBluePlus.stopScan();
        _cancelScanSub();
        completer.completeError(
          TimeoutException('Device not found: $targetDeviceName'),
        );
      }
    });

    return completer.future.whenComplete(_cancelScanSub);
  }

  // --------------------------------------------------------------------------
  // 🔎 ค้นหา Service และ Characteristics ที่ใช้
  // --------------------------------------------------------------------------
  Future<void> _discoverAndSubscribe() async {
    if (_device == null) throw StateError('No device found');

    final services = await _device!.discoverServices();
    BluetoothCharacteristic? notifyChar;
    BluetoothCharacteristic? cmdChar;

    for (final s in services) {
      if (_uuidEq(s.uuid, serviceUuid)) {
        for (final c in s.characteristics) {
          if (_uuidEq(c.uuid, notifyCharUuid) && c.properties.notify) {
            notifyChar = c;
          } else if (_uuidEq(c.uuid, commandCharUuid) && c.properties.write) {
            cmdChar = c;
          }
        }
      }
    }

    if (notifyChar == null) {
      throw StateError('Notify characteristic not found');
    }

    if (cmdChar == null) {
      throw StateError('Command characteristic not found');
    }

    _notifyChar = notifyChar;
    _cmdChar = cmdChar;

    await _notifyChar!.setNotifyValue(true);
    _listenToData(_notifyChar!);

    debugPrint('✅ Service discovery completed.');
  }

  // --------------------------------------------------------------------------
  // 📡 ฟังข้อมูลจาก BLE (BPM, Temp)
  // --------------------------------------------------------------------------
  void _listenToData(BluetoothCharacteristic characteristic) {
    final rawStream = characteristic.onValueReceived;
    dataStream = rawStream.map<(int, double)>((bytes) {
      try {
        final line = utf8.decode(bytes).trim();
        final parts = line.split(',');
        final bpm = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
        final temp = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0.0;
        _handleIncomingData(bpm, temp);
        return (bpm, temp);
      } catch (_) {
        return (0, 0.0);
      }
    });

    _notifySub = rawStream.listen((bytes) {}, onError: (_) {});
  }

  // --------------------------------------------------------------------------
  // 💾 เก็บค่าเฉลี่ยทุก 30 นาที
  // --------------------------------------------------------------------------
  void _handleIncomingData(int bpm, double temp) {
    _accBpm += bpm;
    _accTemp += temp;
    _count++;

    final now = DateTime.now();
    _lastSavedTime ??= now;

    if (now.difference(_lastSavedTime!).inMinutes >= 30 && _count > 0) {
      final avgBpm = _accBpm / _count;
      final avgTemp = _accTemp / _count;

      final record = HistoryModel(
        date: DateTime.now(),
        bpm: avgBpm.round(),
        temperature: avgTemp,
      );
      LocalDB.insertHistory(record);

      debugPrint(
        '📦 [HIVE SAVED] Avg HR=${avgBpm.toStringAsFixed(1)}, Temp=${avgTemp.toStringAsFixed(1)}',
      );

      _accBpm = 0;
      _accTemp = 0;
      _count = 0;
      _lastSavedTime = now;
    }
  }

  // --------------------------------------------------------------------------
  // 📤 ส่งคำสั่งไปยังบอร์ด (RESET / DISCONNECT / PING)
  // --------------------------------------------------------------------------
  Future<void> sendCommand(String command) async {
    if (_cmdChar == null) {
      throw StateError('Command characteristic not found.');
    }
    final data = utf8.encode(command);
    await _cmdChar!.write(data, withoutResponse: true);
    debugPrint('📤 Sent command: $command');
  }

  // --------------------------------------------------------------------------
  // 🔌 ตัดการเชื่อมต่อ BLE
  // --------------------------------------------------------------------------
  Future<void> disconnect() async {
    try {
      await _notifyChar?.setNotifyValue(false);
    } catch (_) {}
    await _notifySub?.cancel();
    _notifySub = null;

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }

    _device = null;
    _notifyChar = null;
    _cmdChar = null;
    dataStream = null;
    _connected = false;
    debugPrint('🔌 BLE disconnected');
  }

  void _cancelScanSub() {
    _scanSub?.cancel();
    _scanSub = null;
  }
}
