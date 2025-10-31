import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _gender = 'Male';

  late final Box<UserModel> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<UserModel>('users');
    _loadUserData();
  }

  // ✅ โหลดข้อมูลจาก Hive (ป้องกัน null ปลอดภัย)
  void _loadUserData() {
    if (_userBox.isNotEmpty) {
      final user = _userBox.getAt(0);
      if (user != null) {
        _name.text = user.name ?? '';
        _age.text = user.age != null ? user.age.toString() : '';
        _gender = user.gender ?? 'Male';
        _weight.text = user.weight != null ? user.weight.toString() : '';
        _height.text = user.height != null ? user.height.toString() : '';
      }
    }
  }

  // ✅ บันทึกการเปลี่ยนแปลง
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _userBox.getAt(0);
    if (user != null) {
      final updatedUser = UserModel(
        username: user.username,
        password: user.password,
        name: _name.text.trim(),
        age: int.tryParse(_age.text),
        gender: _gender,
        weight: double.tryParse(_weight.text),
        height: double.tryParse(_height.text),
      );

      await _userBox.putAt(0, updatedUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Invalid age';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
