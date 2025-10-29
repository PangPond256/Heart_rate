import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/user_model.dart';
import 'models/history_model.dart';
import 'profile.dart';
import 'login_screen.dart';
import 'drawer.dart';
import 'summary_screen.dart'; // ✅ เพิ่มหน้า Summary แทน Measurement

class SettingsScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final box = await Hive.openBox('settings');
    if (mounted) {
      setState(() {
        _isDark = box.get('darkMode', defaultValue: false);
      });
    }
  }

  Future<void> _toggleTheme(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = await Hive.openBox('settings');
    await box.put('darkMode', value);

    if (!mounted) return;
    setState(() => _isDark = value);
    widget.onThemeChanged?.call(value);

    messenger.showSnackBar(
      SnackBar(
        content: Text(value ? 'Dark Mode enabled' : 'Light Mode enabled'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'This will permanently delete all measurement history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final messenger = ScaffoldMessenger.of(context);
      final box = Hive.box<HistoryModel>('history');
      await box.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('All history cleared')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Do you want to sign out from HeartSense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final session = Hive.box('session');
      await session.delete('currentUsername');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.person,
            title: 'Edit Profile',
            subtitle: 'Update your name, weight, or height',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          _tile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          _tile(
            icon: Icons.logout,
            title: 'Log Out',
            subtitle: 'Sign out from this device',
            iconColor: Colors.redAccent,
            onTap: () => _logout(context),
          ),
          const Divider(height: 32),

          const Text(
            'App',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(
              'Dark Mode',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            value: _isDark,
            onChanged: _toggleTheme,
            secondary: const Icon(
              Icons.brightness_6_outlined,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const Divider(height: 32),

          const Text(
            'Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.monitor_heart_rounded,
            title: 'Health Summary',
            subtitle: 'View daily and weekly health analysis',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SummaryScreen()),
              );
            },
          ),
          _tile(
            icon: Icons.delete_outline,
            title: 'Clear History',
            subtitle: 'Remove all saved heart rate records',
            onTap: _clearHistory,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = const Color(0xFF1E3A8A),
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ----------------------------------------------------------
// ✅ Change Password Screen (คงไว้เหมือนเดิม)
// ----------------------------------------------------------

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final session = Hive.box('session');
    final uname = session.get('currentUsername');
    final users = Hive.box<UserModel>('users');

    final user = users.values.firstWhere(
      (u) => u.username == uname,
      orElse: () => UserModel(
        username: '',
        password: '',
        name: '',
        age: 0,
        gender: '',
        weight: 0,
        height: 0,
      ),
    );

    if (user.username.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('User not found')));
      return;
    }

    if (user.password != _oldPwd.text.trim()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Old password is incorrect')),
      );
      return;
    }

    if (_newPwd.text != _confirmPwd.text) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // ✅ Update new password
    user.password = _newPwd.text.trim();
    await user.save();

    messenger.showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _oldPwd,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Old Password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPwd,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPwd,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.lock, color: Colors.white),
                label: const Text(
                  'Save Password',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 30,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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
