import 'dart:async';
import 'package:flutter/foundation.dart';
import '../widgets/rewarded_ad_manager.dart';

/// Ödüllü reklamı "bir kez göster ve sonucu bekle" biçiminde sunan küçük sarmalayıcı.
/// Oyun içi avantajlar (joker, ödül katlama) bu sınıf üzerinden reklam izletir.
/// Ödül kullanıcı reklamı tamamlamadan kapatırsa [showAndWait] false döner.
class RewardedBoost {
  final RewardedAdManager _manager = RewardedAdManager();

  bool get isReady => _manager.isReady;

  void load({VoidCallback? onLoaded}) {
    _manager.loadAd(onAdLoaded: () => onLoaded?.call());
  }

  /// Reklamı gösterir. Bekleme süresi dolmamışsa, reklam hazır değilse veya
  /// kullanıcı ödül kazanmadan kapattıysa false döner.
  Future<bool> showAndWait() async {
    if (!_manager.isReady) return false;
    if (await RewardedAdManager.getRemainingCooldown() > Duration.zero) {
      return false;
    }

    final completer = Completer<bool>();
    _manager.showAd(
      onRewarded: () {
        // Ödül kesinleşti: önce tamamla, kayıt arka planda yazılsın
        if (!completer.isCompleted) completer.complete(true);
        RewardedAdManager.recordAdWatched();
      },
      onDismissed: () {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future;
  }

  void dispose() => _manager.dispose();
}
