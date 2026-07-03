part of '../driver_home_page.dart';

class DriverTripsTab extends StatelessWidget {
  const DriverTripsTab({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return _DriverTripsTab(onBack: onBack);
  }
}
