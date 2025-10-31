import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String? username;

  @HiveField(1)
  String? password;

  @HiveField(2)
  String? name;

  @HiveField(3)
  int? age;

  @HiveField(4)
  String? gender;

  @HiveField(5)
  double? weight;

  @HiveField(6)
  double? height;

  UserModel({
    this.username,
    this.password,
    this.name,
    this.age,
    this.gender,
    this.weight,
    this.height,
  });
}
