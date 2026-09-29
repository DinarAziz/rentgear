import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local_repository.dart';
import 'data/local_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('id_ID');

  final repo = LocalRentGearRepository.open(store: await LocalStore.open());
  final state = AppState(repo);
  await state.bootstrap();

  runApp(ChangeNotifierProvider.value(value: state, child: const RentGearApp()));
}
