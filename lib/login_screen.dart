import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  late final Box<UserModel> _userBox;
  late final Box _sessionBox;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<UserModel>('users');
    _sessionBox = Hive.box('session');
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final uname = _username.text.trim();
      final pwd = _password.text.trim();

      final user = _userBox.values.firstWhere(
        (u) => u.username == uname && u.password == pwd,
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

      if (user.username?.isEmpty ?? true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
        return;
      }

      await _sessionBox.put('currentUsername', user.username);

      messenger.showSnackBar(
        const SnackBar(content: Text('Signed in successfully')),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard', arguments: user);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  'SmartHealth',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 28),

                // Username
                TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: colorScheme.primary,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      _isLoading ? null : _doLogin(), // enter เพื่อ login
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.primary,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 22),

                // ปุ่ม Login
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _doLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // ปุ่มสมัครสมาชิก
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () =>
                            Navigator.pushReplacementNamed(context, '/signup'),
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
