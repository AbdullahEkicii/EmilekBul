# Araştırma C: Platform Yetenekleri ve Sunucu Tarafı — 2026-10

Tarih: 2026-10-20. Yalnızca araştırma; kod değiştirilmedi. Önceki rapor (`ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md`) tekrar edilmedi. Etiketler: **[B]** birincil kaynak (resmi doküman/pub.dev), **[İ]** ikincil, **[GÇ]** geliştirici çıkarımı (kaynaksız yorum). Pub.dev sayfaları "X gün önce" göreli tarihle okundu; kesin takvim tarihi yok. Proje durumu `pubspec.yaml` ve `android/app/build.gradle.kts` dosyalarından okundu (salt okuma).

**Projedeki mevcut durum (okunan):** `firebase_core: 4.13.0` (sabit), `firebase_auth ^6.0.0`, `cloud_firestore ^6.0.0`, `firebase_app_check ^0.4.5+2`, `firebase_remote_config ^6.5.6`, `google_generative_ai ^0.4.7`, `games_services ^4.0.0`, `workmanager ^0.9.2`, `flutter_local_notifications ^19.4.0`; `targetSdk = 36`, `compileSdk = 36`, `minSdk = 26`, AGP 8.7.3, `ndkVersion 27.0.12077973`.

---

## 1) Özet (15 madde)

1. **Cloud Functions dağıtımı Blaze planı gerektirir**; Spark'ta yalnızca emülatörde çalışır. Blaze'de 2M çağrı/ay ücretsiz, sonrası 1M için 0,40$. [B] https://firebase.google.com/docs/functions/get-started ; https://firebase.google.com/pricing
2. **FCM, A/B Testing, Personalization, In-App Messaging, App Check: "no-cost"**; Remote Config için **1 Eylül 2026'dan itibaren günde 100.000 fetch ücretsiz**, üstü ücretli (Spark'ta aşımda 30 gün tolerans sonra kısıtlama). Mevcut projeler için geçiş: Spark 1 Aralık 2026, Blaze 1 Şubat 2027'de faturalama. [B] https://firebase.google.com/docs/remote-config/pricing
3. **Sürüm uyumu (pin ile): `firebase_messaging 16.5.0` (core `^4.13.0`) ve `cloud_functions 6.3.6` (core `^4.13.0`) pub.dev bağımlılık sayfalarında core 4.13.0 ile uyumlu görünüyor.** Daha yeni 16.7.0 / 6.4.0 core `^4.14.0` ister (pini bozar); 17.0.0 / 7.0.0 core 5.x ister. [B] https://pub.dev/packages/firebase_messaging/versions/16.5.0 ; https://pub.dev/packages/cloud_functions/versions/6.3.6
4. **`firebase_ai 3.15.0` core `^4.13.0`, `firebase_auth ^6.5.7`, `firebase_app_check ^0.4.6` ister** — pin ile teorik uyumlu, ama projedeki auth/app_check çözümlenen sürümleri bunun üstünde olmalı (doğrulanamadı: kilit dosyası okunmadı). `firebase_ai 4.0.0` core `^4.14.0` ister (pini bozar). [B] https://pub.dev/packages/firebase_ai/versions/3.15.0
5. **Firebase AI Logic için App Check zorlaması 2 Kasım 2026'dan itibaren zorunlu**; kapatılamaz. Gemini Developer API anahtarı sunucuda kalır, uygulamaya gömülmez; kullanıcı başına varsayılan limit 100 RPM. [B] https://firebase.google.com/docs/ai-logic/faq-and-troubleshooting
6. **Gemini API dokümanı açıkça "anahtarı istemci kodunda tutma, sunucu proxy kullan" der**; projedeki gömülü anahtar bu rehbere aykırı. [B] https://ai.google.dev/gemini-api/docs/api-key
7. **Firebase Dynamic Links 25 Ağustos 2025'te kapandı** (linkler 404, `.page.link` yok). Resmi alternatifler: App Links + 3. parti sağlayıcılar. [B] https://firebase.google.com/support/dynamic-links-faq
8. **Hedef API 36 zorunluluğu 31 Ağustos 2026'da başladı** (uzatma 1 Kasım 2026'ya kadar istenebilir); proje zaten `targetSdk = 36`. 36'da edge-to-edge opt-out kaldırıldı. [B] https://support.google.com/googleplay/android-developer/answer/11926878 ; https://developer.android.com/about/versions/16/behavior-changes-16
9. **16 KB sayfa boyutu: Play'de 1 Şubat 2027'den itibaren uyumsuz güncelleme yayınlanamaz** (API 35+ hedefleyenler). AGP ≥8.5.1 gerekli; NDK r28+ varsayılan hizalı. Projede AGP 8.7.3 var; NDK 27 yalnız kendi native kodunuz varsa sorun (Flutter eklentilerinin `.so` hizası doğrulanmalı). [B] https://developer.android.com/guide/practices/page-sizes
10. **In-app updates (esnek/anında)**: Android 5+, yalnız Play'den kurulu uygulamada; `in_app_update 5.0.0` yalnız `flutter` bağımlılığı → sürüm çatışma riski çok düşük. [B] https://developer.android.com/guide/playcore/in-app-updates ; https://pub.dev/packages/in_app_update
11. **Play Install Referrer kütüphanesi 2.2**: referrer 90 gün erişilebilir, yalnızca ilk çalıştırmada bir kez çağrılır — davet atfı için resmi yol. Flutter sarmalayıcı paketi doğrulanmadı. [B] https://developer.android.com/google/play/installreferrer/library
12. **Güvenilir ödül mantığı:** Admin SDK istemci kurallarını atlar; Firestore kurallarında istemci yazımını kapatıp (deny) ödülü Cloud Functions (callable + `enforceAppCheck`) ile vermek resmi mimariyle örtüşür. [B] https://firebase.google.com/docs/firestore/security/get-started ; https://firebase.google.com/docs/app-check/cloud-functions
13. **Play Integrity: günde 10.000 istek varsayılan kota (tüm kurulumlar toplamı)**; App Check Play Integrity sağlayıcısı için Play Console'da bulut projesi bağlama (Owner) ve SHA-256 kaydı şart. [B] https://developer.android.com/google/play/integrity/overview ; https://firebase.google.com/docs/app-check/android/play-integrity-provider
14. **Ana ekran widget'ı:** `home_widget 0.10.0` (core bağımlılığı yok), etkileşimli widget'lar Dart kodu çağırabilir; widget yerel yazılır. Resmi sayfa Glance'ı önerir. [B] https://pub.dev/packages/home_widget ; https://developer.android.com/develop/ui/views/appwidgets/overview
15. **Data safety formu SDK'ların topladığı veriyi de kapsar** (Crashlytics, Analytics, AdMob dahil sorumluluk geliştiricide); yeni SDK (FCM, in_app_update, install referrer) eklenince formu güncellemek gerekir. [B] https://support.google.com/googleplay/android-developer/answer/10787469

---

## 2) Bulgular

### 2.1 Sunucu taraflı geri çağırma (Cloud Functions 2. nesil + FCM)

**Zamanlanmış fonksiyon.** `onSchedule("every day 00:00", ...)` ile Cloud Scheduler tetikler; cron söz dizimi desteklenir; dağıtım otomatik scheduler işi + HTTP fonksiyonu oluşturur; çalıştırmalar çakışabilir (idempotent yazılmalı). Cloud Scheduler işi 0,10$/ay, hesap başına 3 iş ücretsiz. Cloud Scheduler API etkin olmalı. Sayfada `timeZone` seçeneği geçmiyor → doğrulanamadı. [B] https://firebase.google.com/docs/functions/schedule-functions

**Blaze ve fiyat.** Fonksiyon dağıtımı Blaze ister; Node.js 20 ve 22 tam destekli (18 kullanımdan kalktı). Fiyat sayfasında 2M çağrı/ay ücretsiz, sonra 0,40$/milyon; Spark'ta "uygulanamaz". GB-saniye/GHz-saniye kalemlerine ait ayrıntı bu araştırmada çekilemedi (`/docs/functions/pricing` 404) → doğrulanamadı. [B] https://firebase.google.com/docs/functions/get-started ; https://firebase.google.com/pricing

**FCM gönderim.** Admin SDK ile tek cihaza (FID/token), konuya veya listeye gönderilir; `sendEach` ve `sendEachForMulticast` çağrı başına en çok 500. Doküman artık FID'yi önerir, kayıt tokenını "deprecated" olarak anar — Flutter paketinin FID desteği doğrulanmadı. [B] https://firebase.google.com/docs/cloud-messaging/send/admin-sdk

**Konu (topic) ve token karşılaştırması.**
- Konu: cihaz başına en fazla 2.000 konu; abonelik ekleme/çıkarma 3.000 QPS/proje; toplu abonelik istek başına 1.000; proje başına 1.000 eşzamanlı fanout; "gecikme değil verim için optimize"; herkese açık bilgi (hava durumu gibi) için uygun. Kişisel/hızlı teslim için token/FID önerilir. [B] https://firebase.google.com/docs/cloud-messaging/android/topic-messaging
- Token yaşam döngüsü: ~1 ay bağlanmayan kayıt "stale"; Android'de 270 gün hareketsizlikte silinir; her tokenı zaman damgasıyla sunucuda tut, `UNREGISTERED`(404) alınca sil, günlük temizlik işi çalıştır. [B] https://firebase.google.com/docs/cloud-messaging/manage-tokens
- TTL 0–28 gün (varsayılan 4 hafta); collapse key aynı tür bekleyen mesajı değiştirir; 1 aydan uzun bağlanmayan Android cihaza yeni mesaj kabul edilir ama anında atılır → **uzun süredir gelmeyen kullanıcıya FCM ile geri çağırma çalışmaz**. [B] https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan
- [GÇ] Segment için sunucu işi: Firestore'da `lastActiveAt` / `fcmTokenUpdatedAt` tutup günlük zamanlanmış fonksiyonla 1–7 gün hareketsiz kullanıcılara gönderim; ölçek için yük zamana yayılmalı (önceki rapor: scale-fcm).

**Flutter tarafı.** Android 13+ için `requestPermission`; arka plan işleyicisi üst düzey fonksiyon + `@pragma('vm:entry-point')`, ayrı isolate'ta çalışır, 30 sn üstü işte süreç öldürülebilir; ön planda bildirim göstermek için yüksek öncelikli kanal gerekir. [B] https://firebase.google.com/docs/cloud-messaging/flutter/receive

**Bildirim kanalları.** Android 8+ kanal zorunlu; önem düzeyi oluşturulduktan sonra kod ile değiştirilemez (kullanıcı değiştirir); kanal silmek ayarlarda silinen sayı olarak görünür → kanal kimlikleri/önem düzeyi baştan doğru seçilmeli (ör. "günlük hatırlatma" = düşük/orta, "düello daveti" = yüksek). [B] https://developer.android.com/develop/ui/views/notifications/channels

**Firebase In-App Messaging (FIAM).** Kart/banner/modal/görsel; Analytics ve içe aktarılan segmentlerle hedefleme. `firebase_in_app_messaging 0.10.0` core `^5.0.0` ister → **core 4.13.0 pini ile uyumsuz**; eski sürümün (core ^4.x) uyumu doğrulanmadı. Android/iOS desteği var. [B] https://firebase.google.com/docs/in-app-messaging ; https://pub.dev/packages/firebase_in_app_messaging

**Remote Config + Personalization.** Personalization, ML ile parametre başına kişiye en iyi seçeneği seçer; en az iki alternatif Remote Config parametresi ve Analytics ile ölçülebilir hedef gerekir; holdout grubuyla kıyaslar. Veri eşiği/minimum kullanıcı sayısı sayfada verilmemiş → doğrulanamadı. Küçük kullanıcı tabanında A/B Testing daha öngörülebilir [GÇ]. Remote Config varsayılan minimum fetch aralığı 12 saat; Flutter SDK ≥4.0.0'dan beri `onConfigUpdated` ile gerçek zamanlı güncelleme (Web hariç); aşırı fetch kısıtlanır. [B] https://firebase.google.com/docs/remote-config/personalization ; https://firebase.google.com/docs/remote-config/flutter/get-started

**A/B Testing + audience + churn.** A/B deneyi Analytics ister; hedefte "User audience" kuralı Analytics kitlelerini kullanır (kitleye girişte gecikme olabilir); `notification_receive`/`notification_dismiss` metrikleri yalnız Android ve Notifications composer'dan. FCM mesaj denemesi sayfası okunamadı → doğrulanamadı. [B] https://firebase.google.com/docs/ab-testing/abtest-config
Churn olasılığı: "son 7 günde aktif kullanıcının sonraki 7 günde aktif olmama olasılığı"; uygunluk için 28 günün içinde 7 günlük dönemde en az 1.000 geri dönen ve 1.000 dönmeyen kullanıcı gerekir; kalite düşerse tahmin durur → **küçük/orta DAU'lu uygulamada büyük olasılıkla uygun olmayacak** [GÇ]. [B] https://support.google.com/analytics/answer/9846734

**Maliyet özeti.** FCM, A/B Testing, Personalization, In-App Messaging, App Check: "no-cost" (App Check için sağlayıcıya bağlı kota); Firebase AI Logic SDK ücretsiz, Gemini kullanımı ayrı faturalanır; Remote Config 100.000 fetch/gün sonrası ücretli (yukarıda). [B] https://firebase.google.com/pricing ; https://firebase.google.com/docs/remote-config/pricing

**Sürüm uyumu tablosu (pub.dev bağımlılık sayfalarından):**

| Paket | core 4.13.0 ile uyumlu en yeni sürüm | Notlar |
|---|---|---|
| firebase_messaging | 16.5.0 (`^4.13.0`) | 16.6.0/16.7.0 core ^4.14.0 ister (16.7.0 doğrulandı; 16.6.0 doğrulanmadı); 17.0.0 core ^5.0.0 |
| cloud_functions | 6.3.6 (`^4.13.0`) | 6.4.0 `^4.14.0`; 7.0.0 core 5 + BoM 35 |
| firebase_remote_config | 6.5.6 (projede) | 6.6.0+ muhtemelen core ^4.14.0 (doğrulanmadı) |
| firebase_ai | 3.15.0 (`^4.13.0`, auth ^6.5.7, app_check ^0.4.6) | 4.0.0 core ^4.14.0; 5.0.0 core ^5.0.0 |
| firebase_in_app_messaging | doğrulanamadı | 0.10.0 core ^5.0.0 |

Kaynaklar: https://pub.dev/packages/firebase_messaging/versions/16.5.0 ; https://pub.dev/packages/firebase_messaging/versions/16.7.0 ; https://pub.dev/packages/cloud_functions/versions/6.3.6 ; https://pub.dev/packages/cloud_functions/versions/6.4.0 ; https://pub.dev/packages/firebase_ai/versions/3.15.0 ; https://pub.dev/packages/firebase_ai/versions/4.0.0 ; https://pub.dev/packages/firebase_core/versions ; https://pub.dev/packages/firebase_remote_config/versions
Not [GÇ]: pub.dev sürüm listesi göreli tarih veriyor; core 4.13.0 "2 ay önce", messaging 16.5.0 "2 ay önce" olduğundan eşleşme tutarlı. Zincir etkisi (messaging 16.5.0'ın `firebase_messaging_platform_interface` vb. çözümlemesi, `firebase_auth`/`cloud_firestore` ile ortak `firebase_core_platform_interface` kısıtları) `flutter pub get` ile doğrulanmadan kesin sayılmamalı.

### 2.2 Güvenlik / anti-hile

**İstemci güvenilmez.** Her Firestore isteği kurallara karşı değerlendirilir; varsayılan red; sunucu istemci kitaplıkları (Admin SDK) kuralları atlar, onları IAM korur. Koşullarda `request.resource.data` ile alan doğrulama, `resource.data` ile mevcut veri karşılaştırma, `exists()/get()` (istek başına 10 çağrı, reddedilse de ücretli) kullanılır; "kurallar filtre değildir". `request.time` ve zaman damgalı hız sınırlaması bu sayfada geçmiyor → kurallar referansına bakılmalı. [B] https://firebase.google.com/docs/firestore/security/get-started ; https://firebase.google.com/docs/firestore/security/rules-conditions ; https://firebase.google.com/docs/firestore/security/rules-structure
[GÇ] Önerilen mimari: jeton/puan/ödül alanlarını (`coins`, `streak`, `referralCredits`) kurallarla istemci yazımına kapat (`allow write: if false` ya da yalnız güvenli alanlara izin); ödülü `onCall` fonksiyonu Admin SDK ile versin (sunucu `serverTimestamp`, günlük tek sefer kontrolü, idempotency anahtarı).

**Callable + App Check.** 2. nesil `onCall` içinde `enforceAppCheck: true`; `request.auth` Auth tokenını, `request.app` doğrulanmış uygulamayı verir; `consumeAppCheckToken: true` ile tek kullanımlık (replay) koruması (beta, yalnız Node.js, ek gecikme); IAM rolü "Firebase App Check Token Verifier" gerekir. İstemcide sınırlı kullanımlı token seçeneği Swift/Kotlin/Java/Web için gösterilmiş; **Flutter paketinde sınırlı kullanım desteği doğrulanamadı**. [B] https://firebase.google.com/docs/app-check/cloud-functions ; https://firebase.google.com/docs/functions/callable

**App Check ve Play Integrity sağlayıcısı.** Play Console > Release > App integrity bölümünde bulut projesini bağla (Owner olmak gerekir); Firebase konsolunda Security > App Check > Apps'te SHA-256 imza parmak izi kaydet (kayıtsız uygulamalar zorlamada engellenir); TTL 30 dk–7 gün (varsayılan 1 saat); varsayılan `PLAY_RECOGNIZED` ister, `LICENSED` istemez. Zorlama etkileşimi 15 dk sürebilir; önce metrikleri izle. Zorlama desteklenen ürünler: AI Logic, Firestore, Storage, Auth, RTDB vb.; Cloud Functions ayrı sayfada. Play Integrity API doğrudan: varsayılan 10.000 istek/gün, kota artışı Play Console'dan istenir; tek savunma değil, "izleme modunda başla", "kademeli zorlama"; standart istek `requestHash` ile içeriğe bağlanır. [B] https://firebase.google.com/docs/app-check/android/play-integrity-provider ; https://firebase.google.com/docs/app-check/enable-enforcement ; https://developer.android.com/google/play/integrity/overview
Proje notu: `firebase_app_check ^0.4.5+2` kullanılıyor; 0.5.0 ile `activate` imzası değişti (`providerAndroid`), ama 0.5.0 core 5 / BoM 35 / minSdk 24 ister (pini bozar). [B] https://pub.dev/packages/firebase_app_check/changelog

**Gemini anahtarını istemciden çıkarma.**
- Seçenek A: Firebase AI Logic (`firebase_ai`). Gemini Developer API ile anahtar gerekmez ("anahtar sunucuda kalır"); App Check zorunlu (2 Kasım 2026'dan itibaren kapatılamaz); kullanıcı başına varsayılan 100 istek/dk (konsolda ayarlanır, tek tek kullanıcıya özel limit yok); proje düzeyi sağlayıcı RPM/TPM/RPD sınırları ayrıca geçerli. Gemini Developer API Spark'ta ücretsiz katmanla başlar, Blaze'de tümü kullandıkça öde; Agent Platform (eski Vertex AI) Gemini API her zaman Blaze ister; $300 deneme kredisi Gemini Developer API'de kullanılamaz; çoğu proje Blaze'de ön ödeme gerektirir. [B] https://firebase.google.com/docs/ai-logic ; https://firebase.google.com/docs/ai-logic/faq-and-troubleshooting ; https://firebase.google.com/docs/ai-logic/pricing ; https://firebase.google.com/docs/ai-logic/quotas
- Seçenek B: Proxy Cloud Function (`onCall`, anahtar Secret Manager'da). Gemini dokümanı bunu doğrudan önerir: "istemcide asla anahtar", ortam değişkeni/Secret Manager, faturalandırma uyarıları, sızdıysa yeni anahtar üret/eskiyi kapat. [B] https://ai.google.dev/gemini-api/docs/api-key
- Mevcut `google_generative_ai ^0.4.7` paketi ile gömülü anahtar: **sızmış sayılması gereken anahtar** [GÇ]; acil adım: anahtarı iptal edip yenisini yalnız sunucuda tutmak. `google_generative_ai` paketinin kullanımdan kalkma durumu bu araştırmada çekilmedi → doğrulanamadı.
- Soru üretimi sunucuda toplu yapılıp Firestore'a yazılabilir (maliyet/kota yönetimi) [GÇ].

**Referral sahtekârlığı.** Resmi bir "referral fraud" rehberi bulunamadı. [GÇ] Sunucu doğrulamalı yaklaşım: davet kodu başına tek kullanım, ödülü yalnız davet edilen kullanıcı ilk anlamlı eylemi (ör. 3 oyun) tamamladığında callable ile ver; aynı cihazda çoklu hesap için Play Integrity `deviceRecall`/`recentDeviceActivity` (beta/opt-in) sinyalleri düşünülebilir [B: sinyaller listesi] https://developer.android.com/google/play/integrity/overview ; Play'in teşvikli kurulum/puanlama politikası bu araştırmada doğrulanamadı (answer/9899234 ve 9898783 yanlış politika sayfasıydı).

### 2.3 Google Play özellikleri

**In-app updates.** Esnek (arka planda indirir, uygulama kullanılabilir) ve anında (tam ekran, güncellemeden devam edilemez); Android 5.0+ (API 21), yalnız telefon/tablet/ChromeOS; APK expansion (.obb) ile uyumsuz; topladığı veri (cihaz metaverisi, sürüm, modüller) Data safety açısından not edilmeli. Doküman sayfasında staleness/priority anlatılmıyor; API'de `clientVersionStalenessDays` ve `updatePriority` olduğu genel bilgi (sayfa bunu "genel bilgi" diye işaretliyor) [İ]. Flutter paketi `in_app_update 5.0.0` (~3 ay önce, yalnız Android, yalnız `flutter` bağımlılığı); yerel test yapılamaz, Play'den (dahili test/dahili uygulama paylaşımı) kurulu olmalı; aksi halde `ERROR_API_NOT_AVAILABLE`. Projede `in_app_review` var; `in_app_update` bağımsız ve çakışma beklenmez [GÇ]. [B] https://developer.android.com/guide/playcore/in-app-updates ; https://pub.dev/packages/in_app_update

**Mağaza deneyleri ve özel mağaza listeleri.** Varsayılan grafik denemesi veya en çok 5 yerelleştirilmiş deneme (aynı anda); en çok 2 varyant; 6 ayda otomatik durur; hedef metrik: benzersiz yükleme/açılış tıklaması; yayınlanmış uygulama gerekir. Özel mağaza listesi: en çok 50; ülke başına tek liste; URL parametresi `&listing=...`; "Ads Traffic" hedefi yalnız AdMob trafiği için. [B] https://support.google.com/googleplay/android-developer/answer/6227309 ; https://support.google.com/googleplay/android-developer/answer/9867158 [GÇ] Küçük kullanıcı tabanında deneyin istatistiksel güveni geç oluşur.

**Install Referrer.** Kütüphane 2.2: `startConnection` → `getInstallReferrer` (referrer URL dizesi, tıklama ve kurulum başlangıç zaman damgası) → `endConnection`; referrer 90 gün erişilebilir, yeniden kurulmadıkça değişmez; yalnız ilk çalıştırmada bir kez çağır. Sayfa referrer dizesinin biçimini belirtmiyor (kendiniz ayrıştırırsınız) ve PII konusunda açıklama yapmıyor → doğrulanamadı. Flutter için paket seçilmedi/doğrulanmadı (pub.dev'de `play_install_referrer` benzeri paketler olabilir, **kontrol edilmedi**). Uygulama içi yerel kanal yazmak da mümkün [GÇ]. [B] https://developer.android.com/google/play/installreferrer/library

**Play Games Services.** v2: platform kimliği PGS yönetir (XP, seviye, streak, başarım), oyun durumunu geliştirici kendi hesabıyla saklar; başarım ve liderlik tablosu var; lig/quest/streak gibi mekanikler "Level Up" programına kayıtlı oyunlarla sınırlı. `games_services` 5.3.0 var; 4.0.0'da Play Games Services 2.0.0'a geçildi; 5.1.0 itibarıyla **Flutter 3.44 / Dart 3.12 gerektirir** → proje Flutter 3.32.7 olduğundan ^4.x'te kalmak mantıklı; 5.0.x'in Flutter şartı doğrulanamadı. [B] https://developer.android.com/games/pgs/overview ; https://pub.dev/packages/games_services ; https://pub.dev/packages/games_services/changelog

**Hedef API takvimi.** 31 Ağustos 2026'dan itibaren yeni uygulama ve güncellemeler API 36 hedeflemeli (mobil); mevcut uygulamalar API 35+ hedeflemezse yeni kullanıcılara, yeni Android sürümlü cihazlarda gösterilmez; uzatma 1 Kasım 2026'ya kadar. Proje `targetSdk = 36`: uyumlu. [B] https://support.google.com/googleplay/android-developer/answer/11926878
API 36 davranışı: edge-to-edge opt-out kaldırıldı; tahminli geri hareketi (predictive back) varsayılan açık (`onBackPressed` artık çağrılmaz); sw≥600dp ekranlarda yön/yeniden boyutlandırma kısıtları yok sayılır (oyun kategorisi `appCategory` istisna). [B] https://developer.android.com/about/versions/16/behavior-changes-16 [GÇ] Flutter 3.32.7'de bunların etkisi gerçek cihazda test edilmeli (özellikle tablet yönlendirmesi, geri tuşu). Flutter'ın resmi 3.27 notu: SystemUiMode varsayılanı edge-to-edge. [B] https://docs.flutter.dev/release/breaking-changes

**16 KB.** Play: API 35+ hedefleyen uygulamalar 64 bit cihazlarda 16 KB sayfayı desteklemeli; 1 Şubat 2027'den itibaren desteklemeyen güncelleme yayınlanamaz. AGP ≥8.5.1 ile sıkıştırılmamış `.so` 16 KB zip hizalı; NDK r28+ varsayılan hizalı, r27 ve altı için `-Wl,-z,max-page-size=16384`. Kontrol: `zipalign -c -P 16 -v 4`, `bundletool dump config` ile `PAGE_ALIGNMENT_16K`, 16 KB emülatör. Android sayfası Flutter'ı kapsamıyor; Flutter motoru hizası için resmi kaynak bulunamadı, üçüncü taraf bloglar "3.22+" ve "3.32+" gibi çelişkili söylüyor [İ] https://www.appsonair.com/blogs/16-kb-page-size-support-for-flutter → **doğrulanamadı**; AAB'yi derleyip kontrol komutlarıyla doğrulamak gerekir. [B] https://developer.android.com/guide/practices/page-sizes

**Android 14/15 kısıtları.** API 35+ hedefte `dataSync`/`mediaProcessing` FGS 24 saatte toplam 6 saat; `BOOT_COMPLETED` alıcıları bazı FGS türlerini başlatamaz; edge-to-edge zorunlu; arka plandan FGS başlatma Android 12+ hedefte yasak (listelenmiş istisnalar dışında). Bunlar önceki rapordaki FGS bulgusunu doğrular; ek kural: API 35'te `elegantTextHeight` varsayılan `true` (Arapça/Tayca/Hintçe metinlerde yerleşim değişebilir — projede 25+ dil var [GÇ: ar, th, hi, ko vb. çevirileri var]). [B] https://developer.android.com/about/versions/15/behavior-changes-15 ; https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start

**Play Asset Delivery / boyut.** PAD oyun varlıklarını (200 MB üstü) Play'e barındırır; install-time/fast-follow/on-demand; Flutter için resmi yol yok (Java/Kotlin veya native). Projede 48+ avatar JPG ve 28 dil dosyası var; boyut sorunu varsa önce AAB analizi (Play Console "app size"/Android Studio APK Analyzer) yapılmalı [GÇ]. Sayfa 1,5 GB ve 200 MB temel modül sınırlarını vermiyor → doğrulanamadı. [B] https://developer.android.com/guide/app-bundle/asset-delivery

**Data safety.** Tüm yayımlanmış (kapalı/açık/üretim) uygulamalar formu tamamlamalı; SDK/kütüphanelerin topladığı/paylaştığı veri de beyan edilir (Google Play SDK Index'e bakılması önerilir); yanlış beyan engel/kaldırma doğurabilir; amaçlar arasında analiz, reklam, hata önleme/güvenlik, kişiselleştirme var. Crashlytics/Analytics/AdMob için tek tek hangi veri türünün işaretleneceği bu araştırmada çıkarılamadı (SDK sağlayıcı rehberleri okunmadı) → doğrulanamadı. [B] https://support.google.com/googleplay/android-developer/answer/10787469

### 2.4 Paylaşım / büyüme altyapısı

- **Firebase Dynamic Links kapandı:** 25 Ağustos 2025; tıklanan bağlantılar 404; Short Links/Link Stats API'leri 400/403 döner; `.page.link` alan adları kullanılamaz. Resmi öneri: tam eşdeğerlik için üçüncü taraf (Adjust, Airbridge, AppsFlyer, Bitly, Branch, Kochava, Singular — Google doğrulamamış), yalnız kurulu uygulama için App Links/Universal Links. [B] https://firebase.google.com/support/dynamic-links-faq
- **Android App Links:** manifestte `android:autoVerify="true"` + `https` kapsamı; sunucuda `https://alanadi/.well-known/assetlinks.json`; sistem Android 6+ kurulumda her ana bilgisayar adını doğrular; Android 15+ arka planda periyodik yeniden doğrulama (değişiklik 7 güne kadar yayılabilir), Android 14 ve altı yalnız kurulum/güncelleme. `assetlinks.json` şeması ve Play App Signing'de **uygulama imzalama anahtarı** parmak izi bilgisi sayfada "genel bilgi" olarak işaretli [İ]; doğrulama komutları sayfada (`adb shell pm get-app-links`). [B] https://developer.android.com/training/app-links/verify-android-applinks
- **Uygulama bağlantısı karşılama:** `app_links 7.2.2` (~13 gün önce, `uriLinkStream`); Android kurulumu paket README'sinde (okunmadı); Flutter min sürümü sayfada yok → doğrulanamadı. [B] https://pub.dev/packages/app_links
- **Önemli sınırlama [GÇ]:** App Links yalnız uygulama kuruluyken açar; kurulu değilse web sayfasına düşer. "Davet → Play'e → kurulum → atıf" zinciri için Install Referrer gerekir: davet web sayfası Play URL'sine `&referrer=invite_<kod>` ekler (Play URL `referrer` parametresi bu araştırmada resmi sayfadan doğrulanmadı), uygulama ilk açılışta referrer'ı okuyup kodu sunucuya gönderir. Kod hesabı ödül için sunucuda doğrulanmalı (bkz. 2.2).
- **Alan adı gereksinimi:** App Links bir web sitesi gerektirir (ör. Firebase Hosting); proje web sitesi/alan adı durumu bilinmiyor.
- **Paylaşım kartı:** `share_plus ^12.0.2` projede var (paylaşım menüsü); görsel kart üretimi ayrıca araştırılmadı → doğrulanamadı.

### 2.5 Android ana ekran widget'ı

- `home_widget 0.10.0` (~32 gün önce): veri `saveWidgetData` + `updateWidget`; "Dart kodu çağıran etkileşimli widget" listeli; bağımlılıklar `path_provider`, `path_provider_foundation`; Flutter/Dart minimum sürümü sayfada yok → doğrulanamadı. [B] https://pub.dev/packages/home_widget
- Android dokümanı: Compose ile Glance önerilir; boyut kovaları (size bucket), Android 12+ yapılandırma seçenekleri; yerel güncelleme süresi/pil bilgisi bu sayfada yok. `updatePeriodMillis` ≥30 dk genel bilgi (sayfa "genel bilgi" diyor) [İ]; sık güncelleme için uygulama içinden/WorkManager ile tetikle. [B] https://developer.android.com/develop/ui/views/appwidgets/overview
- [GÇ] Projede yerel Kotlin/XML (veya Glance) kodu yazılacağı, AGP 8.7.3 + Kotlin/Compose sürümü uyumu kontrol edilmeli (Glance bağımlılığı eklenirse Compose derleyici ayarı gerekebilir). Bildirimle karşılaştırıldığında ana ekranda "seri: N gün" görünürlüğü sağlar ama kullanıcı widget'ı kendisi eklemeli (önceki rapor: Play kuralı).

---

## 3) Uygulanabilirlik tablosu

| Öneri | Uygulanabilirlik (bu proje) | Efor | Risk | Maliyet | Bağımlılık sürüm uyumu notu |
|---|---|---|---|---|---|
| Gemini anahtarını istemciden çıkar: önce `onCall` proxy fonksiyonu | Yüksek (öncelik 1; anahtar gömülü) | M | Orta: Blaze'e geçiş, gecikme, kota | Blaze; fonksiyon 2M çağrı/ay ücretsiz; Gemini kullanım ücreti | `cloud_functions 6.3.6` (core ^4.13.0) uyumlu görünüyor; `^6.4.0` pini bozar |
| Alternatif: `firebase_ai` ile Gemini Developer API + App Check | Yüksek ama mevcut `google_generative_ai` kodunu değiştirir | M | Orta: App Check zorlaması 2 Kas 2026; auth ≥6.5.7 şartı | Spark'ta ücretsiz katman, Blaze'de kullandıkça öde | `firebase_ai 3.15.0` core ^4.13.0 ama auth ^6.5.7 / app_check ^0.4.6 ister; kilit dosyasıyla doğrulanmadı |
| Firestore kuralları: ödül/jeton alanlarını istemci yazımına kapat, ödülü callable ile ver | Yüksek (ekonomi/lig/davet için şart) | M–L | Orta: mevcut istemci yazma yollarını bozabilir; emülatörle test | Blaze; kural/function maliyeti düşük | `cloud_firestore ^6.0.0` ile kural değişikliği paket gerektirmez |
| App Check zorlaması (Firestore + Functions) + SHA-256 + Play Console bağlama | Yüksek | S–M | Orta: yanlış zorlama gerçek kullanıcıyı engeller; önce metrik izle | Ücretsiz (kota sağlayıcıya bağlı; Play Integrity 10.000/gün) | `firebase_app_check ^0.4.5+2` mevcut; 0.5.0 core 5 ister |
| FCM sunucu bildirimi (düello daveti, günlük hatırlatma, geri dönüş) + token yönetimi | Yüksek | M | Orta: izin oranı, 1 ay+ hareketsizde ulaşmama | FCM ücretsiz; fonksiyon Blaze | `firebase_messaging 16.5.0` (core ^4.13.0) — pin ile uyumlu görünüyor; 16.6+ pini bozar |
| Zamanlanmış Cloud Function (günlük segment gönderimi) | Orta–yüksek | M | Düşük–orta: çakışan çalıştırma, ölçek | Blaze; scheduler 3 iş ücretsiz, sonra 0,10$/iş/ay | `cloud_functions` gerekmez (yalnızca sunucu) |
| In-app updates (esnek) | Yüksek | S | Düşük | Ücretsiz | `in_app_update 5.0.0` yalnız `flutter` bağımlılığı: çatışma riski çok düşük |
| Hedef API 36 / edge-to-edge / predictive back / 16 KB doğrulaması | Zorunlu | S–M | Orta: tablet/geri tuşu davranışı; `.so` hizası | Yok | Kontrol edilecek: AGP 8.7.3 ≥8.5.1 tamam; NDK 27 (kendi native kodu varsa bayrak); plugin `.so` hizası doğrulanamadı |
| Play mağaza deneyleri + özel listeler | Orta (trafiğe bağlı) | S | Düşük | Ücretsiz | Kod bağımlılığı yok |
| Install Referrer ile davet atfı | Orta (davet özelliği varsa) | M | Orta: Flutter paketi/yerel kanal belirsiz; sahtecilik | Ücretsiz | Flutter sarmalayıcı sürümü doğrulanamadı |
| App Links (`assetlinks.json`) + `app_links` | Orta (alan adı gerekli) | M | Düşük–orta: parmak izi (Play App Signing) hatası | Alan adı/hosting (Hosting ücretsiz katmanı bu araştırmada doğrulanmadı) | `app_links 7.2.2` min Flutter sürümü doğrulanamadı |
| Firebase In-App Messaging | Düşük–orta | S (ama bağımlılık sorunlu) | Orta | Ücretsiz | `firebase_in_app_messaging 0.10.0` core ^5.0.0 → pin ile **uyumsuz**; eski sürüm doğrulanamadı |
| Remote Config Personalization / A/B Testing | Orta (A/B: yüksek, Personalization: düşük–orta) | S | Düşük | Ücretsiz; RC 100.000 fetch/gün sonrası ücretli | `firebase_remote_config 6.5.6` projede |
| Churn tahmini / öngörü kitlesi | Düşük (1.000+1.000 kullanıcı eşiği) | S | Düşük | Ücretsiz | Analytics gerekir |
| Ana ekran widget'ı (`home_widget`) | Orta | L (yerel Kotlin + Glance/XML) | Orta: Kotlin/Compose derleme, sınırlı güncelleme | Ücretsiz | `home_widget 0.10.0` Flutter min sürümü doğrulanamadı |
| Play Games Services (başarım/liderlik) | Orta (paket zaten var) | M | Düşük–orta | Ücretsiz | `games_services` 5.1.0+ Flutter 3.44 ister → ^4.x'te kal; 5.0.x doğrulanamadı |
| Play Asset Delivery | Düşük | L | Orta | Ücretsiz | Flutter ile resmi yol yok |
| Data safety güncellemesi (yeni SDK eklenince) | Zorunlu | S | Yüksek (yanlış beyan → ret/kaldırma) | Yok | — |

---

## 4) Önerilen sıra

1. **Hemen:** Gömülü Gemini anahtarını iptal et/yenile; proxy `onCall` (Secret Manager) veya `firebase_ai` hazırlığı. Gerekçe: Gemini dokümanı gömülü anahtarı açıkça yasaklar; AI Logic için App Check 2 Kasım 2026'da zorunlu.
2. **Hemen:** Play hedefleri doğrula: API 36 zaten tamam; AAB için 16 KB hizalama (zipalign/bundletool) kontrolü; edge-to-edge/predictive back test. (Uzatma son tarihi 1 Kasım 2026 yakın; 16 KB son tarih 1 Şubat 2027.)
3. **Kısa vade:** Firestore kurallarını sertleştir (ekonomi alanlarını istemci yazımına kapat) + ödül callable'ları + App Check zorlaması (önce izleme).
4. **Kısa vade:** In-app updates (S) ve Data safety formunu güncel SDK listesiyle gözden geçirme.
5. **Orta vade:** `firebase_messaging 16.5.0` + `cloud_functions 6.3.6` ekleme (pini bozmadan, `flutter pub get` ile doğrula) → düello daveti/günlük hatırlatma, ardından zamanlanmış segment fonksiyonu.
6. **Orta vade:** A/B Testing ile mekanik denemeleri; mağaza deneyleri.
7. **Davet özelliği planlanırsa:** App Links + Install Referrer + sunucu doğrulamalı ödül.
8. **Son:** Ana ekran widget'ı (L), PGS başarım/lig (opsiyonel), FIAM/Personalization/churn (veri/uyumluluk nedeniyle düşük öncelik).

---

## 5) Doğrulanamayanlar

- Flutter 3.32.7 motorunun `.so` dosyalarının 16 KB hizası (resmi Flutter kaynağı bulunamadı; bloglar çelişkili).
- `firebase_ai 3.15.0` için projede çözümlenen `firebase_auth`/`firebase_app_check` sürümlerinin şartı karşılayıp karşılamadığı (`pubspec.lock` okunmadı).
- `firebase_messaging 16.6.0` core şartı; `firebase_in_app_messaging`'ın core ^4.x ile uyumlu sürümü; `firebase_remote_config 6.6.0+` core şartı.
- Flutter için Play Install Referrer paketi (seçilmedi/okunmadı), Play URL `referrer` parametresi biçimi, referrer içeriğinde PII durumu.
- Callable/App Check sınırlı kullanımlı token'ın Flutter istemcisinde desteği.
- Cloud Functions ayrıntılı fiyatlama (GB-sn, GHz-sn; `/docs/functions/pricing` 404), `onSchedule` `timeZone` seçeneği.
- Remote Config Personalization'ın veri eşikleri/platform desteği; A/B Testing ile FCM mesaj denemesi sayfası.
- FCM'de FID ile gönderimin Flutter `firebase_messaging` 16.x'te kullanılabilirliği.
- Firestore `request.time` ve zaman damgalı hız sınırlama kuralı ayrıntıları; Admin SDK `serverTimestamp` kullanımı (kurallar referansı okunmadı).
- Play'in teşvikli kurulum/puanlama/referans ödülü politikası metni (çekilen iki sayfa yanlış politikaydı).
- Crashlytics/Analytics/AdMob için Data safety'de işaretlenecek veri türleri (SDK sağlayıcı rehberleri okunmadı).
- Referral sahtekârlığı için birincil rehber bulunamadı.
- `home_widget`, `app_links`, `workmanager` Flutter/Dart minimum sürümleri; Android widget `updatePeriodMillis` alt sınırı (resmi sayfada yok).
- `google_generative_ai` paketinin kullanımdan kalkma durumu.
- Play Asset Delivery boyut sınırları (200 MB/1,5 GB sayfada yok).
- Predictive back/edge-to-edge'in Flutter 3.32.7 üzerindeki gerçek cihaz etkisi (yalnız Android dokümanları okundu).

---

## 6) Kaynak listesi

Birincil [B]
1. https://firebase.google.com/pricing
2. https://firebase.google.com/docs/remote-config/pricing
3. https://firebase.google.com/docs/functions/get-started
4. https://firebase.google.com/docs/functions/schedule-functions
5. https://firebase.google.com/docs/functions/callable
6. https://firebase.google.com/docs/cloud-messaging/android/topic-messaging
7. https://firebase.google.com/docs/cloud-messaging/manage-tokens
8. https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan
9. https://firebase.google.com/docs/cloud-messaging/flutter/receive
10. https://firebase.google.com/docs/cloud-messaging/send/admin-sdk
11. https://firebase.google.com/docs/in-app-messaging
12. https://firebase.google.com/docs/remote-config/personalization
13. https://firebase.google.com/docs/remote-config/flutter/get-started
14. https://firebase.google.com/docs/ab-testing/abtest-config
15. https://support.google.com/analytics/answer/9846734
16. https://firebase.google.com/docs/firestore/security/get-started
17. https://firebase.google.com/docs/firestore/security/rules-structure
18. https://firebase.google.com/docs/firestore/security/rules-conditions
19. https://firebase.google.com/docs/app-check/android/play-integrity-provider
20. https://firebase.google.com/docs/app-check/enable-enforcement
21. https://firebase.google.com/docs/app-check/cloud-functions
22. https://firebase.google.com/docs/ai-logic
23. https://firebase.google.com/docs/ai-logic/faq-and-troubleshooting
24. https://firebase.google.com/docs/ai-logic/pricing
25. https://firebase.google.com/docs/ai-logic/quotas
26. https://firebase.google.com/docs/ai-logic/get-started?api=dev
27. https://ai.google.dev/gemini-api/docs/api-key
28. https://firebase.google.com/support/dynamic-links-faq
29. https://developer.android.com/google/play/integrity/overview
30. https://developer.android.com/guide/playcore/in-app-updates
31. https://developer.android.com/guide/practices/page-sizes
32. https://developer.android.com/google/play/installreferrer/library
33. https://developer.android.com/about/versions/16/behavior-changes-16
34. https://developer.android.com/about/versions/15/behavior-changes-15
35. https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
36. https://developer.android.com/develop/ui/views/notifications/channels
37. https://developer.android.com/training/app-links/verify-android-applinks
38. https://developer.android.com/develop/ui/views/appwidgets/overview
39. https://developer.android.com/games/pgs/overview
40. https://developer.android.com/guide/app-bundle/asset-delivery
41. https://support.google.com/googleplay/android-developer/answer/11926878
42. https://support.google.com/googleplay/android-developer/answer/6227309
43. https://support.google.com/googleplay/android-developer/answer/9867158
44. https://support.google.com/googleplay/android-developer/answer/10787469
45. https://docs.flutter.dev/release/breaking-changes
46. https://pub.dev/packages/firebase_core/versions
47. https://pub.dev/packages/firebase_messaging/versions/16.5.0 ; https://pub.dev/packages/firebase_messaging/versions/16.7.0 ; https://pub.dev/packages/firebase_messaging/changelog
48. https://pub.dev/packages/cloud_functions/versions/6.3.6 ; https://pub.dev/packages/cloud_functions/versions/6.4.0 ; https://pub.dev/packages/cloud_functions/changelog
49. https://pub.dev/packages/firebase_ai/versions/3.15.0 ; https://pub.dev/packages/firebase_ai/versions/4.0.0
50. https://pub.dev/packages/firebase_app_check/changelog
51. https://pub.dev/packages/firebase_remote_config/versions
52. https://pub.dev/packages/firebase_in_app_messaging
53. https://pub.dev/packages/in_app_update
54. https://pub.dev/packages/app_links
55. https://pub.dev/packages/home_widget
56. https://pub.dev/packages/games_services ; https://pub.dev/packages/games_services/changelog

İkincil [İ]
- https://www.appsonair.com/blogs/16-kb-page-size-support-for-flutter (arama sonucu özeti; sayfa okunmadı, yalnızca Flutter 16 KB sürüm çelişkisini göstermek için)
