import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HeartBleService {
  static const String defaultDeviceName = 'HeartSense-ESP32';
  static const String defaultServiceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String defaultNotifyCharUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  HeartBleService({
    this.targetDeviceName = defaultDeviceName,
    this.serviceUuid = defaultServiceUuid,
    this.notifyCharUuid = defaultNotifyCharUuid,
    this.scanTimeout = const Duration(seconds: 8),
    this.connectTimeout = const Duration(seconds: 10),
  });

  final String targetDeviceName;
  final String serviceUuid;
  final String notifyCharUuid;

  final Duration scanTimeout;
  final Duration connectTimeout;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;
  Stream<(int bpm, double temp)>? dataStream;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;

  bool _connected = false;

  // ------------------------ Helper ------------------------
  bool _uuidEq(Guid guid, String uuidStr) =>
      guid.toString().toUpperCase() == uuidStr.toUpperCase();

  bool _advHasService(AdvertisementData adv, String svcUuid) {
    final target = svcUuid.toUpperCase();
    for (final u in adv.serviceUuids) {
      final s = u.toString().toUpperCase();
      if (s == target) return true;
    }
    return false;
  }

  // ------------------- Connect / Subscribe -------------------
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
            await _device!.connect(timeout: connectTimeout, autoConnect: false);
            _connected = true;

            await _discoverAndSubscribe();

            if (!completer.isCompleted) completer.complete();
            break;
          } catch (e) {
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

  Future<void> _discoverAndSubscribe() async {
    if (_device == null) {
      throw StateError('No device found to discover services');
    }

    final services = await _device!.discoverServices();

    BluetoothCharacteristic? notifyChar;
    for (final s in services) {
      if (_uuidEq(s.uuid, serviceUuid)) {
        for (final c in s.characteristics) {
          if (_uuidEq(c.uuid, notifyCharUuid) && c.properties.notify) {
            notifyChar = c;
            break;
          }
        }
      }
      if (notifyChar != null) break;
    }

    if (notifyChar == null) {
      throw StateError('Notify characteristic not found on device');
    }

    _notifyChar = notifyChar;
    await _notifyChar!.setNotifyValue(true);

    // ✅ ใช้ onValueReceived เพื่อรับค่าจริงแบบต่อเนื่อง
    final rawStream = _notifyChar!.onValueReceived;

    dataStream = rawStream.map<(int, double)>((bytes) {
      try {
        final line = utf8.decode(bytes).trim(); // เช่น "78,36.7"
        final parts = line.split(',');
        final bpm = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
        final temp = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 0.0;
        return (bpm, temp);
      } catch (_) {
        return (0, 0.0);
      }
    });

    _notifySub = rawStream.listen((_) {}, onError: (_) {});
  }

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
    dataStream = null;
    _connected = false;
  }

  void _cancelScanSub() {
    _scanSub?.cancel();
    _scanSub = null;
  }
}
