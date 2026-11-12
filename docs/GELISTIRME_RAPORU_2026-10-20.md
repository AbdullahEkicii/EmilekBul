# Emilekbul / Trivia Quiz — Geliştirme ve Güzelleştirme Raporu

**Dönem:** 2026-10-02 → 2026-10-20  
**Sürüm:** 1.5.24+52 → **1.5.26+54** (release AAB hazır, imzalı, 59,6 MB)  
**Durum:** `f565068` commit'inden sonra **109 dosya değişti, 6 yeni dosya** var; henüz commit edilmedi.  
**Test ortamı:** Android emülatörü (Pixel 8, API 33, swiftshader, **debug** derleme). Gerçek cihaz ölçümü yok.

> Bu rapor üç şeyi ayırır: **ölçülen** (sayı var), **cihazda görülen** (emülatörde denendi) ve **yalnızca kodla doğrulanan** (derlendi ama çalıştırılıp görülmedi). Doğrulanmayan hiçbir şey "çalışıyor" diye yazılmadı.

---

## 1. Yönetici özeti

| Alan | Önce | Sonra | Kanıt |
|---|---|---|---|
| Avatar bellek yükü (52 görsel, çözülmüş) | ~706 MB | ~25 MB | Pillow ile piksel boyutlarından hesaplandı |
| Avatar disk boyutu | 5,2 MB | 1,0 MB | `du` |
| Test başına etkileşimsiz bekleme (5 soru) | ~24 sn | ~9 sn | Koddaki süreler toplandı |
| Splash | 3,5 sn sabit | 1,3 sn (+ en fazla 6 sn ağ bekleme) | Emülatörde izlendi |
| Açılış (runApp öncesi / ilk frame) | ölçülmemişti | ~0,9 sn / ~1,2 sn | Logcat `Startup:` satırları |
| Yeni kullanıcı, internet yok | Dil listesine atılıyordu, sonra boş ekran | Ana ekranı görür, arka planda otomatik giriş | Emülatörde uçtan uca denendi |
| Hata görünürlüğü | Yok (Crashlytics yoktu) | Crashlytics + `fs_` ilk oturum hunisi | Derlendi, konsolda etkinleştirilmeli |
| Toplam PSS (shop ekranı, tüm avatarlar kaydırılınca) | 428 MB | 409 MB | `dumpsys meminfo` |
| 4 test sonrası bellek eğilimi | — | 451 → 418 MB (**sızıntı yok**) | `dumpsys meminfo` |
| Boşta CPU (ana ekran) | — | %0–0,3 | `top` |

**En önemli üç bulgu:**
1. **Avatarlar** gerçek boyutta saklanıyordu (en büyüğü 4615×5336 px). Eski cihazlarda bellek tükenmesi riskinin asıl kaynağı buydu.
2. **Zorunlu bekleme süreleri** reklam görünürlüğü için konmuştu; kullanıcı oyundan çok bekleme ekranı görüyordu.
3. **Yeni kullanıcı hatalı girişte sessizce kayboluyordu** ve uygulamada hata izleme yoktu, yani sebep görünmüyordu.

---

## 2. AI soru kalitesi (çok uzun soru/şık sorunu)

**Kök neden:** `generationConfig` yoktu, prompt'taki tek kısıt belirsiz "concise" idi, "Vaka/Senaryo", "Kronolojik Sıralama" ve "Eşleştirme" soru açıları paragraflık metin üretiyordu.

**Yapılanlar** ([ai_api_service.dart](../lib/services/ai_api_service.dart), [category_taxonomy.dart](../lib/constants/category_taxonomy.dart)):
- `GenerationConfig`: `temperature 0.9`, `responseMimeType: application/json`, soru sayısına göre `maxOutputTokens` (düşünme token'ları için cömert).
- Prompt'a sert limit: soru ≤ 160, şık ≤ 50 karakter, soru tek cümle.
- İstemci doğrulaması (`_isCompact`): tam 4 şık, `correctIndex` 0–3, uzunluk, çeviriler de dahil. Hepsi elenirse ham liste döner (boş test olmasın).
- Soru açıları tek cümlelik ve kısa şıklı olacak şekilde yeniden yazıldı.
- **Havuz ve önbellek okumalarına da aynı filtre** uygulandı (eski uzun sorular için).
- Model başına 7 sn zaman aşımı, toplam 12 sn bütçe; tüm modeller başarısız olursa Crashlytics'e kayıt.

**Cihazda görüldü:** Yeni AI soruları kısa ("The rupee is the official currency of which nation?", şıklar tek kelime). Eski havuz sorusunda 100+ karakterlik şıklar görüldü ve filtre onları eledi, akış AI üretimine düştü (5 soru ≈ 5,3 sn).

**Risk:** Filtre sıkı. Eski havuzun çoğu elenirse AI çağrısı artar. İhtiyaç olursa şık sınırı 60'a çıkarılabilir.

---

## 3. RAM ve performans

### 3.1 Görseller
- 52 avatar en fazla 384 px'e indirildi, gerçek JPEG olarak kaydedildi: 5,2 → 1,0 MB, çözülmüş toplam 706 → 25 MB.
- `avatar_42.jpg` ve `avatar_47.jpg` aslında **AVIF** idi (Android 12 altında çözülemeyebilir) → JPEG'e çevrildi.
- `lib/assets/emilekbul.png` 806 px / 793 KB → 512 px / 282 KB.
- Orijinaller oturum scratchpad'inde yedekli ve git geçmişinde duruyor.
- Görsel önbelleği 100 MB varsayılanından **48 MB / 150 görsele** sınırlandı ([main.dart](../lib/main.dart)).

### 3.2 Bellek ve pil
- Reklam banner'ları (her biri bir WebView) başka sayfa üstünü kapatınca bellekte kalıyordu; artık 10 sn görünmez kalırsa bırakılıyor, görününce yeniden yükleniyor ([my_native_ad.dart](../lib/widgets/my_native_ad.dart)).
- Kullanılmayan müzik oynatıcısı (her `AudioPlayer` bir native oynatıcı ayırır) kaldırıldı.
- Reklam yeniden denemesi: doldurma yoksa/çevrimdışıysa 5 başarısızlıktan sonra durur (önceden sonsuz).
- Presence (çevrimiçi) yazması 60 → 90 sn; arka plana geçince durur.
- Ana ekrandaki 3 Firestore stream'i (arkadaş, davet, dürtme) arka planda kapanır, dönünce açılır.
- Havuz okuması `count*3` → `max(count*2, count+2)`; 10 dk'lık, en fazla 8 partition'lık bellek önbelleği.
- Düşük RAM'li cihazlarda (<3 GB) geçiş reklamı `warmUp` atlanır.
- Rewarded reklamda eksik `dispose` eklendi.
- `GoogleFonts.poppins` 4 ağırlıkla (400/500/600/700, ~630 KB) pakete gömüldü; `firaCode` (indirme gerektiriyordu) sistem monospace'ine çevrildi.
- Kullanılmayan hassas izin `SYSTEM_ALERT_WINDOW` kaldırıldı.

### 3.3 Performans modu (animasyonlar korunarak)
- 3 yerdeki `BackdropFilter` blur'u `PerformanceService.blur` ile performans moduna bağlandı; animasyonlar çalışmaya devam eder.
- 6 ekrandaki sonsuz orb animasyonu performans moduna bağlandı; ana ekrandaki gereksiz pulse animasyonu yalnızca gerektiğinde çalışır.

### 3.4 Açılış
- Ses, titreşim ve Analytics başlatması ilk frame'i bloklamaz (arka planda).
- **Bilerek bekletilen:** App Check. Arka plana alınırsa ilk Firestore/Auth istekleri token'sız gidip, zorunluluk açıksa `permission-denied` verebilir.
- Açılış süresi ölçümü `app_startup` event'i olarak Analytics'e gider.

**Ölçülemeyen:** Flutter kare süresi (`gfxinfo` Flutter'ı görmüyor). Gerçek eski telefonda DevTools ile bakılmalı.

---

## 4. İlk oturum ve terk/geri dönüş (retention)

### 4.1 Beklemelerin kısaltılması
| Süre | Önce | Sonra |
|---|---|---|
| Splash | 3,5 sn | 1,3 sn |
| Soru yükleme ekranı (min) | 5 sn | 1 sn (Remote Config) |
| Cevap geri bildirimi | 1,8 sn | 1,2 sn |
| Sorular arası geçiş | 2,5 sn | 0,45 sn |

Yükleme ekranındaki ve oyun ekranındaki banner kaldırıldı.

### 4.2 Reklam sıklığı (Remote Config'ten ayarlanır)
| Anahtar | Önce | Sonra |
|---|---|---|
| `interstitial_free_tests` | 5 | 6 |
| `interstitial_every_n` | 2 | 3 |
| `interstitial_min_interval_seconds` | 120 | 180 |
| `loading_min_wait_seconds` | 5 | 1 |

Varsayılanlar kodda; Remote Config ilk açılışta gelmeyebilir (3 sn zaman aşımı, açılışı bloklamaz), değerler sonraki açılışta devreye girer.

### 4.3 Jeton duvarı
- Başlangıç 50 jeton, test girişi 10: ~5. testte jeton bitiyor ve tam o anda geçiş reklamları başlıyordu.
- **Günde 3 ücretsiz test** (bulutla senkron, yeniden kurulum istismarına karşı); kategori ekranında "FREE (N left)" rozeti.
- Yetersiz jetonda "Reklam İzle" aksiyonlu snackbar.
- Ödüllü reklam beklemesi ilk 3 günde 2 dk / 10 dk; sonra eski kurallar (10 dk / 1 saat).
- **Emülatörde doğrulandı:** rozet 3 → 1 hak, hak bitince 10'a döndü, 4. testte jeton 78 → 68 düştü.

### 4.4 Açılış pencereleri
- Açılışta en fazla 2 pencere ([startup_dialog_queue.dart](../lib/services/startup_dialog_queue.dart)); seri kurtarma, günlük seri ve güncelleme `force` ile sayılır.
- Misafir teklifi ve bildirim izni, ana ekran boşalmadan (başka pencere kapanmadan) açılmaz. (Testte teklifin seri penceresinin üstüne bindiği görüldü ve düzeltildi.)
- Esnek güncelleme: `version.json`'da `recommended_version` varsa kapatılabilir "Sonra" penceresi (günde 1). `min_version` altı eskisi gibi zorunlu.

### 4.5 Yeni kullanıcı + kötü/yok internet (emülatörde uçtan uca denendi)
**Bulunan sorun:** Giriş başarısız olunca akış *splash → tanıtım → "Select Language / Dil Seçin" listesi*ne düşüyordu; çevrimdışı akıştaki metinler Türkçe/İngilizce sabitti; hata izleme yoktu.

**Yapılanlar:**
- Giriş yapılamamış yeni kullanıcı dil listesine **atılmaz**; ana ekranda kalır, "You're offline…" bilgisi alır, misafir girişi 15–60 sn aralıklarla (en fazla 8 kez) arka planda yeniden denenir. Giriş başarılı olunca ana ekran görünür olduğunda akış kullanıcıyla yeniden başlar.
- **Testte bulunan kritik hata:** Ana ekran açılıyor ama içeriği **boştu**, çünkü animasyonlar girişsiz başlatılmıyordu → düzeltildi, tam ana ekran görünüyor.
- Splash: giriş zaman aşımı 8 → 5 sn, toplam en fazla 6 sn; 2,2 sn'den uzun sürerse ilerleme göstergesi.
- Splash'ta başarısız olan giriş, `QuizFlow`'da ikinci kez bekletilmez.
- Profil dokümanı yazımı zayıf ağda en fazla 4 sn beklenir (yazma kuyruğa alınır).
- Soru yüklenemezse son çare olarak çevrimdışı başlangıç soruları (tr, en, fr, es, ru, ar; diğer diller İngilizceye düşer).
- İlk açılışta havuzdan 15 "Kolay" soru önyüklenir (AI çağrısı yok).
- Çevrimdışı akıştaki 6 sabit metin 26 dile çevrildi.

---

## 5. Tutundurma özellikleri

| Özellik | Ayrıntı | Doğrulama |
|---|---|---|
| "Yarın dön" bildirimi | İlk gün için; ödül sayısı gerçek seri tablosundan | Kodla |
| Bildirim saati | En çok oynanan saate göre (9–21 aralığı, ≥5 örnek); histogram `play_hour_histogram` | Cihazda: histogram 17. saate yazıldı |
| Win-back | 3 / 7 / 14 gün için ayrı, genel ve koşullu metinler | Kodla |
| Seri kurtarma | Reklamla ≤3 gün, 200 jetonla ≤7 gün kaçırılmışsa; günde bir teklif | Kodla |
| Lig sonucu | Tam ekran terfi/düşme ekranı + PNG paylaşım kartı | Kodla |
| Referral | Ödül ilk test bitince: davet edilene 500, davet edene 250; tek seferlik (transaction) | Kodla |
| Hızlı eşleşme | Saniye sayacı, iptal, en az 1,2 sn görünür, bot isteği 4–7 sn | Kodla |
| Başarım kutlaması | Üstten beliren kart + konfeti | **Cihazda görüldü** ("Flawless Mind") |
| Eski bildirim metni | 24 saat bildirimi yanlışlıkla "50 jeton" diyordu → düzeltildi | Kodla |

---

## 6. Yeni özellikler ve güzelleştirmeler

- **Cevap titreşimi:** doğru cevapta hafif, yanlışta çift darbe, kusursuz testte kutlama titreşimi ([haptic_service.dart](../lib/services/haptic_service.dart)); düello ekranında da var. Ayarlarda aç/kapa anahtarı (işe yaramayan eski "Müzik" anahtarının yerine). Anahtar **cihazda doğrulandı** (tercih kaydediliyor); titreşimin hissi emülatörde doğrulanamadı.
- **Kusursuz test konfetisi** ([confetti_burst.dart](../lib/widgets/confetti_burst.dart)): 5/5'te ekrandan konfeti, **cihazda görüldü**.
- **"FREE" maliyet etiketi:** Quiz Preview'da ücretsiz hak varken maliyet "FREE". *Kod derlendi; cihazda görsel doğrulama yapılamadı* (bulut senkronu sayacı geri yazıyor).
- **Yerelleştirme hatası:** quiz içi "YANLIŞ!/DOĞRU!" tüm dillerde Türkçe sabitti → 26 dile çevrildi, **"CORRECT!" cihazda görüldü**.
- **Davet metinleri:** "500 jeton anında" → "ilk testten sonra"; Arapça ve Hintçe dosyalardaki bozuk Play Store bağlantıları (yazım hatalı paket adı) düzeltildi.
- **Misafir hesap teklifi** ([guest_link_prompt.dart](../lib/widgets/guest_link_prompt.dart)): ilk testten sonra ve 2. gün; "Sonra"ya basılırsa 3 gün sorulmaz. **Cihazda görüldü.**

---

## 7. Ölçüm ve hata izleme

**Crashlytics** ([error_reporter.dart](../lib/services/error_reporter.dart)): yakalanmayan Flutter/Dart hataları (fatal), ayrıca fatal olmayan kayıtlar: misafir girişi, soru yükleme, tüm AI modellerinin başarısızlığı. **Debug sürümde toplama kapalı.**

**Analytics event'leri (yeni):**

| Grup | Event'ler |
|---|---|
| İlk oturum hunisi | `fs_splash_done` (ms, user_ready), `fs_guest_login` (ok, ms, code), `fs_onboarding_done`, `fs_language_screen_shown`, `fs_welcome_shown` (has_user), `fs_welcome_offline`, `fs_guest_retry_ok`, `fs_quiz_load_failed` |
| Ekonomi | `token_wall_hit`, `free_quiz_used`, `rewarded_cooldown_blocked` |
| Soru yükleme | `questions_fallback` (ai / recycled / offline_starter) |
| Tutundurma | `guest_link_offered/accepted/dismissed`, `streak_rescue_offered`, `streak_rescued` |
| Açılış | `app_startup` |

**Yapılması gerekenler:** Firebase Console → Crashlytics → *Enable*; parametreleri raporda görmek için Firebase'de **custom dimension** tanımla (~24 saat sürer); Play Console → Data safety formuna "crash logs / diagnostics" ekle.

---

## 8. Yerelleştirme (26 dil)

- ~40 yeni anahtar + 2 güncellenen davet metni, tüm 26 dil dosyasına eklendi (`en.json` toplam 984 anahtar).
- **tr ve en** gerçek metin; **diğer 24 dil çevirileri benim tarafımdan yapıldı.** Özellikle Arapça, Tayca, Hintçe, Japonca ve Korece için ana dili konuşan birinin gözden geçirmesini öneririm.
- Kullanılmayan eski anahtarlar silinmedi (`referral.success`, `settings.music*`, eski `reengage_*`).

---

## 9. Derleme, sürüm ve bağımlılıklar

| Konu | Not |
|---|---|
| Sürüm | `pubspec.yaml` 1.5.26+54, `build.gradle.kts` 54 / "1.5.26" |
| AAB | `build/app/outputs/bundle/release/app-release.aab`, 59,6 MB, imza doğrulandı |
| `firebase_core` | **4.13.0'a sabit** (4.15.0, `firebase_auth 6.5.7` ile Android derlemesini bozuyor) |
| `firebase_remote_config` | ^6.5.6 (6.7.0 core ^4.14 ister) |
| `firebase_crashlytics` | ^5.2.7 + Gradle eklentisi 3.0.2 |
| `google-services` eklentisi | 4.3.15 → **4.4.2** (Crashlytics eklentisi 3.x için ≥4.4.1 şart) |
| Tuzak | Bu uyumsuzluk **debug derlemesinde görünmez**, yalnızca `bundleRelease`'te patlar |
| Derleme yöntemi | `flutter build` yerine `gradlew bundleRelease --no-daemon` (bu makinede flutter komutu takılıyor) |

---

## 10. Güvenlik ve uyumluluk notları

1. **Firestore kullanıcı silme kuralı geniş** ([firestore.rules](../firestore.rules) ~satır 77–79): `!isAnonymous()` kolu, kalıcı hesabı olan herkesin herhangi bir misafir benzeri profili **90 gün şartı olmadan** silmesine izin veriyor görünüyor. Dar bir kurala çevrilemedi, çünkü misafir→kalıcı geçişte eski misafir oturumu kapanmış oluyor. Kalıcı çözüm: taşıma işlemini Cloud Function'a almak ya da `linkWithCredential` ile uid'yi korumak. **Açık, öncelik ver.**
2. **Referral ödülü istemciden yazılıyor** (kurallar sınırlı artışa izin veriyor). Davet edilen kendi ödülünü aldıktan sonra davet edene yazma başarısız olursa davet eden ödülü kaybeder. Sunucu tarafı doğrulaması daha güvenli.
3. **Gemini API anahtarı** `.env` ile uygulamaya gömülü (APK'dan çıkarılabilir). Firebase AI Logic veya Cloud Function üzerinden çağırmak daha güvenli.
4. **`avatar_42` bilinen bir film karakteri/oyuncusuna benziyor** → Play Store telif/benzerlik riski. Diğer avatarların kullanım hakkı da gözden geçirilmeli.
5. **App Check / Play Integrity:** zorunluluk açıksa Play App Signing sertifikasının SHA-256'sı kayıtlı olmalı; aksi halde mağazadan inen sürüm Auth/Firestore'a erişemez. (Konsoldan kontrol edilmeli; kodla doğrulanamadı.)
6. `version.json` (`min_version` 1.5.19, `latestVersion` 1.5.22): yeni sürüm mağazada yayınlanınca `latestVersion`'ı güncelle; `recommended_version` eklersen kullanıcılar henüz olmayan bir sürüm için uyarı görmesin diye **yayından sonra** ekle.
7. GDPR/UMP onayı mevcut; Crashlytics de Data safety formuna girmeli.

---

## 11. Test kapsamı

**Emülatörde çalıştırıp görülen:** temiz kurulum akışı (splash → tanıtım → seri → ana ekran), ücretsiz hak sayacı ve jeton düşümü, soru geçişleri, AI soru uzunluğu, kusursuz test (konfeti + başarım kartı), "CORRECT!" bannerı, haptic ayarı, misafir teklifi, açılış pencere kuyruğu, shop/avatar kaydırma, banner bırakma-yeniden yükleme, bellek sızıntı testi (4 döngü), yeni kullanıcı çevrimdışı akışı, interneti açınca otomatik girişin devreye girmesi.

**Yalnızca kodla doğrulanan (derlendi, çalıştırılıp görülmedi):** seri kurtarma, win-back bildirimleri, lig sonuç ekranı ve paylaşım kartı, referral'ın koşullu ödülü, hızlı eşleşme değişiklikleri, esnek güncelleme penceresi, "FREE" önizleme etiketi, çevrimdışı akıştaki yeni dialog metinleri, titreşimin hissi, Crashlytics'in release'teki gerçek çalışması.

**Hiç test edilmeyen:** gerçek cihaz (özellikle eski/düşük RAM'li), **release AAB'nin cihazda açılışı** (R8 + Crashlytics eklentisi release'te ilk kez birlikte derlendi), düello akışlarının canlı iki oyunculu testi.

---

## 12. Bilinen sorunlar ve riskler

- Reklam geliri düşebilir (banner'lar kaldırıldı, geçiş reklamı seyreldi). Remote Config'ten ayarlanabilir.
- Başlangıç soruları yalnızca 6 dilde; diğer diller İngilizceye düşer.
- Önyükleme cihaz diline göre çalışıyor, uygulamada kayıtlı dili kullanmıyor.
- "Quiz Preview" ücretsiz hakta "FREE" gösterir ama jeton harcanan durumla ilgili tüm metinler ("insufficient_tokens" vb.) sabit "10" diyor.
- Ücretsiz hak, test sonradan iptal edilse bile harcanmış sayılır.
- Uygulama adı tutarsız: cihazda "Trivia Quiz", Türkçede "Bilgi Yarışması", paylaşım metninde "Quiz Arena" → mağaza sayfası ve reklam görseliyle uyumlu olmalı.
- Eski misafir profillerinin 90 gün sonra silinmesi (dönen kullanıcı ilerlemesini kaybeder).
- `macos/Flutter/GeneratedPluginRegistrant.swift` `pub add` yan etkisiyle değişti, commit'e girmemeli.

---

## 13. Önerilen sonraki adımlar

### P0 — Yayından önce
1. Release AAB'yi emülatöre/gerçek cihaza kurup açılış, giriş ve soru akışını doğrula.
2. Firebase Console'da Crashlytics'i etkinleştir; Play Console Data safety formunu güncelle.
3. App Check / Play Integrity SHA-256 kaydını kontrol et.
4. Firestore silme kuralı için çözüm planı (Cloud Function veya `linkWithCredential`).
5. `avatar_42` ve diğer avatarların kullanım hakkını gözden geçir.

### P1 — İlk hafta (veriyle karar)
6. Firebase'de `fs_` hunisini kur: `first_open → fs_splash_done → fs_guest_login(ok) → fs_onboarding_done → quiz_start → quiz_completed`; D1/D7 elde tutma.
7. Reklam kampanyasını "yükleme" yerine uygulama içi olaya (`quiz_completed`) göre optimize et; ülke/dil hedeflemesini desteklenen dillerle eşleştir.
8. Reklam sıklığını Remote Config'ten A/B test et.
9. 24 dilin çevirilerini ana dili konuşanlara kontrol ettir (Arapça, Tayca, Hintçe, Japonca, Korece öncelikli).
10. Uygulama adını mağaza + reklam + uygulama içinde tutarlı hale getir.

### P2 — Güzelleştirme (günlük küçük işler)
11. Başlangıç sorularını tüm 26 dil için çevir.
12. Tanıtım ekranını 3 sayfadan kısaltmayı veya "Atla"yı belirginleştirmeyi dene.
13. Soru ekranına "hatalı soru bildir" butonu (AI kalitesi için geri bildirim döngüsü).
14. Boş durumlar için iskelet (skeleton) yükleme ekranları; yükleme ekranına ipucu/ilerleme.
15. Cevap seçiminde de hafif titreşim ve seçili şık animasyonu.
16. Müzik: ya gerçek arka plan müziği ekle ya da kullanılmayan `settings.music*` anahtarlarını temizle.
17. Günlük hedef halkası (ana ekranda "bugün 2/3 test") ve seri için ana ekran widget'ı.
18. Erişilebilirlik: yazı ölçeği, kontrast, ekran okuyucu etiketleri.
19. "Quiz Preview" maliyet metinlerini ücretsiz hakla tam uyumlu hale getir.
20. Bellek kazanımı için kalan `Image`/`AssetImage` kullanımlarına `cacheWidth` ekle.

### P3 — Orta vadeli
21. Referral ve seri ödüllerini Cloud Function ile sunucu tarafına al.
22. Gemini çağrılarını sunucu tarafına taşı (anahtarı APK'dan çıkar).
23. Sunucu tarafı veriye dayalı win-back (arkadaşın seni geçti) için FCM.
24. Gerçek cihazlarda DevTools ile kare süresi/bellek profili (özellikle eski telefonlar).

---

## 14. Günlük kontrol listesi (çalışırken)

Her gün birkaç dakikada bakılacaklar:
- **Crashlytics:** yeni fatal olmayan kayıtlar (`guest_login`, `quiz_load`, `ai_fallback_exhausted`).
- **Firebase Analytics:** `fs_guest_login` başarı oranı (ok=1) ve `ms` dağılımı; `fs_welcome_offline` sayısı; `questions_fallback` aşaması dağılımı.
- **Play Console:** ilk gün silme oranı, ülke/cihaz kırılımı, ANR ve yavaş render.
- **Reklam:** kullanıcı başına `ad_impression` ve D1 elde tutma ilişkisi.
- **Ekonomi:** `token_wall_hit` sıklığı (çok yüksekse ücretsiz hak/başlangıç jetonu artırılabilir).

---

## Ek A — Yeni dosyalar
- `lib/services/error_reporter.dart` — Crashlytics sarmalayıcı
- `lib/services/haptic_service.dart` — titreşim servisi
- `lib/services/remote_flags.dart` — Remote Config bayrakları
- `lib/services/startup_dialog_queue.dart` — açılış pencere kuyruğu
- `lib/widgets/confetti_burst.dart` — konfeti
- `lib/widgets/guest_link_prompt.dart` — misafir hesap teklifi

(Önceki turlarda eklenen `league_result_screen.dart`, `streak_rescue_dialog.dart` ve `achievement_celebration.dart` git geçmişinde `f565068` commit'inde yer alıyor.)

## Ek B — Değişiklik sayıları
- 109 değiştirilmiş + 6 yeni dosya, +1354 / −269 satır (`git diff --shortstat`).
- Bunların 52'si avatar görselleri, 26'sı dil dosyaları, 32'si `lib/` altı Dart dosyaları; kalanı Android/pubspec yapılandırması.
