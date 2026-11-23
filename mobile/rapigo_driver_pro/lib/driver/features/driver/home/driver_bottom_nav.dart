part of 'driver_home_page.dart';

class DriverBottomNav extends StatelessWidget {
  const DriverBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    // Keep the existing shell indices and persisted navigation destinations.
    const destinations = [0, 2, 3, 4];
    final selected = destinations.indexOf(currentIndex);
    return Material(
      color: palette.backgroundBase,
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarTheme.of(context).copyWith(
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? palette.accentYellow
                    : palette.textMuted,
                size: 24,
              ),
            ),
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: palette.backgroundBase,
            indicatorColor: palette.accentYellow.withValues(alpha: 0.12),
            selectedIndex: selected < 0 ? 3 : selected,
            onDestinationSelected: (index) => onTap(destinations[index]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Viajes',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Pedidos',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
