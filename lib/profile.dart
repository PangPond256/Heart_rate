import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'models/user_model.dart';
import 'models/history_model.dart';
import 'drawer.dart';
import 'ble/ble_manager.dart';
import 'utils/permissions.dart'; // ✅ เพิ่มตรงนี้

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  File? _profileImage;
  int? latestBpm;
  double? latestTemp;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLatestData();
    _loadSavedImage();
  }

  Future<void> _loadUserData() async {
    final box = Hive.box<UserModel>('users');
    if (box.isNotEmpty && mounted) {
      setState(() => _user = box.getAt(0));
    }
  }

  Future<void> _loadLatestData() async {
    final box = Hive.box<HistoryModel>('history');
    if (box.isNotEmpty && mounted) {
      final latest = box.values.last;
      setState(() {
        latestBpm = latest.bpm;
        latestTemp = latest.temperature;
      });
    }
  }

  Future<void> _loadSavedImage() async {
    final box = await Hive.openBox('settings');
    final path = box.get('profileImage');
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _profileImage = File(path));
    }
  }

  /// ✅ ฟังก์ชันเลือกรูปจากแกลเลอรี (รองรับ Android 13+)
  Future<void> _pickImage() async {
    final granted =
        await ensureGalleryPermission(); // ✅ ใช้จาก permissions.dart
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access gallery.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null && mounted) {
      final box = await Hive.openBox('settings');
      await box.put('profileImage', picked.path);
      setState(() => _profileImage = File(picked.path));
      debugPrint('📸 Image saved: ${picked.path}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0.5,
      ),
      drawer: const MainDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: colorScheme.primary,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _pickImage,
                child: Text(
                  'Change Photo',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _user?.name ?? 'Guest User',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 30),
              Divider(
                thickness: 1.2,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),

              // ❤️ HEALTH DATA
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHealthCard(
                      icon: Icons.favorite,
                      color: Colors.redAccent,
                      label: 'Heart Rate',
                      value: latestBpm != null ? '$latestBpm bpm' : '—',
                      theme: theme,
                    ),
                    _buildHealthCard(
                      icon: Icons.thermostat,
                      color: Colors.orangeAccent,
                      label: 'Temperature',
                      value: latestTemp != null
                          ? '${latestTemp!.toStringAsFixed(1)} °C'
                          : '—',
                      theme: theme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 🧍 PERSONAL INFO
              _buildInfoSection(theme),

              const SizedBox(height: 35),

              // 🔗 BLE BUTTON
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await BleManager().disconnect();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('BLE connection reset.')),
                    );
                  } catch (e) {
                    debugPrint('BLE disconnect error: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to reset BLE connection.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bluetooth_connected),
                label: const Text('Manage BLE Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ✏️ EDIT BUTTON
              OutlinedButton.icon(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.pushNamed(context, '/edit_profile');
                },
                icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                label: Text(
                  'Edit Profile',
                  style: TextStyle(color: colorScheme.primary),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ข้อมูลส่วนตัว
  Widget _buildInfoSection(ThemeData theme) {
    final textColor = theme.colorScheme.onSurface;
    final info = [
      {
        'label': 'Age',
        'value': _user?.age != null ? _user!.age.toString() : '—',
      },
      {'label': 'Gender', 'value': _user?.gender ?? '—'},
      {
        'label': 'Height',
        'value': _user?.height != null ? '${_user!.height} cm' : '—',
      },
      {
        'label': 'Weight',
        'value': _user?.weight != null ? '${_user!.weight} kg' : '—',
      },
    ];

    return Column(
      children: info
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label']!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    item['value']!,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ✅ การ์ดสุขภาพ
  Widget _buildHealthCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      width: 150,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: theme.hintColor)),
        ],
      ),
    );
  }
}
