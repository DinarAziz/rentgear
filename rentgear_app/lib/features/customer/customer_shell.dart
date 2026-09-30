import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../shared/profile_screen.dart';
import 'catalog_screen.dart';
import 'my_rentals_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => AdaptiveShell(
    selectedIndex: _index,
    onSelect: (i) => setState(() => _index = i),
    pages: const [CatalogScreen(), MyRentalsScreen(), ProfileScreen()],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        label: 'Katalog',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Sewa Saya',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
    ],
  );
}
