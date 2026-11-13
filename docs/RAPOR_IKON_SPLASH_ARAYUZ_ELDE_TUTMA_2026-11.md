# Rapor: İkon, Splash, Arayüz ve Elde Tutma — 2026-11-13

Kapsam: mevcut kod ve varlıklar incelendi (dosya yolları aşağıda). Dış kaynak taraması yapılmadı; "resmi kılavuz" ifadeleri, kontrol edilmesi gereken yönlendirmelerdir.
"Elde tutamıyor" ifadesini **kullanıcı elde tutma (retention)** olarak yorumladım. Yanlışsa 6. bölüme bakın.

---

## 1) Mevcut durum (kanıtlı bulgular)

| Alan | Bulgu | Kanıt |
|---|---|---|
| İkon kaynağı | Canlı ikon `lib/assets/emilekbul2.png` (512×512; kitap–beyin–kehribar taşı). `lib/assets/emilekbul.png` (mor ampul) hiçbir yerde kullanılmıyor. | `pubspec.yaml` `flutter_icons`, iOS 1024 ikonu ile piksel karşılaştırması |
| iOS App Store ikonu | 1024×1024 dosya, 512 px kaynaktan büyütülmüş olabilir → App Store'da yumuşak görünebilir. Palet tabanlı PNG; alfa kanalı olmadığı ayrıca doğrulanmalı. | `Icon-App-1024x1024@1x.png` |
| iOS açılış ekranı (splash) | `LaunchImage.png` **1×1 piksel şeffaf yer tutucu** (68 bayt). Storyboard arka planı **beyaz**. Uygulama ise koyu tema. Açılışta beyaz bir ekran yanıp sönüyor. | `LaunchScreen.storyboard` (`backgroundColor` 1,1,1), `LaunchImage.imageset` |
| Android açılış ekranı | Düz renk `#0F172A`, logo yok. Uygulama teması `#0B1020`. Küçük bir renk uyumsuzluğu var. | `drawable/launch_background.xml`, `app_theme.dart` |
| Flutter animasyonlu splash | 1,3 sn animasyon; kodda en fazla **6 sn** backend beklemesi (`timeout(6s)`), misafir girişi için ayrıca 5 sn zaman aşımı. Yavaş ağda ilk ekran 6–7 sn boş/animasyonlu kalabilir. | `lib/screens/animated_splash_screen.dart` |
| Renk dili | Arayüz iOS-vari mavi `#0A84FF` vurgu rengi + lacivert zemin. Canlı ikon sepya/kahverengi; arayüzle uyumsuz. | `lib/theme/app_theme.dart`, ikon görseli |
| İkon konsepti | Canlı ikon (kitap) koyu ve düşük kontrastlı; sayfa, ışık ve dal detayları 40–60 px'te kayboluyor. "Kendini belirtmiyor" hissinin ana nedeni bu. Kullanılmayan mor ampul (`emilekbul.png`) tek silüet ve yüksek kontrastla çok daha net; küçük boyutta da okunuyor. | Karşılaştırma: 120 / 60 / 40 px, koyu zemin |
| Cam yüzey bileşeni | `glass_surface` ve `glass_alert_dialog` mevcut; yeni nesil görünümün altyapısı zaten var. | `lib/widgets/glass_surface.dart` |
| Bildirim ve retention altyapısı | Bildirim izni akışı, WorkManager hatırlatmaları, nudge motoru, widget, ödüllü reklam ve günlük seri var. Teknik altyapı eksik değil; sorun büyük ölçüde açılış deneyimi, ilk dakika ve geri dönüş kancalarında. | `docs/ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md`, `docs/ARASTIRMA_D_BUYUME_ASO_ONBOARDING_2026-10.md` |

**Öncelik sırası (etki / maliyet):**
1. iOS beyaz açılış flaşı (yüksek etki, düşük maliyet).
2. Splash süresinin kısaltılması ve açılış görünümü (yüksek etki, orta maliyet).
3. İkon yeniden çizimi ve tek marka rengi (orta–yüksek etki, orta maliyet).
4. Arayüzde yeni nesil dokunuşlar (orta etki, yüksek maliyet, aşamalı).
5. İlk dakika ve retention mekanikleri (yüksek etki, yüksek maliyet; mevcut araştırmalar kapsıyor).

---

## 2) Öneriler

### 2.1 İkon
- **Kaynağı büyüt:** 1024×1024 vektör ya da en az 1024 px kare kaynak hazırla. Mevcut 512 px kaynağı büyütme yerine yeniden üret.
- **Önerilen:** Canlı ikonu mor ampul ile değiştir (`flutter_icons` kaynağını `emilekbul.png` yap). Mor ampul küçük boyutta net, arayüzün koyu zeminiyle de kontrast veriyor. Bu dosya 512×507 ve kare değil; kare tuval (512×512) ile doldurulup üretim yapılmalı.
- **Tek marka rengi:** Mor ikon seçilirse vurgu rengi de mora yakınlaştırılmalı ya da ikon mavi/lacivert vurgu ile hizalanmalı. Karar gerekiyor (bkz. 5. bölüm).
- **Sadeleştir:** Devre çizgilerini kaldır veya tek bir motife indir. 29 px ve 40 px boyutta okunurluk testi yap.
- **iOS 26 "Liquid Glass" ikonu:** Apple'ın katmanlı `.icon` biçimi (Icon Composer ile) Xcode 26 gerektirir. Mevcut CI `macos-15` ve Xcode 16 kullanıyor; bu biçim için CI'ın Xcode sürümünü yükseltmek gerekir. Eski biçim de çalışmaya devam eder.
- **Android:** `mipmap-anydpi-v26/ic_launcher.xml` var; Android 13+ "themed icon" için monokrom katman olup olmadığı kontrol edilmeli (doğrulanmadı).
- **Doğrulama:** iOS 1024 ikonunda alfa kanalı olmamalı (App Store reddi nedeni olabilir).

### 2.2 Splash ve açılış
- **iOS açılış görseli (acil):** `LaunchScreen.storyboard` arka planını koyu tema rengine (`#0B1020`) çevir ve logoyu ortalanmış bir görsel olarak ekle (1×1 yer tutucu kaldırılsın). Böylece açılış flaşı kaybolur.
- **Android açılış:** `launch_background.xml` içine logo ekle ve renk değerini tema zeminiyle eşitle. Android 12+ için `SplashScreen` API (values-v31) ile ikon + arka plan tanımı yapılabilir (mevcut `values-v35` klasörü ne içeriyor, kontrol edilmeli).
- **Flutter splash süresi:** 1,3 sn animasyon + 6 sn beklemeyi ayır. Öneri: animasyonu 0,8–1,0 sn'ye indir; backend bekleme süresini 3 sn'ye çek; bu süre dolunca ana ekrana geç ve veriyi arka planda tamamla. Mevcut "yavaş ağ" göstergesi (`_showSpinner`) bu akışın içinde kalsın.
- **Ölçüm:** Açılıştan ilk etkileşilebilir ekrana kadar süreyi `AnalyticsService.logAppStartup` ile zaten ölçüyorsun. P50/P90 değerlerini bu üç değişiklikten önce ve sonra karşılaştır.

### 2.3 Arayüz — yeni nesil dokunuşlar
Öneriler düşük maliyetten yükseğe sıralı:
1. **Hareket sistemi:** `app_motion.dart` içinde tutarlı süre ve eğri seti (ör. giriş 220 ms, vurgu 320 ms). Ekranlar arası geçişte tek tip kayma/solma.
2. **Mikro-etkileşim:** Doğru cevapta kısa ölçek sıçraması + hafif titreşim (`haptic_service` zaten var); yanlışta kısa sarsıntı.
3. **Cam yüzeyler:** `glass_surface`'ü yalnızca kart ve alt menüde kullan; metin okunurluğunu koru (kontrast testi).
4. **Tipografi:** Poppins zaten paketli. Başlık için tek bir ağırlık/boyut skalası tanımla.
5. **Boş durumlar ve iskelet yükleme:** Liste ve skor ekranlarında iskelet (skeleton) yükleme; boş ekran için tek satırlık yönlendirme ve bir eylem düğmesi.
6. **Sonuç ekranı:** Skor sayımı + seri ilerlemesi + "bir sonraki hedef" kartı. Bu, retention etkisinin en yüksek olduğu yer olabilir (ölçülmeli).
7. **Karanlık/açık tema:** Şu an yalnızca koyu tema; sistem ayarına bağlı tema seçeneği ayrıca değerlendirilebilir.

### 2.4 Elde tutma (retention) — mevcut araştırmayla bağlantı
Yeni eklemeler değil, mevcut dokümanlardaki öncelikli maddelerin açılış deneyimiyle bağlantısı:
- İlk testi kayıt olmadan oynat; kayıt adımını ilk testten sonra iste (Duolingo deseni, D-ARAŞTIRMA §4.2).
- Bildirim iznini ilk açılışta değil, "yarın hatırlatalım mı?" bağlamında iste (RETENTION §1 madde 5).
- İlk oturum hunisi olaylarını GA4 funnel olarak tanımla (`first_open` → `first_quiz_complete` → `goal_set` → `notification_perm_granted`).
- Her değişikliği Remote Config bayrağıyla aç/kapa; A/B testiyle doğrula.

---

## 3) Önerilen uygulama sırası

| Aşama | İş | Süre tahmini | Doğrulama |
|---|---|---|---|
| A | iOS açılış görseli + Android açılış rengi/logosu | 0,5–1 gün | Simulator/cihazda açılış videosu |
| B | Flutter splash süresi (1,0 sn animasyon, 3 sn timeout) | 0,5 gün | `logAppStartup` P50/P90 karşılaştırması |
| C | İkon yeniden çizimi (1024 kaynak, sadeleştirme) + tek marka rengi | 1–3 gün (tasarım dahil) | 29/40 px okunurluk, App Store önizleme |
| D | Hareket sistemi + mikro-etkileşim + sonuç ekranı | 3–5 gün | Gözle inceleme + A/B (sonuç ekranı) |
| E | İlk oturum hunisi ve hedef seçimi | 3–5 gün | GA4 funnel, D1 dönüş |

---

## 4) Doğrulanamayanlar

- Android themed icon (monokrom katman) ve `values-v35` içeriği kontrol edilmedi.
- iOS 1024 ikonunda alfa kanalı yok mu sorusu yalnızca dosya türüne bakılarak yanıtlandı; App Store Connect yüklemesinde kesin doğrulanır.
- Splash süresinin gerçek cihaz değerleri ölçülmedi; kod okumasına dayanıyor.
- Liquid Glass ikon biçiminin CI'da gerektirdiği Xcode sürümü ayrıca doğrulanmalı.
- Retention rakamları için kaynak ve yöntem notları önceki araştırma dokümanlarında; bu raporda yeni sayısal iddia yok.

---

## 5) Karar bekleyen sorular

1. **Marka rengi:** Mor ikon mu kalsın (arayüzü mora çevir), yoksa ikon mavi/lacivert ile mi hizalansın?
2. **"Elde tutamıyor":** Kastedilen kullanıcı kaybı (retention) mı, yoksa arayüzün "elle tutulamaz" (kullanılabilirlik/ergonomi) hissi mi? Bu iki durumda öncelikler farklı.
3. **Liquid Glass:** iOS 26 ikon biçimini şimdiden hedefleyelim mi (CI Xcode yükseltmesi gerekir)?
4. **Kapsam:** Aşama A ve B hemen uygulansın mı? (İki aşama düşük riskli ve hızlı.)

---

## 6) Uygulanan değişiklikler (2026-11-13)

Aşama A ve B uygulandı; commit/push yapılmadı, yerelde duruyor.

- **iOS açılış (A):** `LaunchScreen.storyboard` zemini beyazdan `#0B1020`'ye alındı; 1×1 yer tutucu yerine `LaunchImage` 1x/2x/3x, canlı ikonun 168/336/504 px sürümleriyle değiştirildi (`ios/Runner/Assets.xcassets/LaunchImage.imageset/`).
- **Android açılış (A):** `launch_background.xml` zemini `#0B1020`; ortaya 160 dp logo (`drawable-nodpi/launch_logo.png`) eklendi.
- **Flutter splash (B):** animasyon 1300 → 1000 ms; backend bekleme üst sınırı 6 → 3 sn (`animated_splash_screen.dart`).
- **Doğrulama:** `flutter analyze` (splash dosyası) temiz; `flutter test` 44/44 geçti; iki XML dosyası ayrıştırıldı. Gerçek cihazda açılış görüntüsü ve süre ölçümü henüz yapılmadı.
- **Risk:** Backend bekleme 3 sn'ye inince ana ekran, misafir girişi bitmeden açılabilir. Ana ekranın `currentUser == null` durumunu yeniden denediğini ayrıca kontrol etmek gerekir.
- **Logo değişikliği:** Splash logosu şimdilik canlı ikon. İkon kararı verilirse `launch_logo.png` ve `LaunchImage*` aynı kaynaktan yeniden üretilmeli.

## 7) Dosya referansları

- `pubspec.yaml` — `flutter_icons` (ikon kaynağı)
- `lib/assets/emilekbul.png`, `lib/assets/emilekbul2.png` — ikon kaynakları
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` — iOS açılış ekranı
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/` — iOS açılış görseli (1×1 yer tutucu)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — iOS uygulama ikonu
- `android/app/src/main/res/drawable/launch_background.xml` — Android açılış rengi
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` — Android adaptive ikon
- `lib/screens/animated_splash_screen.dart` — Flutter splash akışı
- `lib/theme/app_theme.dart` — renk ve tema tokenları
- `lib/widgets/glass_surface.dart` — cam yüzey bileşeni
- `docs/ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md` — retention araştırması
- `docs/ARASTIRMA_D_BUYUME_ASO_ONBOARDING_2026-10.md` — onboarding ve ASO araştırması
