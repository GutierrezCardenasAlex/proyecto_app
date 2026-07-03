part of '../driver_home_page.dart';

class DriverAccountTab extends StatelessWidget {
  const DriverAccountTab({
    super.key,
    required this.fullName,
    required this.phone,
    this.onBack,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final String fullName;
  final String phone;
  final VoidCallback? onBack;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return _DriverAccountTab(
      fullName: fullName,
      phone: phone,
      onBack: onBack,
      onOpenProfile: onOpenProfile,
      onOpenNotifications: onOpenNotifications,
      onOpenSettings: onOpenSettings,
      onOpenHelp: onOpenHelp,
    );
  }
}
