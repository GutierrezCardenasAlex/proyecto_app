part of 'driver_home_page.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({
    super.key,
    required this.onMenuTap,
    required this.onOpenTab,
    required this.openOffersFromDrawer,
    required this.onOffersDrawerHandled,
  });

  final VoidCallback onMenuTap;
  final ValueChanged<int> onOpenTab;
  final bool openOffersFromDrawer;
  final VoidCallback onOffersDrawerHandled;

  @override
  Widget build(BuildContext context) {
    return _DriverDashboard(
      onMenuTap: onMenuTap,
      onOpenTab: onOpenTab,
      openOffersFromDrawer: openOffersFromDrawer,
      onOffersDrawerHandled: onOffersDrawerHandled,
    );
  }
}
