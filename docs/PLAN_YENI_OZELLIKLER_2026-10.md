# Yeni Özellikler ve Güzelleştirme Planı — Oyuna Bağlama (Retention) Paketi

**Tarih:** 2026-10-20 · **Dayanak:** [ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md](ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md) (birincil kaynaklı araştırma)  
**Durum:** Kod yazıldı, `flutter analyze` ve release derlemesiyle doğrulandı. **Emülatörde/cihazda test EDİLMEDİ** (istek üzerine).

---

## 1. Hedef ve çerçeve

**Sorun:** Reklamdan gelen az sayıda kullanıcı ilk günlerde siliyor veya geri dönmüyor; kalıcı bir kitle oluşmuyor.
**İstek:** "Ünlü oyunlar gibi" kullanıcıyı oyun akışına bağlayan, **arka planda çalışan** mekanikler.

### "Arka planda sürekli çalışma" gerçekte nasıl yapılır? (araştırma sonucu)
Android'de uygulama kapalıyken **sürekli çalışan kod yoktur** ve Play politikasına uygun bir yolu da yoktur. Ünlü oyunların yaptığı şey üç parçadan oluşur:

| Parça | Nasıl çalışır | Bu projede |
|---|---|---|
| **Zaman damgası sayaçları** | Sayaç aslında hiç "çalışmaz"; bir bitiş zamanı saklanır, uygulama açılınca ya da bildirim zamanı gelince kalan süre hesaplanır | Ücretsiz sandık, günlük hedef |
| **Planlı yerel bildirimler** | İşletim sistemi alarmıyla, uygulama kapalıyken bile gösterilir | `flutter_local_notifications` (`inexactAllowWhileIdle`, izin gerektirmez) |
| **Periyodik arka plan işi** | WorkManager; OS'un uygun bulduğu zamanda (min. 15 dk, Doze/Standby'a tabi) kısa çalışır | `workmanager`, ~6 saatte bir bildirim planını yeniler |

**Bilerek YAPILMAYAN (araştırmaya göre yasak/riskli):** kalıcı bildirimli "keep-alive" foreground service, `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` talebi, sahte geri sayım/aciliyet, yüksek öncelikli sessiz FCM ile uyandırma. [bkz. araştırma §4]

---

## 2. Uygulanan özellikler (adım adım)

### Adım 1 — Retention çekirdeği
| Dosya | Görev |
|---|---|
| `lib/services/retention_scheduler.dart` | **İzole-güvenli** planlayıcı (yalnızca SharedPreferences + yerel bildirim + timezone; Firebase yok). Hem uygulamada hem arka plan izolatında çalışır |
| `lib/services/retention_engine.dart` | Günlük hedef, zamanlı sandık, ödül verme, bulut eşlemesi, ayar anahtarı |
| `lib/services/background_worker.dart` | WorkManager kaydı: `retention_refresh`, 6 saatte bir, ağ gerektirmez; hatırlatmalar kapalıysa iptal |
| `lib/services/remote_flags.dart` | Remote Config bayrakları (aşağıda) |
| `lib/services/cloud_state_service.dart` | `gameState.retention` bölümü (yeniden kurulumla sıfırlama istismarına karşı: aynı gün için **büyük olan** kazanır) |

**Güvenli kurallar (araştırma §3'e göre uygulandı):**
- Günde **en fazla 1** sandık/hedef hatırlatması (sandık o gün planlıysa hedef notu atlanır).
- Sessiz saatler 22:00–08:00; içine düşen bildirim ertesi 08:30'a ertelenir.
- 7 gündür girmeyene bu hatırlatmalar planlanmaz (win-back ayrı ve sınırlı).
- Bildirim içeriği **gerçektir**: sandık zamanı gerçek bitiş zamanı, "N test kaldı" gerçek sayı.
- Ayarlardan kapatılabilir; kapalıyken mevcut bildirimler iptal edilir, WorkManager görevi silinir.
- Bildirim metinleri uygulama açıkken önbelleğe alınır (arka plan izolatında çeviri motoru yok); dil değişince yenilenir.

### Adım 2 — Günlük hedef + ücretsiz sandık kartı
- `lib/widgets/daily_goal_card.dart`: ana ekranda (Günün Testi kartı ile Mağaza arasında) ilerleme halkası, hedef sandığı butonu ve **ücretsiz zamanlı sandık** geri sayımı. Sayaç zaman damgasından hesaplanır.
- Hedef sayacı **3 yerde** artar: tekli test sonucu, düello sonucu, günlük meydan okuma (`RetentionEngine.onActivityCompleted()`).
- Kutlama: konfeti + titreşim + ses; ödül dialog'u.

### Adım 3 — Kullanıcı kontrolü
- Ayarlar → **Hatırlatmalar** anahtarı (açık/kapalı). Kapatınca bildirimler ve arka plan görevi durur.

### Adım 4 — Seri kilometre taşları
- 7, 14, 30, 60, 100. günlerde tek seferlik bonus: **50 / 100 / 200 / 400 / 800 jeton** (`StreakService.milestoneBonuses`). Günlük seri penceresinde kutlama + konfeti.
- Kaynak notu: Duolingo kendi blogunda kilometre taşı animasyonu ile yeni kullanıcılarda 7. gün geri dönüşünde +%1,7 bildiriyor (yöntem/örneklem verilmemiş; sadece yön göstergesi).

### Adım 5 — "Soruyu bildir" (Firestore kuralı DEĞİŞTİRMEDEN çalışır)
- Test detay ekranında her soruda bayrak simgesi → neden seç (yanlış cevap / belirsiz / uygunsuz / tekrar).
- **Gerçek etkisi (kural/sunucu değişikliği gerektirmez):**
  1. **Yerel:** bildirilen soru o oyuncuya bir daha gösterilmez (yerel önbellek, bulut havuzu, geri dönüştürülmüş ve aralıklı tekrar sonuçları filtrelenir). Anahtar: normalize edilmiş soru metni, en fazla 300 kayıt.
  2. **Ortak havuz:** mevcut kuralların zaten izin verdiği `question_bank/{bölüm}/questions/{id}` dokümanına `reports` ve `reportReasons.<neden>` sayaçları artırılır (en iyi çaba). Sayaç **3'e ulaşan soru havuzdan herkese gösterilmez** → topluluk kendi kalitesini denetler.
- Günde en fazla 10 bildirim; aynı soru için sayaç yalnızca bir kez artar; analytics `question_reported` (`remote` = sayaç yazıldı mı).
- Onay metni dürüsttür: "Bu soru sana bir daha gösterilmeyecek, bildirimin soruları iyileştirmemize yardım eder."
- **Sınır:** bildirimin metni/gerekçesi sunucuda saklanmaz, yalnızca sayaç tutulur; ayrıntılı moderasyon için ileride `question_reports` koleksiyonu + kural gerekir (şu an bilerek eklenmedi).

### Adım 6 — Yerelleştirme ve duyuru
- 26 dile 26 yeni anahtar (`retention_hub.*`, `settings.reminders*`, `report.*`).
- "Yenilikler" penceresindeki 4 "Yeni" maddesi bu paketi (ve önceki turun ana özelliklerini) anlatacak şekilde güncellendi (sonraki sürümde gösterilir).

---

## 3. Remote Config parametreleri (hepsi opsiyonel; varsayılanlar kodda)

| Parametre | Varsayılan | Sınır | Anlamı |
|---|---|---|---|
| `daily_goal_target` | 3 | 1–10 | Günlük hedef test sayısı |
| `chest_interval_hours` | 6 | 1–24 | Ücretsiz sandık aralığı |
| `chest_min_tokens` / `chest_max_tokens` | 10 / 20 | 1–200 | Zamanlı sandık ödülü |
| `goal_chest_min_tokens` / `goal_chest_max_tokens` | 30 / 60 | 1–500 | Hedef sandığı ödülü |

**Ekonomi kontrolü (kabaca):** zamanlı sandık ≤ 4/gün × ort. 15 = ≤ 60 jeton; hedef sandığı ort. 45; seri ödülü 20–300. Test girişi 10 jeton + 3 ücretsiz test. Enflasyon şüphesinde sandık ödülünü/sıklığını Remote Config'ten düşür.

**Analytics event'leri:** `daily_goal_reached`, `goal_chest_claimed`, `timer_chest_claimed`, `reminders_toggled`, `streak_milestone`, `question_reported`.

---

## 4. Yayından önce yapılması gerekenler

1. ~~Firestore kuralı yayınlama~~ **Gerekmiyor:** "Soruyu bildir" mevcut kurallarla çalışır (`firestore.rules` bu pakette DEĞİŞMEDİ).
2. Remote Config'e yukarıdaki parametreleri ekle (isteğe bağlı).
3. **Cihazda test et** (bu paket test edilmedi), özellikle:
   - Sandık geri sayımı, hedef halkası ve ödül dialog'u.
   - Bildirimin kapalı uygulamada **gerçekten** gelmesi (sandık hazır olunca) ve sessiz saat ertelemesi.
   - WorkManager görevinin kaydolması (`adb shell dumpsys jobscheduler | grep abdullahekici`).
   - Ayarlardan "Hatırlatmalar"ı kapatınca bildirimlerin iptali.
   - Seri 7. gün bonusu (tarih/pref düzenleyerek simüle edilebilir).
4. Play Console: bildirim politikası/Data safety (Crashlytics zaten notlandı); Families politikası geçerliyse (çocuk kitlesi) bildirim ve jeton akışını yeniden değerlendir.

---

## 5. Bilinen sınırlar ve riskler

- **Ekonomi istemci tarafında:** sandık zamanı ve ödüller yerel/SharedPreferences + bulut eşlemesi ile tutuluyor; cihaz saatini değiştiren kullanıcı sandığı erkene çekebilir. Kalıcı çözüm sunucu saati/Cloud Function (araştırma kural 6).
- **WorkManager garanti vermez:** uzun süre açılmayan kullanıcıda uygulama "Rare/Restricted" bucket'a düşer, iş çalışmayabilir. Bu yüzden bildirimler **önceden** (uygulama açıkken) da planlanır; worker yalnızca yeniler. Uzun süre dönmeyenler için güvenilir yol sunucu tetikli FCM'dir (aşağıda).
- **Cihaz üreticisi kısıtları** (Xiaomi/Huawei vb.) planlı bildirimleri engelleyebilir; Samsung'da 500 planlı alarm sınırı vardır (araştırma §1.5).
- `RECEIVE_BOOT_COMPLETED` alıcıları var; yeniden başlatma sonrası WorkManager kendini sürdürür, bildirim planı ise uygulama bir kez açılınca yenilenir.
- Emülatörde **test edilmedi**; analiz ve release derlemesi (`assembleRelease`, arm64, başarılı) dışında çalıştırılıp görülen bir şey yoktur.
- **Bağımlılık tuzağı:** Flutter 3.32.7'de `workmanager ^0.9.2` seçilir; pub en yeni `workmanager_platform_interface 0.9.4`'ü getirince `workmanager_apple 0.9.4` ile API uyuşmazlığı çıkar ve **yalnızca release derlemesi** bozulur. `pubspec.yaml`'a `dependency_overrides` (`workmanager_platform_interface: 0.9.3`, `workmanager_android: 0.9.2`) eklendi. Flutter SDK'sı ≥3.38'e yükseltilince bu override kaldırılıp `workmanager 0.10.x`'e geçilebilir.

---

## 6. Sonraki adımlar (öncelik sırasıyla)

| # | İş | Neden | Not |
|---|---|---|---|
| 1 | **Cihaz testi + sandık/hedef ekonomi ayarı** | Test edilmedi | Remote Config ile güvenli ayar |
| 2 | **FCM ile sunucu tetikli geri çağırma** (Cloud Function) | Uzun süre dönmeyenlere ulaşmanın tek güvenilir yolu | `firebase_messaging` ↔ `firebase_core 4.13.0` pin uyumu **doğrulanmadı**; eklemeden önce kontrol et |
| 3 | **Android ana ekran widget'ı** (seri + hedef) | Her gün görünür hatırlatma | Yerel Kotlin/XML gerekir; `home_widget`; kullanıcı rızasıyla eklenir |
| 4 | **Sunucu saatli sandık/ödül** | İstemci saati istismarı | Cloud Function + `serverTimestamp` |
| 5 | **Haftalık ligde "yaklaşıyor" bildirimi** | Lig hâlihazırda var | Veriye dayalı olmalı, sahte baskı yok |
| 6 | **Arkadaş serisi / ortak hedef** | Sosyal bağ (Duolingo Friend Streaks — birincil kaynak doğrulanamadı) | Spam etmeden, kullanıcı daveti ile |
| 7 | **Sezonluk etkinlikler** | Yeniden gelme nedeni | Gerçek bitiş zamanı; sahte kıtlık yok (FTC) |
| 8 | A/B testi | Etkiyi ölç | 1 birincil + ≤5 ek metrik, ~14 gün, guardrail: bildirim iptali/silme |

---

## 7. Değişen / eklenen dosyalar (bu paket)

**Yeni:** `retention_scheduler.dart`, `retention_engine.dart`, `background_worker.dart`, `question_report_service.dart`, `widgets/daily_goal_card.dart`  
**Değişen:** `remote_flags.dart`, `cloud_state_service.dart`, `main.dart`, `welcome_screen.dart`, `account_screen.dart`, `streak_service.dart`, `daily_streak_dialog.dart`, `test_detail_screen.dart`, `test_sonucu_screen.dart`, `daily_challenge_screen.dart`, `live_duel_result_screen.dart`, `language_selector_button.dart`, `question_pool_service.dart`, `pubspec.yaml` (+ `workmanager ^0.9.2`), 26 dil dosyası
