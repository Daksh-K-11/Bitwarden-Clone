import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation (phones) / navigation rail (tablets).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _destinations = [
    (Icons.lock_outline_rounded, Icons.lock_rounded, 'Vault'),
    (Icons.timer_outlined, Icons.timer_rounded, 'Codes'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Generator'),
    (Icons.health_and_safety_outlined, Icons.health_and_safety_rounded, 'Security'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.shield_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
