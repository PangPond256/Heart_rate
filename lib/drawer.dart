import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Drawer หลักที่ใช้ในทุกหน้า
class MainDrawer extends StatelessWidget {
  final Function(String route)? onSelect;

  const MainDrawer({super.key, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E3A8A);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF1E3A8A);

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Main Menu",
                style: TextStyle(
                  fontSize: 18,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              // Dashboard
              _drawerItem(
                context,
                icon: LucideIcons.layoutDashboard,
                title: "Dashboard",
                route: '/dashboard',
                iconColor: iconColor,
                textColor: textColor,
              ),

              // ✅ History (แก้แล้วให้ทำงานได้แน่นอน)
              _drawerItem(
                context,
                icon: LucideIcons.activity,
                title: "History",
                route: '/history',
                iconColor: iconColor,
                textColor: textColor,
              ),

              // Measurement
              _drawerItem(
                context,
                icon: LucideIcons.heart,
                title: "Measurement",
                route: '/measurement',
                iconColor: iconColor,
                textColor: textColor,
              ),

              // Profile
              _drawerItem(
                context,
                icon: LucideIcons.user,
                title: "Profile",
                route: '/profile',
                iconColor: iconColor,
                textColor: textColor,
              ),

              // Settings
              _drawerItem(
                context,
                icon: LucideIcons.settings,
                title: "Settings",
                route: '/settings',
                iconColor: iconColor,
                textColor: textColor,
              ),

              const Spacer(),

              // ปุ่มปิด Drawer
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

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Color iconColor,
    required Color textColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(fontSize: 16, color: textColor)),
      onTap: () {
        Navigator.pop(context); // ปิด Drawer ก่อน
        Future.delayed(const Duration(milliseconds: 200), () {
          Navigator.pushNamed(context, route);
        });
      },
    );
  }
}
