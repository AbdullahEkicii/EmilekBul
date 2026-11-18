import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import 'kategori_screen.dart';
import 'league_screen.dart';
import 'shop_screen.dart';
import 'welcome_screen.dart';

/// 4 sekmeli kalıcı ana uygulama kabuğu:
/// 0: Ana Sayfa (günlük hedef, seri, sandık, hızlı maç, görevler)
/// 1: Modlar & Kategoriler
/// 2: Lig & Sosyal (haftalık lig, arkadaşlar, turnuvalar)
/// 3: Mağaza & Profil
class MainShell extends StatefulWidget {
  final VoidCallback onStart;
  final Function(String category, String difficulty, int duration, {bool isDuel})
      onStartQuiz;
  final int initialIndex;

  const MainShell({
    super.key,
    required this.onStart,
    required this.onStartQuiz,
    this.initialIndex = 0,
  });

  /// Alt ağaçtaki herhangi bir widget'tan yeni sekme açar (yeni sayfa push etmeden).
  static bool selectTabOf(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<MainShellState>();
    if (state == null) return false;
    state.selectTab(index);
    return true;
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;
  late final Set<int> _mountedTabs;

  static const _tabNames = ['home', 'modes', 'league', 'shop'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _mountedTabs = {_currentIndex};
  }

  void selectTab(int index) {
    final clamped = index.clamp(0, 3);
    if (clamped == _currentIndex) return;
    HapticService.light();
    setState(() {
      _currentIndex = clamped;
      _mountedTabs.add(clamped);
    });
    try {
      AnalyticsService.logScreenView(screenName: 'tab_${_tabNames[clamped]}');
    } catch (_) {}
  }

  Widget _buildTab(int index) {
    if (!_mountedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return WelcomeScreen(
          onStart: () => selectTab(1),
          skipLoading: true,
        );
      case 1:
        return KategoriScreen(
          onStartQuiz: widget.onStartQuiz,
          onStart: () => selectTab(0),
          embedded: true,
        );
      case 2:
        return LeagueScreen(embedded: true);
      case 3:
        return ShopScreen(embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          selectTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.backgroundTop,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(4, _buildTab),
        ),
        bottomNavigationBar: FloatingGlassTabBar(
          selectedIndex: _currentIndex,
          onSelected: selectTab,
          items: [
            FloatingTabItemData(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'nav.home'.tr(),
            ),
            FloatingTabItemData(
              icon: Icons.grid_view_outlined,
              selectedIcon: Icons.grid_view_rounded,
              label: 'nav.modes'.tr(),
            ),
            FloatingTabItemData(
              icon: Icons.emoji_events_outlined,
              selectedIcon: Icons.emoji_events_rounded,
              label: 'nav.league'.tr(),
            ),
            FloatingTabItemData(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront_rounded,
              label: 'nav.shop'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}

class FloatingTabItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingTabItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Yeni nesil yüzen kapsül tabbar:
/// Arkasındaki kaydırılan öğeleri geçirir, yüksek sigma Gaussian bulanıklık ve
/// doygunluk/renk yayılımı (chromatic dispersion) matrisiyle yumuşak prizmatik ışık dağılımı üretir.
class FloatingGlassTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FloatingTabItemData> items;

  const FloatingGlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const radius = 34.0;

    final ImageFilter glassBlurFilter = ImageFilter.blur(
      sigmaX: 30,
      sigmaY: 22,
    );

    final Widget capsuleInterior = SizedBox(
      height: 68,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Katman 1: Bulanık arka planın %74'ünü geçiren ince yarı saydam taban
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: AppColors.backgroundTop.withValues(alpha: 0.26),
              ),
            ),
          ),
          // Katman 2: Kromatik renk dağılımı (additive prizmatik ışık kırılması)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.plus,
                  gradient: LinearGradient(
                    begin: const Alignment(-1.0, -0.7),
                    end: const Alignment(1.0, 0.7),
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.18),
                      const Color(0xFF818CF8).withValues(alpha: 0.14),
                      const Color(0xFFE879F9).withValues(alpha: 0.16),
                      const Color(0xFF2DD4BF).withValues(alpha: 0.12),
                      const Color(0xFFFBBF24).withValues(alpha: 0.18),
                    ],
                    stops: const [0.0, 0.26, 0.52, 0.76, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Katman 3: Mercek kenarı renk saçılması (sol-üst camgöbeği & sağ-alt mercan)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.screen,
                  gradient: RadialGradient(
                    center: const Alignment(-0.75, -0.6),
                    radius: 1.3,
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.screen,
                  gradient: RadialGradient(
                    center: const Alignment(0.75, 0.6),
                    radius: 1.3,
                    colors: [
                      const Color(0xFFFB7185).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Üst optik kristal ışık yansıması
          Positioned(
            top: 0,
            left: 28,
            right: 28,
            height: 1.2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.65),
                      const Color(0xFF7DD3FC).withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Alt ince prizmatik renk dağılımı hattı
          Positioned(
            bottom: 0,
            left: 36,
            right: 36,
            height: 1.0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.0),
                      const Color(0xFF38BDF8).withValues(alpha: 0.42),
                      const Color(0xFFA78BFA).withValues(alpha: 0.36),
                      const Color(0xFFFBBF24).withValues(alpha: 0.42),
                      const Color(0xFFFBBF24).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Dış cam çerçeve hattı
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1.15,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isSelected = i == selectedIndex;
                return Expanded(
                  child: _FloatingTabButton(
                    item: item,
                    selected: isSelected,
                    onTap: () => onSelected(i),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF061224).withValues(alpha: 0.36),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.14),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: glassBlurFilter,
            child: capsuleInterior,
          ),
        ),
      ),
    );
  }
}

class _FloatingTabButton extends StatelessWidget {
  final FloatingTabItemData item;
  final bool selected;
  final VoidCallback onTap;

  const _FloatingTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.30),
                    AppColors.accentSecondary.withValues(alpha: 0.18),
                  ],
                )
              : null,
          border: selected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                  width: 0.9,
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 0.96,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary.withValues(alpha: 0.82),
                  fontSize: 10.5,
                  letterSpacing: 0.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
