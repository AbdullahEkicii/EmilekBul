import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_service.dart';
import '../widgets/glass_container.dart';

class ReviewService {
  static const int reviewRewardTokens = 200;
  static const String _claimedKey = 'has_claimed_review_reward';
  static const String _lastPromptKey = 'review_prompt_last_shown';
  static final InAppReview _inAppReview = InAppReview.instance;

  /// Kullanıcının daha önce 200 token ödülünü alıp almadığını kontrol eder
  static Future<bool> hasClaimedReward() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locallyClaimed = prefs.getBool(_claimedKey) ?? false;
      if (locallyClaimed) return true;

      // Firestore kontrolü
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['hasClaimedReviewReward'] == true) {
          await prefs.setBool(_claimedKey, true);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking review reward status: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_claimedKey) ?? false;
    }
  }

  /// 200 Jeton ödülünü güvenli ve tek seferlik olarak tanımlar
  static Future<bool> claimReward(BuildContext context) async {
    try {
      final alreadyClaimed = await hasClaimedReward();
      if (alreadyClaimed) return false;

      // 1. Yerel bayrağı anında true yap (Race condition önlemi)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claimedKey, true);

      // 2. Token ekle
      await TokenService.addTokens(reviewRewardTokens);

      // 3. Firestore kaydı
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'hasClaimedReviewReward': true,
            'reviewRewardedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error saving review reward in Firestore: $e');
        }
      }

      // 4. Tebrik bildirimi & Haptik
      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'review.reward_claimed_title'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent),
                      ),
                      Text(
                        'review.reward_claimed_toast'.tr(args: [reviewRewardTokens.toString()]),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error claiming review reward: $e');
      return false;
    }
  }

  /// Uygulama içi (In-App) Google Play yorum & puan akışını başlatır
  static Future<void> startReviewFlow({
    required BuildContext context,
    VoidCallback? onRewardClaimed,
  }) async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing();
      }

      // İnceleme modalı kapandıktan sonra (veya mağaza açıldıktan sonra) ödülü güvenle ver
      final isAlreadyClaimed = await hasClaimedReward();
      if (!isAlreadyClaimed && context.mounted) {
        final success = await claimReward(context);
        if (success) {
          onRewardClaimed?.call();
        }
      }
    } catch (e) {
      debugPrint('In-App Review flow error: $e');
      // Hata durumunda fallback olarak mağaza sayfasını aç
      try {
        await _inAppReview.openStoreListing();
      } catch (_) {}
    }
  }

  /// Kullanıcıya modern ve ödüllü değerlendirme dialogu gösterir
  static void showReviewDialog(BuildContext context, {VoidCallback? onRewardClaimed}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star Icon with Glow
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.amber, size: 42),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'review.dialog_title'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  'review.dialog_desc'.tr(args: [reviewRewardTokens.toString()]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Token Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: Color(0xFF34D399), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'review.reward_badge'.tr(args: [reviewRewardTokens.toString()]),
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'review.later'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          startReviewFlow(context: context, onRewardClaimed: onRewardClaimed);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_rounded, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'review.rate_now'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Uygun anlarda (örn: 3. test sonrası veya seviye atlamada) kullanıcıyı rahatsız etmeden değerlendirme önerir
  static Future<void> checkAndPromptAutoReview(BuildContext context) async {
    try {
      final alreadyClaimed = await hasClaimedReward();
      if (alreadyClaimed) return;

      final prefs = await SharedPreferences.getInstance();
      final lastPromptMillis = prefs.getInt(_lastPromptKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // En az 3 gün ara ile göster (3 * 24 * 60 * 60 * 1000)
      if (now - lastPromptMillis < 259200000) return;

      await prefs.setInt(_lastPromptKey, now);
      if (context.mounted) {
        showReviewDialog(context);
      }
    } catch (_) {}
  }
}
