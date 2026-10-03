import 'package:flutter/material.dart';

import 'theme.dart';

/// Tiga kelas layar. Batas mengikuti Material 3 window size classes:
/// HP < 600, tablet < 1024, sisanya desktop/laptop.
enum FormFactor {
  phone,
  tablet,
  desktop;

  static FormFactor fromWidth(double width) => switch (width) {
    < 600 => phone,
    < 1024 => tablet,
    _ => desktop,
  };

  static FormFactor of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}

/// Lebar maksimum konten baca (detail, form) supaya baris tidak terlalu panjang.
const double readableWidth = 760;

/// Padding horizontal yang memusatkan konten selebar [maxWidth]. Area
/// kosong di kiri-kanan tetap bagian dari scroll view, jadi roda mouse
/// di sisi kosong tetap menggulir halaman.
EdgeInsets centeredPadding(
  double available, {
  double maxWidth = readableWidth,
  double vertical = 16,
  double bottom = 16,
}) {
  final side = available > maxWidth + 32 ? (available - maxWidth) / 2 : 16.0;
  return EdgeInsets.fromLTRB(side, vertical, side, bottom);
}

/// [ListView] yang isinya dibatasi selebar [maxWidth] di layar lebar.
class ReadableListView extends StatelessWidget {
  const ReadableListView({
    super.key,
    required this.children,
    this.maxWidth = readableWidth,
    this.bottomPadding = 16,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  final List<Widget> children;
  final double maxWidth;
  final double bottomPadding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ListView(
      padding: centeredPadding(
        c.maxWidth,
        maxWidth: maxWidth,
        bottom: bottomPadding,
      ),
      keyboardDismissBehavior: keyboardDismissBehavior,
      children: children,
    ),
  );
}

/// Membatasi lebar satu widget (mis. tombol aksi di bawah layar) dan
/// memusatkannya.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = readableWidth,
  });

  final Widget child;
  final double maxWidth;

  // heightFactor 1: setinggi isinya saja, juga saat dipasang sebagai
  // bottomNavigationBar yang tingginya tidak dibatasi.
  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Daftar kartu yang berubah jadi beberapa kolom saat layar melebar:
/// 1 kolom di HP, 2 di tablet, 3 di desktop (mengikuti [minItemWidth]).
/// Tinggi kartu boleh berbeda; tiap baris setinggi kartu tertingginya.
class ResponsiveCardList extends StatelessWidget {
  const ResponsiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 340,
    this.maxColumns = 3,
    this.maxWidth = 1280,
    this.bottomPadding = 16,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minItemWidth;
  final int maxColumns;
  final double maxWidth;
  final double bottomPadding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final padding = centeredPadding(
        c.maxWidth,
        maxWidth: maxWidth,
        bottom: bottomPadding,
      );
      final inner = c.maxWidth - padding.horizontal;
      final columns = ((inner + _gap) / (minItemWidth + _gap)).floor().clamp(
        1,
        maxColumns,
      );
      final rows = (itemCount / columns).ceil();
      return ListView.separated(
        padding: padding,
        keyboardDismissBehavior: keyboardDismissBehavior,
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: _gap),
        itemBuilder: (context, row) {
          if (columns == 1) return itemBuilder(context, row);
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: row * columns + col < itemCount
                        ? itemBuilder(context, row * columns + col)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

/// Kerangka menu utama tiap role. HP: bar navigasi bawah. Tablet:
/// rail ikon di kiri. Desktop: sidebar lebar dengan logo dan label.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
    required this.pages,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<NavigationDestination> destinations;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(index: selectedIndex, children: pages);
    final form = FormFactor.of(context);
    if (form == FormFactor.phone) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: destinations,
        ),
      );
    }

    final extended = form == FormFactor.desktop;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: extended ? null : NavigationRailLabelType.all,
            backgroundColor: scheme.surfaceContainerLow,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _Brand(extended: extended),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(
      Icons.landscape_rounded,
      color: AppColors.forest,
      size: 32,
    );
    if (!extended) return icon;
    return const SizedBox(
      width: 188,
      child: Row(
        children: [
          icon,
          SizedBox(width: 10),
          Text(
            'RentGear',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}
