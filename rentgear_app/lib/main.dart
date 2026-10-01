import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/http_repository.dart';
import 'data/local_repository.dart';
import 'data/local_store.dart';
import 'data/repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('id_ID');

  // Dengan `--dart-define=API_URL=...` data diambil dari server Laravel;
  // tanpa itu aplikasi berjalan mandiri dengan data di perangkat.
  final RentGearRepository repo = apiUrl.isEmpty
      ? LocalRentGearRepository.open(store: await LocalStore.open())
      : HttpRentGearRepository(baseUrl: apiUrl, tokens: await PrefsTokenStore.open());
  final state = AppState(repo);
  await state.bootstrap();

  runApp(ChangeNotifierProvider.value(value: state, child: const RentGearApp()));
}
