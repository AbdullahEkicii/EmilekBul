/// Açılışta çıkan bilgilendirme pencerelerini sınırlayan basit oturum sayacı.
/// Bir uygulama oturumunda en fazla [maxInfoDialogs] pencere gösterilir; kalanlar ertelenir.
/// Ertelenen pencerelerin kendi "bugün gösterildi/gördü" bayrakları gösterilmedikçe set
/// edilmediğinden sonraki açılışta/ekran dönüşünde tekrar denenir.
///
/// Öncelik (yüksek -> düşük): zorunlu güncelleme > seri kurtarma > günlük seri ödülü >
/// lig sonucu > aylık kazanan > yenilikler (güncelleme sonrası) > misafir bağlama > bildirim izni.
/// Her kontrol akışı kendi gecikmesiyle bu sıraya göre tetiklenir (yüksek öncelik daha erken).
/// Arkadaş daveti / dürtme gibi anlık bildirimler kuyruğa GİRMEZ.
enum StartupDialogType {
  forcedUpdate,
  streakRescue,
  dailyStreak,
  leagueResult,
  monthlyWinner,
  whatsNew,
  guestLink,
  notificationPermission,
}

class StartupDialogQueue {
  static const int maxInfoDialogs = 2;
  static final Set<StartupDialogType> _shown = {};

  /// Zorunlu/kritik pencereler: sınıra takılmaz ama sayılır.
  static void force(StartupDialogType type) => _shown.add(type);

  /// Yer varsa ve bu tür bu oturumda gösterilmediyse yer ayırır.
  static bool tryClaim(StartupDialogType type) {
    if (_shown.contains(type)) return false;
    if (_shown.length >= maxInfoDialogs) return false;
    _shown.add(type);
    return true;
  }

  static bool get hasRoom => _shown.length < maxInfoDialogs;
}
