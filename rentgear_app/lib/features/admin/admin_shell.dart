import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/fines.dart';
import '../../domain/guarantee.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/verification_widgets.dart';
import '../customer/my_rentals_screen.dart';
import '../rental/rental_detail_screen.dart';
import '../shared/profile_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_gear_status_screen.dart';
import 'admin_store_review_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => AdaptiveShell(
    selectedIndex: _index,
    onSelect: (i) => setState(() => _index = i),
    pages: [
      AdminDashboardScreen(
        onOpenProviders: () => setState(() => _index = 1),
        onOpenRentals: () => setState(() => _index = 3),
      ),
      const AdminProvidersScreen(),
      const AdminCustomersScreen(),
      const AdminRentalsScreen(),
      const ProfileScreen(),
    ],
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        label: 'Penyedia',
      ),
      NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Penyewa'),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Transaksi',
      ),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
    ],
  );
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onOpenProviders,
    required this.onOpenRentals,
  });

  final VoidCallback onOpenProviders;
  final VoidCallback onOpenRentals;

  /// Jumlah transaksi terbaru yang tampil di dashboard.
  static const _recentCount = 6;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.manage_search),
            label: const Text('Jejak audit'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AdminAuditScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView<(List<Rental>, List<ProviderProfile>)>(
        load: () async =>
            (await state.repo.allRentals(), await state.repo.providers()),
        builder: (context, data) {
          final (rentals, providers) = data;
          final active = rentals.where(
            (r) => const {
              RentalStatus.pendingConfirmation,
              RentalStatus.awaitingPayment,
              RentalStatus.paymentReview,
              RentalStatus.paid,
              RentalStatus.pickedUp,
              RentalStatus.overdue,
              RentalStatus.returned,
            }.contains(r.status),
          );
          final held = rentals
              .expand((r) => r.guarantees)
              .where((g) => g.status == GuaranteeStatus.held)
              .length;
          final revenue = rentals
              .where((r) => r.status == RentalStatus.completed)
              .fold<double>(0, (sum, r) => sum + r.subtotal);
          final pending = providers
              .where((p) => p.status == ProviderStatus.pending)
              .length;
          final fineReviews = rentals
              .where((r) => r.damageReview == DamageReview.pending)
              .toList();
          final mismatchReports = rentals
              .where((r) => r.mismatch == MismatchStatus.pending)
              .toList();
          final rentedUnits = rentals
              .where((r) => r.status == RentalStatus.pickedUp || r.status == RentalStatus.overdue)
              .fold<int>(0, (sum, r) => sum + r.qty);

          final stats = [
            ('Total transaksi', '${rentals.length}', Icons.receipt_long),
            ('Transaksi aktif', '${active.length}', Icons.sync),
            ('Jaminan dipegang', '$held dokumen', Icons.badge),
            ('Penyedia menunggu', '$pending', Icons.hourglass_top),
            ('Denda ditinjau', '${fineReviews.length}', Icons.gavel_outlined),
            ('Laporan barang', '${mismatchReports.length}', Icons.report_problem_outlined),
            ('Unit sedang disewa', '$rentedUnits', Icons.backpack_outlined),
            ('Nilai sewa selesai', rupiah(revenue), Icons.payments_outlined),
          ];
          // Card height follows the system font scale so large text does not overflow.
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          // HP 2 kolom, tablet 3, desktop semua statistik dalam satu baris.
          final columns = switch (FormFactor.of(context)) {
            FormFactor.phone => 2,
            FormFactor.tablet => 3,
            FormFactor.desktop => stats.length,
          };
          Widget rentalCards(Iterable<Rental> items) => _CardWrap(
            children: [
              for (final r in items)
                RentalCard(
                  rental: r,
                  showCustomer: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RentalDetailScreen(rentalId: r.id),
                    ),
                  ),
                ),
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 56 + 72 * textScale,
                ),
                children: [
                  for (final (label, value, icon) in stats)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              icon,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SectionTitle('Perlu tindakan'),
              if (pending == 0 && fineReviews.isEmpty && mismatchReports.isEmpty)
                const Text(
                  'Tidak ada yang menunggu keputusan admin.',
                  style: TextStyle(color: Colors.black54),
                ),
              if (pending > 0)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: Text('$pending penyedia menunggu verifikasi'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenProviders,
                  ),
                ),
              if (fineReviews.isNotEmpty) ...[
                if (pending > 0) const SizedBox(height: 10),
                const Text(
                  'Denda kerusakan menunggu keputusan:',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                rentalCards(fineReviews),
              ],
              if (mismatchReports.isNotEmpty) ...[
                if (pending > 0 || fineReviews.isNotEmpty) const SizedBox(height: 10),
                const Text(
                  'Laporan barang tidak sesuai menunggu keputusan:',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                rentalCards(mismatchReports),
              ],
              const SectionTitle('Stok'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Status alat hari ini'),
                  subtitle: const Text('Unit yang disewa, dipesan, dan tersedia di tiap toko'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AdminGearStatusScreen()),
                  ),
                ),
              ),
              SectionTitle(
                'Transaksi terbaru',
                trailing: TextButton(
                  onPressed: onOpenRentals,
                  child: const Text('Lihat semua'),
                ),
              ),
              if (rentals.isEmpty)
                const Text(
                  'Belum ada transaksi.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                rentalCards(rentals.take(_recentCount)),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu berjajar 1 sampai 3 kolom di dalam halaman yang sudah bisa digulir.
class _CardWrap extends StatelessWidget {
  const _CardWrap({required this.children});

  final List<Widget> children;

  static const double _gap = 10;
  static const double _minWidth = 340;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = ((c.maxWidth + _gap) / (_minWidth + _gap)).floor().clamp(
        1,
        3,
      );
      final width = (c.maxWidth - _gap * (columns - 1)) / columns;
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class AdminProvidersScreen extends StatelessWidget {
  const AdminProvidersScreen({super.key});

  void _review(BuildContext context, ProviderProfile p) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => AdminStoreReviewScreen(providerId: p.id)),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Penyedia')),
      body: AsyncView<List<ProviderProfile>>(
        load: state.repo.providers,
        builder: (context, providers) => ResponsiveCardList(
          itemCount: providers.length,
          itemBuilder: (context, i) {
            final p = providers[i];
            return FadeSlideIn(
              delay: FadeSlideIn.stagger(i),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.businessName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          StatusCrossfade(
                            value: p.status,
                            child: Pill(p.status.label, color: providerStatusColor(p.status)),
                          ),
                        ],
                      ),
                      Text(
                        p.address,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Jaminan: ${p.policy.acceptedTypes.map((t) => t.label).join(', ')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      // Toko lama sudah terverifikasi sebelum ada dokumen, jadi tidak diberi catatan.
                      if (p.documentsSubmitted || p.status != ProviderStatus.verified) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.documentsSubmitted ? 'Dokumen verifikasi sudah dikirim' : 'Dokumen verifikasi belum dikirim',
                          style: TextStyle(
                            fontSize: 13,
                            color: p.documentsSubmitted ? Colors.black87 : Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: p.status == ProviderStatus.pending && p.documentsSubmitted
                            ? FilledButton.icon(
                                onPressed: () => _review(context, p),
                                icon: const Icon(Icons.fact_check_outlined),
                                label: const Text('Periksa dokumen'),
                              )
                            : OutlinedButton(
                                onPressed: () => _review(context, p),
                                child: const Text('Lihat detail'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AdminRentalsScreen extends StatelessWidget {
  const AdminRentalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Semua Transaksi')),
      body: AsyncView<List<Rental>>(
        load: state.repo.allRentals,
        builder: (context, rentals) =>
            RentalList(rentals: rentals, showCustomer: true),
      ),
    );
  }
}
