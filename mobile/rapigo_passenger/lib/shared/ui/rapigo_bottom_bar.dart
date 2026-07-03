import 'package:flutter/material.dart';

class RapigoBottomBar extends StatelessWidget {
  const RapigoBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavigationDestination> items;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      animationDuration: const Duration(milliseconds: 280),
      destinations: items,
    );
  }
}
