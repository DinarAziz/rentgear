import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../shared/profile_screen.dart';
import 'provider_equipment_screen.dart';
import 'provider_orders_screen.dart';
import 'provider_policy_screen.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => AdaptiveShell(
    selectedIndex: _index,
    onSelect: (i) => setState(() => _index = i),
    pages: const [
      ProviderOrdersScreen(),
      ProviderEquipmentScreen(),
      ProviderPolicyScreen(),
      ProfileScreen(),
    ],
    destinations: const [
      NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Pesanan'),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        label: 'Alat',
      ),
      NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Jaminan'),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
    ],
  );
}
