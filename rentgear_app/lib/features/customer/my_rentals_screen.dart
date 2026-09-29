import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../rental/rental_detail_screen.dart';

class MyRentalsScreen extends StatelessWidget {
  const MyRentalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sewa Saya')),
      body: AsyncView<List<Rental>>(
        load: () => state.repo.customerRentals(state.currentUser.id),
        builder: (context, rentals) => RentalList(rentals: rentals),
      ),
    );
  }
}

class RentalList extends StatelessWidget {
  const RentalList({
    super.key,
    required this.rentals,
    this.showCustomer = false,
  });

  final List<Rental> rentals;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) => rentals.isEmpty
      ? const EmptyState(
          icon: Icons.inbox_outlined,
          message: 'Belum ada transaksi.',
        )
      : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rentals.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => FadeSlideIn(
            delay: FadeSlideIn.stagger(i),
            child: RentalCard(
              rental: rentals[i],
              showCustomer: showCustomer,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => RentalDetailScreen(rentalId: rentals[i].id),
                ),
              ),
            ),
          ),
        );
}
