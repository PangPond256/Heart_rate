import 'package:hive/hive.dart';

part 'history_model.g.dart'; // ← สำคัญมาก ต้องตรงชื่อไฟล์

@HiveType(typeId: 1) // typeId ต้องไม่ซ้ำกับ UserModel (ที่ใช้ 0)
class HistoryModel extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  int bpm;

  @HiveField(2)
  double temperature;

  HistoryModel({
    required this.date,
    required this.bpm,
    required this.temperature,
  });
}
