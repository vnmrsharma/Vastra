import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/vastra_colors.dart';
import '../../widgets/pip.dart';
import '../../widgets/vastra_widgets.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final name = profile?.displayName.trim() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';

    return VastraPage(
      appBar: AppBar(
        backgroundColor: VastraColors.ivory.withValues(alpha: 0.88),
        titleSpacing: 20,
        title: const VastraLogo(height: 38),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Semantics(
              button: true,
              label: 'Your profile and settings',
              child: GestureDetector(
                onTap: () => context.push('/settings'),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: VastraColors.blush,
                  foregroundImage: profile?.tryOnPhotoUrl != null ? NetworkImage(profile!.tryOnPhotoUrl!) : null,
                  child: Text(
                    initial,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: VastraColors.burgundy,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: VastraColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.checkroom_outlined),
              selectedIcon: Icon(Icons.checkroom_rounded),
              label: 'Closet',
            ),
            NavigationDestination(
              icon: Icon(Icons.dry_cleaning_outlined),
              selectedIcon: Icon(Icons.dry_cleaning_rounded),
              label: 'Dress up',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Try on',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Looks',
            ),
          ],
        ),
      ),
      child: navigationShell,
    );
  }
}
