import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'glass_container.dart';
import 'package:emilekbul/services/haptic_service.dart';

/// Üst kontrol katmanındaki geri ve ana sayfa düğmeleri: cam (Liquid Glass benzeri) + %35 koyu katman.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? color;

  const AppBackButton({super.key, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return _NavigationButton(
      icon: Icons.arrow_back_ios_new_rounded,
      label: 'nav.back'.tr(),
      onTap: onTap ?? () => Navigator.pop(context),
      color: color,
    );
  }
}

class AppHomeButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;

  const AppHomeButton({super.key, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return _NavigationButton(
      icon: Icons.home_rounded,
      label: 'nav.home'.tr(),
      onTap: onTap,
      color: color,
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _NavigationButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          onTap();
        },
        child: GlassContainer(
          borderRadius: 14,
          opacity: 0.1,
          useBlur: true,
          scrim: true,
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: color ?? Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
