import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../screens/basari_hesapla_screen.dart';
import '../../../screens/kategori_screen.dart';
import '../../../screens/main_shell.dart';
import '../../../screens/tier_list_screen.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_utils.dart';
import '../../../widgets/glass_alert_dialog.dart';
import '../../../widgets/glass_container.dart';

class TierListButton extends StatelessWidget {
  final VoidCallback onPressed;
  const TierListButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    return GlassContainer(
      opacity: 0.1,
      blur: 10,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticService.light();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PuanlarEkrani(),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700), size: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "welcome_screen.leaderboard".tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  final void Function(String, String, int, {bool isDuel}) onPressedd;
  final String text;

  const StartButton({
    required this.onPressedd,
    required this.onPressed,
    this.text = 'Quiz',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6A141).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              HapticService.medium();
              final hasInternet = await AppUtils.hasInternetConnection();
              if (!hasInternet && context.mounted) {
                showOfflineNoticeDialog(
                  context,
                  onStart: onPressed,
                  onOfflineQuickPlay: () =>
                      onPressedd('Genel Kültür', 'Kolay', 30),
                );
                return;
              }
              if (context.mounted) {
                if (MainShell.selectTabOf(context, 1)) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KategoriScreen(
                      onStartQuiz: onPressedd,
                      onStart: onPressed,
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.amber, AppColors.amberDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showOfflineNoticeDialog(
  BuildContext context, {
  required VoidCallback onStart,
  VoidCallback? onOfflineQuickPlay,
}) {
  showDialog(
    context: context,
    builder: (context) => GlassAlertDialog(
      backgroundColor: AppColors.scaffoldGradientEnd,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'errors.no_internet_title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'errors.offline_only_past_tests'.tr(),
        style:
            const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ),
        if (onOfflineQuickPlay != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onOfflineQuickPlay();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small)),
            ),
            child: Text('offline_quiz.quick_play'.tr(),
                style: const TextStyle(color: Colors.white)),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BasariHesaplaScreen(onStart: onStart),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.indigo,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.small)),
          ),
          child: Text('past_tests.view_past_tests'.tr(),
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class QuickMatchButton extends StatelessWidget {
  final VoidCallback onTap;

  const QuickMatchButton({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.coral.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              HapticService.medium();
              final hasInternet = await AppUtils.hasInternetConnection();
              if (!hasInternet && context.mounted) {
                showOfflineNoticeDialog(context, onStart: () {});
                return;
              }
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9F43), AppColors.coral],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'duel.quick_match'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'duel.quick_match_sub'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FriendRaceButton extends StatelessWidget {
  final VoidCallback onTap;

  const FriendRaceButton({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              HapticService.medium();
              final hasInternet = await AppUtils.hasInternetConnection();
              if (!hasInternet && context.mounted) {
                showOfflineNoticeDialog(context, onStart: () {});
                return;
              }
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.indigoLight, AppColors.indigoDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'duel.friend_race'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD56B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '1v1 ⚡',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BasariButton extends StatelessWidget {
  final VoidCallback onStart;
  const BasariButton({required this.onStart, super.key});

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    return GlassContainer(
      opacity: 0.1,
      blur: 10,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticService.light();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BasariHesaplaScreen(onStart: onStart),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.history_rounded,
                  color: Colors.blueAccent, size: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'welcome_screen.my_tests'.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
