# Araştırma B: Live-Ops, İçerik Takvimi ve Gelir (2026-10)

Tarih: 2026-10-20. Yalnızca araştırma; kod değiştirilmedi. Önceki rapor (retention/arka plan) tekrar edilmedi: `ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md`.
Etiketler: **[B]** birincil (resmi dokümantasyon/konferans sayfası), **[İ]** ikincil (blog, özet, rapor özeti), **[GÇ]** geliştirici çıkarımı (kaynaksız, bu rapordan sorumlu araştırmacının yorumu). Kaynaklara WebFetch aracıyla ulaşıldı; araç sayfayı özetlediği için bazı ayrıntılar küçük bir modelin özetinden gelir (sayfa metni birebir okunmadı).

---

## 1) Özet (15 madde)

1. Google Play'in resmi "Promotional content/LiveOps" kartı: etkinlik en fazla 4 hafta, başlangıçtan ≥24 saat önce, en geç başlangıca 14 gün kala gönderilir, onay 4 güne kadar sürebilir; yayınlandıktan sonra düzenlenemez; uygulama içi etkinlikle eşzamanlı olmazsa uyarı/30 gün Play Console'dan kaldırma. Beta'da seçili geliştiricilere açıktı; güncel erişim doğrulanamadı. [İ: AppTweak] https://www.apptweak.com/en/aso-blog/what-are-google-play-liveops-best-practices-examples?format=md ; [İ: Phiture] https://phiture.com/asostack/what-are-liveops-and-how-to-use-them/ ; resmi sayfa [B] https://support.google.com/googleplay/android-developer/answer/10121285 yalnız "Events" ve "Featured products" türlerini ve "Premium growth tools" ölçütlerini söylüyor.
2. Google'ın kapalı beta verisi (AppTweak üzerinden aktarılan): promosyon içeriği çalıştıran uygulamalar ortalama %5 daha fazla aktif kullanıcı, %4 daha yüksek gelir göstermiş; Google'ın kendi, bağımsız doğrulanmamış rakamı. [İ] AppTweak linki yukarıda.
3. Küçük ekip için pratik kalıp: 2-3 tekrarlayan etkinlik türü + aylık takvim, 30-50 kademeli basit pass, 2-3 etkinlik önceden hazır tampon, şablon tabanlı etkinlik. Kaynak yazarın kendi görüşü (bağımsız doğrulanmamış, rakamlar çelişkili). [İ] https://gamegrowthadvisor.com/blog/2026-03-31-liveops-strategy-mobile-games-guide/
4. Remote Config ile etkinlik aç/kapa mümkün: gerçek-zamanlı dinleyici ön planda HTTP bağlantısıyla yeni şablonu `minimumFetchInterval`'i atlayarak getirir (proje başına 20 milyon eşzamanlı bağlantı sınırı). Resmî öneri: önbellekteki değerleri açılışta uygula, yenisini sonraki oturum için çek; oturum ortasında değer değiştirme. [B] https://firebase.google.com/docs/remote-config/real-time ; https://firebase.google.com/docs/remote-config/optimization-best-practices
5. Zamanlı (cron) sunucu işi için Cloud Functions `onSchedule` + Cloud Scheduler; iş başına aylık 0,10 USD, hesap başına 3 iş ücretsiz; Blaze planı gerekir; aynı işin üst üste çalışma riski var (idempotent yazın). [B] https://firebase.google.com/docs/functions/schedule-functions
6. Ödüllü reklam: kullanıcı açıkça seçince gösterilir; ödül değeri reklam birimi başına ayarlanır. Ekonomiyi etkileyen ödülde AdMob, sunucu taraflı doğrulama (SSV) callback'ini beklemeyi öneriyor (ECDSA imza, anahtar önbelleği ≤24 saat, `transaction_id` ile tekilleştirme). [B] https://support.google.com/admob/answer/7372450 ; https://developers.google.com/admob/android/ssv
7. Geçiş reklamı: yalnız içerik sayfaları/aşamalar arasında; her 2 kullanıcı eylemine en fazla 1; kapatılır kapatılmaz yenisi yok; açılış/çıkışta değil (açılış için "app open" öneriliyor). [B] https://support.google.com/admob/answer/6201362 ; https://support.google.com/admob/answer/6066980
8. Google Play Billing: istemciden değil sunucudan doğrula; `purchaseToken` küresel benzersiz (birincil anahtar, `orderId` değil); `PENDING` iken yetki verme; 3 gün içinde acknowledge/consume yoksa otomatik iade; `obfuscatedAccountId` ile sahtecilik tespiti; Voided Purchases API ile iade/chargeback geri alma. [B] https://developer.android.com/google/play/billing/security ; https://developer.android.com/google/play/billing/integrate
9. Billing Library: 31 Ağu 2026 itibarıyla yeni uygulama/güncellemelerde v8+ zorunlu (uzatma talebiyle 1 Kas 2026'ya kadar). Flutter `in_app_purchase` 3.3.1 (Android SDK 24+); `completePurchase` çağrılmazsa Android 3 gün sonra iade eder; tüketilmiş ürünler Play'den sorgulanamaz, bakiyeyi kendi sunucunuzda tutun. [B] https://developer.android.com/google/play/billing ; https://pub.dev/packages/in_app_purchase
10. Play servis ücreti: sayfaya göre "diğer pazarlar"da ilk 1 milyon USD yıllık gelirde %15, abonelikte %15; ABD/AB/Birleşik Krallık/Avustralya/Japonya için yeni yapı (abonelik %10 + %5 faturalama; tek seferlik ürünlerde yeni yüklemede %20+%5). Türkiye için hangi dilimin geçerli olduğu sayfada açıkça yok → doğrulanamadı. [B] https://support.google.com/googleplay/android-developer/answer/112622
11. Rastgele sanal öğe (loot box) satışında satın alma öncesi ve yakınında olasılık açıklaması şart; sanal para yalnız satın alındığı uygulamada harcanabilir. [B] https://support.google.com/googleplay/android-developer/answer/9858738 (loot box maddesi sayfadan alındı; mağazada "rastgele paket" varsa uygulanır.)
12. Retention kıyası (tüm oyunlar, GameAnalytics 2025 özeti): medyan D1 ~%22, D7 ~%4, D30 ~%0,7; en iyi %10: D1 ~%40, D7 ~%12, D30 ~%4. Ölçüm yöntemi/örneklem belirtilmemiş. Trivia'ya özel güncel (2024-25) birincil rakam bulunamadı. [İ] https://investgame.net/news/pdf/2026-01-20-mobile_retention_benchmarks_2026/
13. ARPDAU: yalnız reklamlı casual için 0,01-0,05 USD; hibrit-casual (reklam+IAP) 0,15-0,50 USD. Rakamlar bir blog üzerinden başka bir bloga atıf; metodoloji yok. Reklam gelir payı ikincil özette %63'ten %56'ya, abonelik %4'ten %7'ye (karma monetizasyonlu oyunlar). [İ] https://blog.playio.co/arpdau-benchmarks-mobile-games
14. Ekonomi: kaynak/gider (faucet/sink) dengesi; akademik tek kanıt noktası (Old School RuneScape, nedensel çıkarım): işlem vergisi hacmi anlamlı değiştirmedi, öğe gideri lüks mal fiyatlarının artışıyla örtüştü. Tek oyun, MMO, sonuç trivia'ya doğrudan taşınmaz. [B/ön baskı] https://arxiv.org/abs/2210.07970
15. Düşük kullanıcı sayısında gelir hedefi gerçekçi olmalı: Appodeal verisi eCPM'i ülke ve biçime göre ayırıyor ama Türkiye değerleri çekilen sayfada yok; Türkiye rewarded eCPM'i doğrulanamadı. [İ] https://appodeal.com/blog/mobile-ecpm-report-app-ad-monetization-worldwide-performance

---

## 2) Live-ops çerçevesi

### 2.1 Tanım ve bileşenler
- Live-ops = lansmandan sonra oyunu hizmet olarak yürütmek: olay yakalama, segmentasyon, deney/özellik bayrağı, analitik/retention; uzak yapılandırma ile ödül/hedefleme build göndermeden değişir. Küçük stüdyoya öneri: olayları lansmandan önce ölçün, ilk canlı etkinlikleri geliştirme sırasında planlayın, tek teklif/ödül değişikliğini kontrol grubuyla ölçün. Aynı yazı kendi ürününü öneriyor (satıcı yanlılığı). [İ] https://heroiclabs.com/blog/what-is-game-liveops/
- GDC 2015 "LiveOps: A Process in the Making" (MunkyFun): küçük stüdyoların esnek süreç + analitik ile live-ops yapabileceği; video üyelere açık, içerik özeti dışında bulgu okunamadı. [B-özet] https://gdcvault.com/play/1022125/LiveOps-A-Process-in-the
- GDC 2015 "Effective LiveOps Strategies" (PlayFab, James Gwertzman): iki araç, oyun içi etkinlik ve oyuncu teklifleri; "live ops'u oyun kadar özenle planlayın". Detay üyelik gerektirir. [B-özet] https://gdcvault.com/play/1021947/Effective-LiveOps
- GDC 2026 oturumu "Evolve or Die: How LiveOps Scaled Our Indie Hit" (kendi finansmanlı indie, şablon içerik, yapımcı alımı): sayfa 403 verdi, yalnız arama özetine dayanır; doğrulanamadı. https://schedule.gdconf.com/session/evolve-or-die-how-liveops-scaled-our-indie-hit/914177

### 2.2 Üç katmanlı takvim (tek yazar görüşü, [İ])
Game Growth Advisor: makro (4-8 hafta: sezonluk tema), orta (1-2 hafta: turnuva/mücadele serisi), mikro (24-72 saat: hafta sonu etkinliği); büyük rekabetçi etkinlikler arasında 12-24 saat nefes payı; küçük ekip için "ayda 4-6 cilalı etkinlik". Aynı yazıdaki hedefler (etkinlik katılımı DAU'nun %40-60'ı, etkinlik sırasında ARPDAU +%20-40) yazarın kendi iddiasıdır, bağımsız doğrulanmamış; yazı kendi içinde tutarsız (80-100 vs ~100 dokunuş noktası). https://gamegrowthadvisor.com/blog/2026-03-31-liveops-strategy-mobile-games-guide/

### 2.3 Sezon/battle pass modeli
- Brawl Stars örneği: pass ücretsiz/ücretli katman, görevlerle token toplama, sezon başına yaklaşık iki ay, ücretli katman ~8,99-9,99 USD, kademe sayısı kaynaklar arasında çelişkili (80 / 100). Supercell birincil kaynağı bulunamadı. [İ] https://www.sportskeeda.com/mobile-games/brawl-stars-season-34-brawl-pass-cost-rewards ; https://clutchpoints.com/gaming/all-brawl-stars-brawl-pass-rewards-for-season-50 (başlık düzeyinde arama sonucu; sayfalar okunmadı).
- Pass gelirinin "üst sırada gelirli F2P oyunlarda gelirin %10-40'ı" olduğu iddiası yalnız Game Growth Advisor'da, birincil yok. [İ]
- Play LiveOps'ta "battle ve season pass" büyük güncelleme kartı olarak listeleniyor. [İ: Phiture]

### 2.4 Play'in kendi live-ops kanalı
- Kartlar: Teklif (indirim/ek değer/ücretsiz ödül/abonelik denemesi/diğer), Etkinlik (zaman sınırlı turnuva/mücadele), Büyük güncelleme (içerik, sezon/battle pass), ön kayıt duyurusu. Etkinlik ≤4 hafta, teklif süresiz olabilir (süresizler yalnız yeni kullanıcıya), büyük güncelleme 1 hafta; çeyrekte yalnız 1 "Çok yüksek" öncelik. Hedef: "Herkes" veya "Yeni kullanıcılar" (ölçüt eklemeleri planlanmış). Raporlama: tekil görüntüleyen, dönüştüren, dönüşüm oranı. [İ] Phiture/AppTweak linkleri yukarıda.
- Resmî yardım sayfası etkinlik ve "öne çıkan ürün" biçimlerini adlandırıyor; öne çıkarma, derin bağlantı ve kitle hedefleme için "Premium growth tools" ölçütü gerekli; ölçüt ayrıntısı çekilemedi. [B] https://support.google.com/googleplay/android-developer/answer/10121285
- Uygunluk: küçük/yeni uygulamanın erişimi doğrulanamadı → Play Console'da "Grow > Promotional content" bölümü kontrol edilmeli [GÇ].

### 2.5 Tek geliştirici ritmi (öneri, [GÇ] kaynaklı kısımlar işaretli)
- İçerik hattı: soru üretimi (Gemini) → toplu üretim betiği → insan örneklem denetimi → Firestore'a "yayın tarihi" ile yazma; etkinlik = Remote Config JSON (başlangıç/bitiş zamanı, kural, ödül tablosu).
- Remote Config anahtarı örneği: `events_calendar_json` (liste: id, tür, başlangıç, bitiş, ödül çarpanı, kategori). İstemci açılışta önbelleği uygular, gerçek-zamanlı dinleyici yalnız yeni içerik duyurusu için. [B için Remote Config sayfaları; tasarım GÇ]
- Takvim sunucu saatine bağlı: bitiş/başlangıç kararı Cloud Functions `onSchedule` ile (haftalık lig sıfırlama, sezon geçişi); istemci saati yalnız gösterim. [B: scheduled functions; GÇ: tasarım]
- Deney: Firebase A/B Testing ile (önceki raporda: 1 birincil + ≤5 ek metrik, ~14 gün lider).

---

## 3) Benchmark'lar

| Metrik | Değer | Kaynak | Birincil/İkincil | Ölçüm / not |
|---|---|---|---|---|
| Tüm oyunlar medyan D1/D7/D30 | ~%22 / ~%4 / ~%0,7 (2025) | https://investgame.net/news/pdf/2026-01-20-mobile_retention_benchmarks_2026/ (GameAnalytics raporu özeti) | İkincil | Hesaplama yöntemi, örneklem, rapor adı belirtilmemiş; "2025'te yine düştü" |
| Üst %10 D1/D7/D30 | ~%40 / ~%12 / ~%4 | aynı | İkincil | "Üst %10" tanımı belirtilmemiş. Yazar daha gerçekçi hedef olarak 35/15/5 öneriyor |
| Trivia D1 (en iyi başlıklar) | en çok ~%48 (2019 verisi) | arama özeti, GameAnalytics 2019 (wnhub.io: https://wnhub.io/news/analytics/item-2261) | İkincil, eski | Sayfa okunmadı; yalnız arama özeti; 2024-25 trivia'ya özel birincil rakam bulunamadı |
| Genel "iyi" D7 | %14 (2019) | aynı | İkincil, eski | Trivia'da D7 %15-25 yalnız en iyi projeler |
| Oyun dikeyi D1 / D30 (Adjust 2022 verisi) | %29 / %6 | https://adjust.com/blog/get-the-mobile-app-retention-benchmarks-for-2023/ (sayfa 429 verdi, okunamadı; rakamlar arama özetinden) | Birincil kaynak ama özet üzerinden doğrulanamadı | Yıl 2022 |
| Puzzle D1/D7/D30 (AppsFlyer 2022 Ç3) | %31,85 / %12,18 / %5,35 | arama özeti (ikincil blog) | İkincil | Trivia ayrı verilmemiş |
| ARPDAU casual (yalnız reklam) | 0,01-0,05 USD | https://blog.playio.co/arpdau-benchmarks-mobile-games | İkincil (kendisi Game Growth Advisor'a atıf) | ARPDAU = günün geliri / günün DAU'su |
| ARPDAU hibrit-casual | 0,15-0,50 USD | aynı | İkincil | IAP payı %40-60 iddiası |
| D90 reklam geliri/kullanıcı (casual) | 0,55 USD (casino 0,47; midcore 0,40; hypercasual 0,22) | AppsFlyer "State of App Monetization 2026" - özet: https://gamedevreports.substack.com/p/appsflyer-app-monetization-in-2026 | İkincil (birincil rapora ulaşılamadı) | D90 IAA ARPU, küresel ortalama |
| Rewarded eCPM (ABD Android, 2024 Ç2) | 30,25 USD | arama özeti (Tenjin/CAS) | İkincil | Türkiye değeri yok |
| Türkiye rewarded/interstitial eCPM | bulunamadı | Appodeal sayfası: https://appodeal.com/blog/mobile-ecpm-report-app-ad-monetization-worldwide-performance | İkincil | Etkileşimli araçta; metin sayfada yok |
| Etkinlik katılım / ARPDAU artışı | %40-60 DAU / +%20-40 | https://gamegrowthadvisor.com/blog/2026-03-31-liveops-strategy-mobile-games-guide/ | İkincil (yazar görüşü) | Atıf yok, kendi içinde tutarsız |
| Play LiveOps beta etkisi | +%5 aktif kullanıcı, +%4 gelir | AppTweak üzerinden Google | İkincil (birincil atıf) | Kapalı beta, bağımsız doğrulanmamış |
| Uninstall oranı (trivia/casual) | bulunamadı | n/a | n/a | Doğrulanamadı |

---

## 4) Gelir stratejisi

### 4.1 Reklam (AdMob resmi rehberleri)
- **Ödüllü:** Yalnız kullanıcı açıkça seçerse; ödül değeri reklam biriminde ayarlanır; reklam pod'u (iki ardışık video) varsayılan açık, kapatmak geliri azaltabilir; kapat düğmesi/sayaç 5-30 sn. Placement tavsiyesi sayfada yok (video bağlantısı). [B] https://support.google.com/admob/answer/7372450
- **Uygulamada ön yükleme:** Reklam 1 saat sonra süresi dolar; önbelleği yenile; ödül dinleyicisi (`OnUserEarnedRewardListener`) ve SSV için `custom_data`. [B] https://developers.google.com/admob/android/rewarded
- **SSV:** Ekonomi etkiliyorsa SSV callback'i bekle; `transaction_id` ve `user_id` ile tekilleştir; imza doğrulama; en çok 5 yeniden deneme (1 sn). [B] https://developers.google.com/admob/android/ssv
- **Geçiş:** Bkz. özet madde 7 (doğal duraklar, 2 eylemde en çok 1, önceden yükle, kapatma gecikmesi genelde 5 sn'ye kadar). [B] https://support.google.com/admob/answer/6201362 ; https://support.google.com/admob/answer/6066980
- **Banner:** Bu araştırmada banner yerleşimine dair resmî sayfa okunamadı; yalnız geçiş sayfası "yardımcı/utility uygulamalarda banner daha uygun olabilir" diyor → doğrulanamadı.
- **Mediation:** Birden çok reklam kaynağına yönlendirir; bidding (gerçek zamanlı açık artırma) ile waterfall (sıralı) birlikte kullanılabilir; sayfa gelir artışı rakamı VERMİYOR. Bu nedenle "mediation %X eCPM artırır" iddiası bu raporda yer almaz. [B] https://support.google.com/admob/answer/3063564
- **Play politikası etkileri:** Önceki rapordaki (Ads politikası, Families) maddeler geçerli; ek olarak AdMob "çok fazla reklam / uygulamanın ana odağı olmasın" ve kazara tıklama uyarısı yapıyor; kurallara uymamak geçersiz trafik/reklam yayınının kapatılmasına yol açabilir. [B] https://support.google.com/admob/answer/6201362

### 4.2 Reklam vs IAP vs abonelik (çok az kullanıcı için)
- Gerçekçi tablo [GÇ, rakam yok]: DAU çok düşükse reklam geliri (ARPDAU x DAU) küçük kalır; ARPDAU aralığı için bkz. §3 (ikincil, çok geniş aralık). Gelir hedefi "birkaç yüz kullanıcıyla anlamlı gelir" değil, "ürün-pazar uyumu ölçmek ve içerik hendeği kurmak" olmalı.
- Abonelik payı karma monetizasyonlu oyunlarda %4→%7'ye çıkmış (ikincil özet). Trivia için abonelik "reklamsız + haftalık premium paket" biçiminde mümkün ama düşük DAU'da denemek yüksek efor/düşük getiri [GÇ].
- Reklamsız tek seferlik IAP (non-consumable) ve jeton paketi (consumable) abonelikten daha basit; Play ücret yapısı farkı için §5.3.
- Çocuk riski: Families politikası (önceki raporda) hedef kitle çocukları içeriyorsa IAP/reklam seçeneklerini sınırlar. [B] https://support.google.com/googleplay/android-developer/answer/9893335 (önceki rapordan)

---

## 5) IAP / abonelik

### 5.1 Play Billing özeti [B]
- Sadece dijital ürünler; iki tür: tek seferlik (`INAPP`: tüketilebilir/tüketilemez) ve abonelik (`SUBS`). Sunucu doğrulama "şiddetle öneriliyor"; RTDN (Cloud Pub/Sub) ile durum değişimi izlenir. https://developer.android.com/google/play/billing
- `enablePendingPurchases`, `queryPurchasesAsync` (bağlantıda ve `onResume`'da), `ProductDetails` önbelleğe alınmaz. https://developer.android.com/google/play/billing/integrate
- Güvenlik: bkz. özet madde 8; reddedilen satın almada tüket/onaylama, açıkça iade et (`Orders:refund` + `revoke`, abonelikte `subscriptionsv2:revoke`). https://developer.android.com/google/play/billing/security
- Abonelik: base plan + offer; ücretsiz deneme; grace period ve account hold (süre base plan başına); ilk abonelikte 3 gün içinde acknowledge; sonraki yenilemelerde gerekmez; iptal=erişim süre sonuna kadar, revoke=anında; 1 yıla kadar yeniden abone olma. https://developer.android.com/google/play/billing/subscriptions

### 5.2 Flutter `in_app_purchase` [B] https://pub.dev/packages/in_app_purchase
- Sürüm 3.3.1; Android SDK 24+, iOS 13+.
- `buyConsumable` / `buyNonConsumable`, `purchaseStream` dinle; teslimden sonra `completePurchase`; yapılmazsa Android 3 gün sonra iade.
- Tüketilmiş ürünler geri yüklenemez; sahipliği kendi sunucunuzda tutun.
- Sunucu doğrulama kodu pakette YOK; Google Play Developer API ile Cloud Function'da yazılmalı.
- Billing Library sürümü paketin altında olduğundan v8 zorunluluğu için paketin kullandığı Billing Library sürümü doğrulanmadı (changelog kontrolü gerekir) → doğrulanamadı.

### 5.3 Ücretler ve fiyat
- Servis ücreti sayfası: yeni (ABD/AB/Birleşik Krallık: 30 Haz 2026; Avustralya/Japonya: 30 Eyl 2026) ve eski yapı birlikte anlatılıyor; "diğer pazarlar" için ilk 1 milyon USD'de %15, abonelikte %15; 15% kademesi için kayıt gerekir, ölçüt başka sayfada. Türkiye'nin hangi gruba girdiği sayfada açık değil. [B] https://support.google.com/googleplay/android-developer/answer/112622
- Fiyat dönüştürme: yeni bir alıcı para birimi eklendiğinde Google varsayılan fiyat, güncel kur ve yerel fiyat kalıplarıyla otomatik fiyat üretir; Play Console "Uygulama fiyatlandırması" sayfasında gözden geçirilebilir; kur sipariş anındaki kurdur; iade orijinal para biriminde. [B] https://support.google.com/googleplay/android-developer/answer/1169947
- Vergi: Google'ın vergi tahsil/ödeme sorumluluğu ve Türkiye notu bu araştırmada doğrulanamadı (çekilen sayfa konum/para birimi tablosuydu).
- Loot box/rastgele öğe ve sanal para kuralı: bkz. özet 11. [B] https://support.google.com/googleplay/android-developer/answer/9858738

### 5.4 Trivia'ya uyarlama (öneriler, [GÇ])
- **Jeton paketi (consumable):** 3 kademe; sunucu `purchaseToken` kaydı + `consume`; bakiye sunucuda.
- **Reklamsız (non-consumable):** banner/geçiş kapatır, ödüllü reklam kalır (kullanıcı seçimi).
- **Sezon pass (tek seferlik veya sezonluk "abonelik değil"):** ücretsiz + premium kademe; ücretsiz kademe gerçek değer vermeli.
- **Abonelik:** düşük DAU'da önce ertele.

---

## 6) Ekonomi

- **Faucet/sink:** Faucet = sisteme giren değer (ödül, günlük bonus, reklam ödülü); sink = çıkan (mağaza alışverişi, güçlendirici, kozmetik). Faucet > sink uzun süre = enflasyon. İkincil kaynak: https://yukaichou.com/gamification-analysis/economy-design-sources-sinks-confidence/ ; https://metavert.io/game-economy-design (yalnız arama özeti, sayfalar okunmadı).
- **Akademik/kanıt:** Hogan-Hennessy, Xenopoulos, Silva (2022), Old School RuneScape'te iki müdahale (işlem vergisi, öğe sink'i); vergi, sınır noktalarında işlem hacmini anlamlı değiştirmedi; sink lüks mal fiyatlarının artışıyla örtüştü ama ticaret hacmini azaltmadı. Tek oyun, MMO, ön baskı. [B/ön baskı] https://arxiv.org/abs/2210.07970
- Castronova'nın EverQuest çalışması (birincil kaynağa ulaşılamadı; arama özeti): sanal para ile gerçek para kuru ve enflasyon gözlemi. [İ] https://thewalrus.ca/?p=47662 (arama sonucu, sayfa okunmadı)
- **Stok-akış modeli:** her para biriminin stoğu = önceki + giriş - çıkış; ileri projeksiyonla kaçak enflasyon/deflasyon denetlenir. İkincil. https://medium.com/@msahinn21/designing-game-economies-inflation-resource-management-and-balance-fa1e6c894670
- **Duolingo:** gem ekonomisine dair resmî birincil kaynak bulunamadı; yalnız hayran/üçüncü taraf kaynaklar (kullanılmadı).
- **Hile önleme [B]:** ödüllü reklam → SSV; IAP → sunucu `purchaseToken` doğrulama + tekilleştirme + `obfuscatedAccountId`; İstemci bütünlüğü → Firebase App Check (Android'de Play Integrity sağlayıcısı, günlük 10.000 çağrı kotası Standard katmanda; Cloud Functions'ta yalnız callable desteği; azaltır ama bitirmez). https://firebase.google.com/docs/app-check
- **Önerilen metrikler [GÇ]:** günlük toplam jeton üretimi/harcaması (faucet/sink oranı), medyan bakiye, bakiye P90, reklam ödül sıklığı/kullanıcı, mağaza dönüşümü, güçlendirici kullanım oranı. Tüm ödül/bakiye işlemleri Cloud Function transaction'ı ile (idempotent) ve kayıtlı.

---

## 7) Uygulanabilirlik tablosu

Not: Efor/risk değerleri [GÇ] tahminidir; projenin kodu bu araştırmada incelenmedi. "Mevcut sistem" sütunu görev tanımındaki özellik listesine göre.

| Öneri | Ölçülecek metrik | Efor | Risk | Yeni altyapı | Bağlandığı mevcut sistem |
|---|---|---|---|---|---|
| Remote Config etkinlik takvimi JSON'u + gerçek zamanlı dinleyici | Etkinlik katılım %, etkinlik günü DAU/ARPDAU | S | Düşük (oturum ortası değer değişimi dikkat) | Yok (RC zaten pinli) | Remote Config, günlük meydan okuma, mağaza |
| Haftalık "tema haftası" (kategori çarpanı) | D7 geri dönüş, oturum/gün | S | Düşük | İçerik etiketleme | Tek kişilik/ligler, soru havuzu |
| Zaman sınırlı mod (hafta sonu 72 sa, çift jeton) | Etkinlik sırasında ARPDAU, jeton enflasyonu | M | Orta (ödül enflasyonu) | Cloud Functions zamanlayıcı | Jeton ekonomisi, lig |
| Sezon + ücretsiz/ücretli pass (30-50 kademe) | Pass dönüşümü, kademe ilerleme, D30 | L | Orta-yüksek (denge, destek yükü) | Sunucu ilerleme, IAP | Mağaza, seri, görevler |
| Koleksiyon etkinliği (sezonluk avatar/çerçeve seti) | Set tamamlama oranı, mağaza dönüşümü | M | Düşük | Yeni görseller | Mağaza avatar/çerçeve/unvan |
| Ödüllü reklam SSV | Reddedilen ödül oranı, sahte ödül kaybı | M | Düşük | Cloud Function + imza doğrulama | Ödüllü reklam, jeton |
| Jeton paketi IAP (consumable) | Ödeme yapan %, ARPPU | M | Orta (Billing v8, sunucu doğrulama) | `in_app_purchase`, Cloud Function, Play Developer API, RTDN | Jeton ekonomisi, mağaza |
| Reklamsız IAP | Reklamsız dönüşüm, reklam geliri kaybı | S-M | Düşük | Aynı IAP altyapısı | Banner/geçiş reklamı |
| Abonelik | Abone oranı, churn | L | Yüksek (düşük DAU) | RTDN, grace/hold işleme | Mağaza |
| Mediation (AdMob mediation + 1-2 ağ) | eCPM, doluluk | M | Orta (SDK boyutu, Families uyumu) | Ağ SDK'ları | Mevcut AdMob |
| Play Promotional Content kartları | Kart dönüşümü, yeni kullanıcı | S (başvuru) | Düşük; erişim belirsiz | Görseller, 14 günlük plan | Etkinlik takvimi |
| Ekonomi paneli (günlük faucet/sink) | Faucet/sink oranı, bakiye P90 | M | Düşük | BigQuery/Firestore toplama | Jeton ekonomisi |
| A/B testi: etkinlik sıklığı | D7/D30, bildirim iptali | S | Düşük | Firebase A/B | Remote Config |
| App Check (Play Integrity) | Sahte istemci isteği oranı | M | Orta (yanlış red) | Konsol ayarı, istemci | Cloud Functions callable |

---

## 8) 12 aylık içerik takvimi önerisi (taslak, [GÇ])

Yayına alınış ayı için 2026-11 başlangıç varsayıldı. Her ay: 1 makro tema, 2-3 orta etkinlik, haftalık lig; gerçek Türkiye bayramları/sezonlar uyarlanmalı; tarihleri Remote Config'de kayıtlı tut.

| Ay | Makro tema | Orta etkinlik örnekleri | Ekonomi/Gelir görevi |
|---|---|---|---|
| 1 (Kas) | Başlangıç kalıbı kurma | Hafta sonu 72 sa "çift jeton" | RC takvimi, ekonomi paneli |
| 2 (Ara) | Yılbaşı koleksiyonu (çerçeve seti) | Yıl sonu bilgi yarışı | Koleksiyon seti, ödüllü reklam SSV |
| 3 (Oca) | "Yeni yıl" seri meydan okuması | Kategori haftası | Jeton paketi IAP (Billing v8) |
| 4 (Şub) | Bilim ayı | 1v1 hafta sonu turnuvası | A/B: etkinlik sıklığı |
| 5 (Mar) | Ramazan/Bahar (yerel takvime göre) | Günlük meydan okuma serisi | Reklamsız IAP |
| 6 (Nis) | Tarih ayı + Sezon 1 pass | Sezon görevleri | Pass beta (az kademe) |
| 7 (May) | Spor/Gençlik | Kategori ustalığı | Pass ayarı, mediation denemesi |
| 8 (Haz) | Yaz | Hafta sonu hız turu | Retention incelemesi |
| 9 (Tem) | Yaz koleksiyonu | Sezon 2 hazırlığı | Ekonomi dengesi (sink ekle) |
| 10 (Ağu) | Okula dönüş | Eğitim kategorisi haftası | Play kartı denemesi |
| 11 (Eyl) | Sezon 2 | Lig finali | Fiyat/yerel fiyat gözden geçirme |
| 12 (Eki) | Yıl dönümü | Yıl özeti, topluluk etkinliği | Yıllık değerlendirme, abonelik kararı |

---

## 9) Doğrulanamayanlar

- Trivia/quiz'e özel D1/D7/D30 ve uninstall oranı (2024-25, birincil). Eldeki trivia rakamları 2019 tarihli ikincil özet.
- Adjust 2023 benchmark sayfası (429 hatası): gaming D1 %29 / D30 %6 yalnız arama özeti; AppsFlyer/Tenjin/Sensor Tower birincil raporlarına ulaşılamadı.
- Türkiye için rewarded/interstitial eCPM ve ARPDAU; banner yerleşimi resmî rehberi; AdMob "rewarded best practices" videosu.
- Mediation'ın eCPM artışı (AdMob rakam vermiyor).
- Google Play LiveOps/Promotional Content'in küçük uygulamalar için güncel uygunluğu ve "Premium growth tools" ölçütleri; Play'in %4-5 etki rakamları yalnız ikincil aktarım.
- Play servis ücretinin Türkiye için geçerli dilimi; Google'ın Türkiye vergi (KDV/DST) işlemesi; Türkiye fiyat şablonu ayrıntısı.
- `in_app_purchase` paketinin kullandığı Billing Library sürümü ve v8 zorunluluğuyla uyumu.
- Supercell, King, Playtika, Zynga live-ops birincil kaynakları (arama sonuç vermedi); Brawl Pass birincil kaynağı.
- GDC oturumlarının içeriği (video üyeliğe bağlı); 2026 GDC "Evolve or Die" sayfası (403).
- Castronova'nın birincil makaleleri; Duolingo gem ekonomisi birincil kaynak; battle pass'in gelir payı (%10-40) iddiası.
- Firebase Remote Config'in Flutter'daki `minimumFetchInterval` varsayılanı (çekilen sayfa içermedi).

---

## 10) Kaynak listesi

Birincil [B]
1. https://developer.android.com/google/play/billing
2. https://developer.android.com/google/play/billing/integrate
3. https://developer.android.com/google/play/billing/security
4. https://developer.android.com/google/play/billing/subscriptions
5. https://pub.dev/packages/in_app_purchase
6. https://pub.dev/packages/google_mobile_ads (sürüm 9.1.0, yalnız sürüm bilgisi)
7. https://support.google.com/googleplay/android-developer/answer/112622
8. https://support.google.com/googleplay/android-developer/answer/1169947
9. https://support.google.com/googleplay/android-developer/answer/9858738
10. https://support.google.com/googleplay/android-developer/answer/10121285
11. https://support.google.com/admob/answer/6201362
12. https://support.google.com/admob/answer/6066980
13. https://support.google.com/admob/answer/7372450
14. https://support.google.com/admob/answer/3063564
15. https://developers.google.com/admob/android/rewarded
16. https://developers.google.com/admob/android/ssv
17. https://firebase.google.com/docs/remote-config/real-time
18. https://firebase.google.com/docs/remote-config/optimization-best-practices
19. https://firebase.google.com/docs/functions/schedule-functions
20. https://firebase.google.com/docs/app-check
21. https://gdcvault.com/play/1022125/LiveOps-A-Process-in-the (yalnız özet)
22. https://gdcvault.com/play/1021947/Effective-LiveOps (yalnız özet)
23. https://arxiv.org/abs/2210.07970 (ön baskı)

İkincil [İ]
24. https://www.apptweak.com/en/aso-blog/what-are-google-play-liveops-best-practices-examples?format=md
25. https://phiture.com/asostack/what-are-liveops-and-how-to-use-them/
26. https://gamegrowthadvisor.com/blog/2026-03-31-liveops-strategy-mobile-games-guide/
27. https://heroiclabs.com/blog/what-is-game-liveops/
28. https://investgame.net/news/pdf/2026-01-20-mobile_retention_benchmarks_2026/
29. https://blog.playio.co/arpdau-benchmarks-mobile-games
30. https://appodeal.com/blog/mobile-ecpm-report-app-ad-monetization-worldwide-performance
31. https://gamedevreports.substack.com/p/appsflyer-app-monetization-in-2026
32. https://wnhub.io/news/analytics/item-2261 (yalnız arama özeti)
33. https://adjust.com/blog/get-the-mobile-app-retention-benchmarks-for-2023/ (okunamadı, arama özeti)
34. https://yukaichou.com/gamification-analysis/economy-design-sources-sinks-confidence/ (yalnız arama özeti)
35. https://medium.com/@msahinn21/designing-game-economies-inflation-resource-management-and-balance-fa1e6c894670 (yalnız arama özeti)
36. https://metavert.io/game-economy-design (yalnız arama özeti)
37. https://thewalrus.ca/?p=47662 (yalnız arama özeti)
38. https://www.sportskeeda.com/mobile-games/brawl-stars-season-34-brawl-pass-cost-rewards (yalnız arama özeti)
39. https://clutchpoints.com/gaming/all-brawl-stars-brawl-pass-rewards-for-season-50 (yalnız arama özeti)
40. https://schedule.gdconf.com/session/evolve-or-die-how-liveops-scaled-our-indie-hit/914177 (403, arama özeti)
