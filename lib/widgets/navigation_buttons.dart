import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_container.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? color;

  const AppBackButton({super.key, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return _NavigationButton(
      icon: Icons.arrow_back_ios_new_rounded,
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
      onTap: onTap,
      color: color,
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _NavigationButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: GlassContainer(
        borderRadius: 14,
        opacity: 0.1,
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
