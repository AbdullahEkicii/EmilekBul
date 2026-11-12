import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_categories.dart';
import '../main.dart';
import '../services/analytics_service.dart';
import '../services/haptic_service.dart';
import '../services/whats_new_service.dart';

/// İlk açılış: iki dokunmalı adım (günlük hedef, ilgi alanı) ve ardından
/// kısa, kolay bir ilk quiz. Pasif slayt yok; oyuncu ilk turu hemen oynar.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _goalOptions = [1, 3, 5];
  static const _accent = Color(0xFF6366F1);
  static const _accentEnd = Color(0xFFA855F7);
  static const _background = Color(0xFF090D16);

  int _step = 0;
  int _goal = 3;
  int _interestIndex = 0;
  bool _saving = false;

  Future<void> _finish({required bool startTour}) async {
    if (_saving) return;
    _saving = true;
    HapticService.medium();
    AnalyticsService.logFirstSession('onboarding_done');
    WhatsNewService.markCurrentSeen();

    final interest = AppCategories.categories[_interestIndex].name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding_v3', true);
      await prefs.setBool('has_seen_onboarding_v2', true);
      await prefs.setInt('user_daily_goal', _goal);
      await prefs.setString('onboarding_interest', interest);
    } catch (e) {
      debugPrint('Onboarding pref save error: $e');
    }

    if (!mounted) return;
    final Widget next = startTour
        ? QuizFlow(
            initialCategory: interest,
            initialDifficulty: 'Kolay',
            initialDuration: 25,
            isOnboarding: true,
          )
        : const QuizFlow();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _next() {
    HapticService.light();
    if (_step == 0) {
      AnalyticsService.logFirstSession('onboarding_goal_$_goal');
      setState(() => _step = 1);
    } else {
      AnalyticsService.logFirstSession('onboarding_interest_set');
      _finish(startTour: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == 1;
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            left: -60,
            child: _glow(_accent, 260),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: _glow(const Color(0xFFFF9F43), 280),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height * 0.6,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _step == 0 ? _buildGoalStep() : _buildInterestStep(),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      _buildDots(),
                      const SizedBox(height: 24),
                      _buildPrimaryButton(isLast),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.22), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, _accentEnd]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'app_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => _finish(startTour: false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white60,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(
              'onboarding.btn_skip'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return Column(
      children: [
        _buildStepTitle(
          title: 'onboarding.goal_title'.tr(),
          subtitle: 'onboarding.goal_sub'.tr(),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            for (final n in _goalOptions) ...[
              Expanded(child: _buildGoalCard(n)),
              if (n != _goalOptions.last) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGoalCard(int count) {
    final selected = _goal == count;
    return GestureDetector(
      onTap: () {
        HapticService.light();
        setState(() => _goal = count);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'onboarding.goal_option'.tr(namedArgs: {'count': '$count'}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestStep() {
    return Column(
      children: [
        _buildStepTitle(
          title: 'onboarding.interest_title'.tr(),
          subtitle: 'onboarding.interest_sub'.tr(),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < AppCategories.categories.length; i++)
              _buildInterestChip(i),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestChip(int index) {
    final item = AppCategories.categories[index];
    final selected = _interestIndex == index;
    return GestureDetector(
      onTap: () {
        HapticService.light();
        setState(() => _interestIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? item.color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? item.color : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 18, color: selected ? item.color : Colors.white60),
            const SizedBox(width: 6),
            Text(
              item.key.tr(),
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTitle({required String title, required String subtitle}) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            color: isActive ? _accent : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildPrimaryButton(bool isLast) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [_accent, _accentEnd]),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'onboarding.btn_tour'.tr() : 'onboarding.btn_next'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
