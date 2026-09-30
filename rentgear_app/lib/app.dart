import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'domain/models.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/customer/customer_shell.dart';
import 'features/provider/provider_shell.dart';
import 'state/app_state.dart';

class RentGearApp extends StatefulWidget {
  const RentGearApp({super.key});

  @override
  State<RentGearApp> createState() => _RentGearAppState();
}

class _RentGearAppState extends State<RentGearApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Job status otomatis ikut jalan saat aplikasi dibuka lagi dari background.
    _lifecycle = AppLifecycleListener(onResume: () => context.read<AppState>().refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<AppState, UserRole?>((s) => s.user?.role);
    return MaterialApp(
      title: 'RentGear',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: switch (role) {
        null => const LoginScreen(),
        UserRole.customer => const CustomerShell(),
        UserRole.provider => const ProviderShell(),
        UserRole.admin => const AdminShell(),
      },
    );
  }
}
