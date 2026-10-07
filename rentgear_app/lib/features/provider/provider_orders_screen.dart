import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../customer/my_rentals_screen.dart';

class ProviderOrdersScreen extends StatelessWidget {
  const ProviderOrdersScreen({super.key});

  static const _needsAction = {
    RentalStatus.pendingConfirmation,
    RentalStatus.paymentReview,
    RentalStatus.paid,
    RentalStatus.pickedUp,
    RentalStatus.overdue,
    RentalStatus.returned,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final providerId = state.currentUser.providerId!;
    return AsyncView<(ProviderProfile, List<Rental>)>(
      load: () async => (await state.repo.provider(providerId), await state.repo.providerRentals(providerId)),
      builder: (context, data) {
        final (profile, rentals) = data;
        List<Rental> where(bool Function(Rental) test) => rentals.where(test).toList();
        final active = where((r) => _needsAction.contains(r.status));
        final waiting = where((r) => r.status == RentalStatus.awaitingPayment);
        final history = where(
          (r) => !_needsAction.contains(r.status) && r.status != RentalStatus.awaitingPayment,
        );

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(profile.businessName),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Aksi (${active.length})'),
                  Tab(text: 'Belum bayar (${waiting.length})'),
                  const Tab(text: 'Riwayat'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (profile.status != ProviderStatus.verified)
                  MaterialBanner(
                    content: Text(
                      'Status toko: ${profile.status.label}. '
                      'Alat Anda belum tampil di katalog sampai admin memverifikasi.',
                    ),
                    leading: const Icon(Icons.hourglass_top),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      RentalList(rentals: active, showCustomer: true),
                      RentalList(rentals: waiting, showCustomer: true),
                      RentalList(rentals: history, showCustomer: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
