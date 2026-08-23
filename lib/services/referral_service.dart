import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_service.dart';

enum ReferralResult {
  success,
  alreadyUsed,
  ownCode,
  invalidCode,
  error,
}

class ReferralService {
  static const int referralRewardTokens = 500;
  static const int referrerBonusTokens = 250;
  static const String _claimedKey = 'has_claimed_referral_reward';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kullanıcının kendi benzersiz davet kodunu döner
  static Future<String> getUserInviteCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final existingCode = userDoc.data()?['inviteCode'] as String?;
        if (existingCode != null && existingCode.isNotEmpty) {
          return existingCode.toUpperCase();
        }
      }

      // Kod yoksa UID'nin ilk 6 karakterinden temiz bir kod üret ve kaydet
      final newCode = user.uid.length >= 6
          ? user.uid.substring(0, 6).toUpperCase()
          : user.uid.toUpperCase();

      await _firestore.collection('users').doc(user.uid).set({
        'inviteCode': newCode,
      }, SetOptions(merge: true));

      return newCode;
    } catch (e) {
      debugPrint('Error getting invite code: $e');
      return user.uid.length >= 6 ? user.uid.substring(0, 6).toUpperCase() : 'FRIEND';
    }
  }

  /// Kullanıcının daha önce bir davet kodu kullanıp kullanmadığını kontrol eder
  static Future<bool> hasUsedReferral() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locallyClaimed = prefs.getBool(_claimedKey) ?? false;
      if (locallyClaimed) return true;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['hasUsedReferralCode'] == true) {
          await prefs.setBool(_claimedKey, true);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking referral status: $e');
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_claimedKey) ?? false;
    }
  }

  /// Arkadaşının davet kodunu girerek 500 Token ödülünü alma akışı
  static Future<ReferralResult> redeemReferralCode(String inputCode, BuildContext context) async {
    final cleanCode = inputCode.trim().toUpperCase();
    if (cleanCode.isEmpty || cleanCode.length < 4) {
      return ReferralResult.invalidCode;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return ReferralResult.error;

    try {
      // 1. Daha önce kullanılmış mı?
      final alreadyUsed = await hasUsedReferral();
      if (alreadyUsed) {
        return ReferralResult.alreadyUsed;
      }

      // 2. Kendi kodu mu?
      final myCode = await getUserInviteCode();
      if (cleanCode == myCode || user.uid.toUpperCase().startsWith(cleanCode)) {
        return ReferralResult.ownCode;
      }

      // 3. Kodun ait olduğu kullanıcıyı Firestore'da ara
      DocumentSnapshot? referrerDoc;
      final codeQuery = await _firestore
          .collection('users')
          .where('inviteCode', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (codeQuery.docs.isNotEmpty) {
        referrerDoc = codeQuery.docs.first;
      } else {
        // Fallback: UID başlangıcına göre ara
        final uidQuery = await _firestore
            .collection('users')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: cleanCode.toLowerCase())
            .where(FieldPath.documentId, isLessThanOrEqualTo: '${cleanCode.toLowerCase()}\uf8ff')
            .limit(1)
            .get();
        if (uidQuery.docs.isNotEmpty) {
          referrerDoc = uidQuery.docs.first;
        }
      }

      if (referrerDoc == null || !referrerDoc.exists || referrerDoc.id == user.uid) {
        return ReferralResult.invalidCode;
      }

      final referrerUid = referrerDoc.id;

      // 4. Kullanıcıya 500 Token ver & Bayrakları güncelle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claimedKey, true);

      await TokenService.addTokens(referralRewardTokens);

      await _firestore.collection('users').doc(user.uid).set({
        'hasUsedReferralCode': true,
        'usedReferralCode': cleanCode,
        'referredBy': referrerUid,
        'referralClaimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5. Kod sahibine (Arkadaşa) da bonus token ve sayaç artışı sağla
      try {
        await _firestore.collection('users').doc(referrerUid).update({
          'tokens': FieldValue.increment(referrerBonusTokens),
          'referralCount': FieldValue.increment(1),
        });
      } catch (_) {}

      // 6. Başarı bildirimi
      if (context.mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'referral.success'.tr(args: [referralRewardTokens.toString()]),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
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

      return ReferralResult.success;
    } catch (e) {
      debugPrint('Error redeeming referral code: $e');
      return ReferralResult.error;
    }
  }
}
