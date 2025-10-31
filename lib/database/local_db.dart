import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_model.dart'; // ✅ ตรวจสอบ path ให้ตรงกับโครงสร้างโปรเจ็กต์ของคุณ

class LocalDB {
  static const _boxName = 'historyBox';
  static Box<HistoryModel>? _box;

  // ✅ เปิดกล่อง Hive
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HistoryModelAdapter());
    }
    _box ??= await Hive.openBox<HistoryModel>(_boxName);
  }

  // ✅ เพิ่มข้อมูลใหม่
  static Future<void> insertHistory(HistoryModel record) async {
    await _box?.add(record);
  }

  // ✅ ดึงข้อมูลทั้งหมด
  static List<HistoryModel> getAll() {
    return _box?.values.toList() ?? [];
  }

  // ✅ ลบข้อมูลทั้งหมด
  static Future<void> clearAll() async {
    await _box?.clear();
  }

  // ✅ Export ข้อมูลทั้งหมดใน Hive เป็นไฟล์ CSV
  static Future<void> exportDataToCSV(BuildContext context) async {
    try {
      final box = _box ?? await Hive.openBox<HistoryModel>(_boxName);

      if (box.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No data available to export.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // สร้าง header
      final List<List<dynamic>> rows = [
        ['Date', 'Heart Rate (bpm)', 'Temperature (°C)'],
      ];

      // เพิ่มข้อมูลแต่ละ record
      for (final record in box.values) {
        rows.add([record.date.toString(), record.bpm, record.temperature]);
      }

      // แปลงข้อมูลเป็น CSV string
      final csvData = const ListToCsvConverter().convert(rows);

      // สร้างไฟล์ใน directory ของแอป
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/health_data.csv');
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Data exported successfully: ${file.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error exporting data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to export data.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
