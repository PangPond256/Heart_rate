import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Box<UserModel> _userBox;
  String _username = '';
  UserModel? _user;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<UserModel>('users');
    _loadUser();
  }

  void _loadUser() {
    final session = Hive.box('session');
    _username = session.get('currentUsername', defaultValue: '');

    if (_username.isNotEmpty) {
      _user = _userBox.values.firstWhere(
        (u) => u.username == _username,
        orElse: () => UserModel(
          username: _username,
          password: '',
          name: '',
          age: 0,
          gender: '',
          weight: 0,
          height: 0,
        ),
      );
    }

    if (_user != null) {
      _nameController.text = _user!.name;
      _ageController.text = _user!.age > 0 ? _user!.age.toString() : '';
      _weightController.text = _user!.weight > 0
          ? _user!.weight.toStringAsFixed(1)
          : '';
      _heightController.text = _user!.height > 0
          ? _user!.height.toStringAsFixed(1)
          : '';
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;

    _user!
      ..name = _nameController.text.trim()
      ..age = int.tryParse(_ageController.text.trim()) ?? 0
      ..weight = double.tryParse(_weightController.text.trim()) ?? 0
      ..height = double.tryParse(_heightController.text.trim()) ?? 0;

    if (_user!.isInBox) {
      await _user!.save();
    } else {
      await _userBox.add(_user!);
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pop(ctx); // ปิด popup
            setState(() => _isEditing = false);
          });

          return Container(
            padding: const EdgeInsets.all(24),
            height: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF1E3A8A),
                  size: 60,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Profile Updated Successfully!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your changes have been saved.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // ✅ Drawer (Main Menu)
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

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('No user found')));
    }

    return Scaffold(
      drawer: _buildDrawer(context), // ✅ เพิ่ม Drawer เข้าไป
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            tooltip: _isEditing ? 'Cancel' : 'Edit Profile',
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isEditing ? _buildEditForm() : _buildProfileView(),
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: CircleAvatar(
            radius: 45,
            backgroundColor: Color(0xFF1E3A8A),
            child: Icon(Icons.person, color: Colors.white, size: 60),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            _user!.name.isNotEmpty ? _user!.name : _user!.username,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Profile Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const Divider(),
        _buildInfoRow('Username', _user!.username),
        _buildInfoRow('Full Name', _user!.name),
        _buildInfoRow('Age', _user!.age > 0 ? '${_user!.age}' : '-'),
        _buildInfoRow(
          'Weight',
          _user!.weight > 0 ? '${_user!.weight} kg' : '-',
        ),
        _buildInfoRow(
          'Height',
          _user!.height > 0 ? '${_user!.height} cm' : '-',
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _buildEditField('Full Name', _nameController),
        _buildEditField('Age', _ageController, type: TextInputType.number),
        _buildEditField(
          'Weight (kg)',
          _weightController,
          type: TextInputType.number,
        ),
        _buildEditField(
          'Height (cm)',
          _heightController,
          type: TextInputType.number,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saveProfile,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text(
            'Save Changes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
