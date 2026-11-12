# Uzun Vadeli Yol Haritası ve Güncelleme Takvimi

**Tarih:** 2026-10-20 · **Dayanak:** 5 derin araştırma + ilk araştırma (toplam 230+ kaynak)

| Rapor | Konu | Dosya |
|---|---|---|
| 0 | Retention ve arka plan çalışma (Android sınırları) | [ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md](ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md) |
| A | Oyun tasarımı ve bağlılık mekanikleri (51 kaynak) | [ARASTIRMA_A_OYUN_TASARIMI_2026-10.md](ARASTIRMA_A_OYUN_TASARIMI_2026-10.md) |
| B | Canlı işletme, gelir, ekonomi (40 URL) | [ARASTIRMA_B_LIVEOPS_GELIR_2026-10.md](ARASTIRMA_B_LIVEOPS_GELIR_2026-10.md) |
| C | Platform, sunucu tarafı, güvenlik (~56 kaynak) | [ARASTIRMA_C_PLATFORM_SUNUCU_2026-10.md](ARASTIRMA_C_PLATFORM_SUNUCU_2026-10.md) |
| D | Büyüme, mağaza, ilk deneyim (43 kaynak) | [ARASTIRMA_D_BUYUME_ASO_ONBOARDING_2026-10.md](ARASTIRMA_D_BUYUME_ASO_ONBOARDING_2026-10.md) |
| E | İçerik kalitesi, zorluk, kişiselleştirme (44 kaynak) | [ARASTIRMA_E_ICERIK_KALITESI_ZORLUK_2026-10.md](ARASTIRMA_E_ICERIK_KALITESI_ZORLUK_2026-10.md) |

> **Güvenilirlik notu:** Birçok sayfa araçla özetleyici modelle okundu (birebir alıntı değil); "birincil" şirket kaynakları da **kendi beyanıdır** (yöntem/örneklem çoğunlukla yok). Benchmark rakamları (D1/D7/D30, ARPDAU) ikincil ve bağlamsaldır, **hedef değil kıyas** olarak kullanın. Aşağıda her önerinin yanındaki harf, dayanağının hangi rapordan geldiğini gösterir.

---

## 1. Ana teşhis (araştırmanın bu projeye söylediği)

1. **"İlk gün siliyorlar" sektör ortalamasına yakın olabilir.** Türkiye oyun D1 ≈ %19 / D7 ≈ %5 (Adjust H1 2025, ikincil); tüm oyunlarda medyan ≈ %22 / %4 / %0,7 (GameAnalytics özeti, ikincil, yöntem belirtilmemiş). Yani sorun yalnızca "uygulama kötü" değil; **trafiğin kalitesi ve ölçüm eksikliği** de büyük pay sahibi. [B, D]
2. **Günde 3–5 kurulumla A/B testi anlamsızdır.** D1'i %19'dan %25'e çıkarmayı istatistiksel olarak görmek için kol başına ~740 kurulum gerekir (≈ 300+ gün). Mantıklı yol: **5–8 kişilik nitel gözlem**, büyük etkili önce/sonra karşılaştırma, bütçe artışı. [D, geliştirici hesabı]
3. **Bildirim ve küçük mekanikler mütevazı kazanç verir.** Duolingo'nun kendi beyanı: bildirim optimizasyonu DAU +%0,5 / yeni kullanıcı tutma +%2; freeze +%0,38; kilometre taşı animasyonu +%1,7. En büyük ölçülmüş kazanç **kilidi azaltmaktan** geldi: streak'i "günde 1 ders"e indirmek D14 geri dönüşü +%3,3 yaptı. Küçük kitlede bu etkiler **tespit edilemez**; bu yüzden uygulama kararlarını mekaniğin "yön"üne göre verin, sayısına değil. [A]
4. **Güvenlik/uyumluluk riski gerçek:** Gömülü Gemini API anahtarı Gemini dokümanına göre yasak; Firebase AI Logic için App Check **2 Kasım 2026'da zorunlu**. [C]
5. **Soru kalitesi tutunmanın temelidir** ve elinizdeki en ucuz kaldıraç: şema/uzunluk doğrulaması (yapıldı), soru başı sayaçla zorluk kalibrasyonu, eşik tabanlı gizleme, ikinci geçiş doğrulama. [E]
6. **HQ Trivia dersi:** tek formata ve canlı randevuya bağımlı olmak risklidir; asenkron tasarım (sizinki gibi) daha dayanıklı. [A, ikincil]

---

## 2. Aşamalı yol haritası

Efor: **S** ≤1 hafta · **M** 1–3 hafta · **L** >1 ay (geliştirici tahmini). Etiket: [harf] = dayanak raporu.

### Faz 0 — Bu hafta: güvenlik, zorunluluk, görünürlük
| # | İş | Efor | Not |
|---|---|---|---|
| 0.1 | Gömülü **Gemini anahtarını iptal edip yenile**; çağrıyı sunucuya taşı (`onCall` proxy + Secret Manager, ya da `firebase_ai`) [C] | M | **Blaze planı gerekir** (maliyet/ödeme yöntemi kararı sizde). `cloud_functions 6.3.6` ve `firebase_ai 3.15.0` `firebase_core 4.13.0` pini ile uyumlu görünüyor, **`pub get` ile doğrulayın**. |
| 0.2 | **Crashlytics'i Console'da etkinleştir**, Data safety formunu güncelle [C] | S | Yanlış beyan ret/kaldırma riski taşır. |
| 0.3 | **Android vitals eşiklerini izle** (çökme %1,09, ANR %0,47; 28 gün) [D] | S | Aşılırsa Play görünürlüğü düşer. |
| 0.4 | **Play hedef doğrulamaları:** targetSdk 36 zaten var; **16 KB sayfa hizası** kontrolü (zorunluluk 1 Şub 2027), edge-to-edge/predictive back testi [C] | S–M | Flutter 3.32.7 motorunun 16 KB hizası için resmi kaynak **doğrulanamadı**. |
| 0.5 | **Tek ürün adı** (başlık/ikon/reklam/paylaşım) [D] | S | Şu an "Trivia Quiz / Bilgi Yarışması / Quiz Arena". |

### Faz 1 — 1–4 hafta: ilk oturum ve ölçüm
| # | İş | Efor | Not |
|---|---|---|---|
| 1.1 | **5–8 kişilik nitel kullanıcı gözlemi** (ekran/ses kaydı) [D] | S | Araştırmaların en yüksek öğrenme/efor oranı; kanal dışı, hedef kitleye benzer kişiler. |
| 1.2 | Firebase'de **`fs_` hunisini ve D1/D7 kohortlarını** kur [D] | S | Olaylar kodda hazır. |
| 1.3 | İlk testten sonra **"yarın hedefin" adımı** (hedef/hatırlatma saati) + bildirim izni bağlamda [D, A] | M | İlk giriş zaten misafir/anonim; "girişsiz ilk test" büyük ölçüde mevcut. |
| 1.4 | **Streak'i hedeften ayrı tut** ("tek kısa tur seriyi korur") — mevcut davranışı doğrula [A] | S | Duolingo'nun en güçlü ölçülmüş kazancı yönü. |
| 1.5 | **In-app updates (esnek)** [C] | S | `in_app_update` yalnızca `flutter` bağımlılığı, çatışma riski çok düşük. |
| 1.6 | **Yorumlara cevap + in-app review zamanlaması** [D] | S | Mevcut review servisi var. |
| 1.7 | Hassas konu kara listesi + güvenlik eşikleri + IARC beyan kontrolü [E] | S | Play içerik politikası riski. |

### Faz 2 — 1–3 ay: içerik kalitesi ve canlı işletme temeli
| # | İş | Efor | Not |
|---|---|---|---|
| 2.1 | **Soru başı sayaçlar** (`shown/correct`, cihazda biriktirip toplu yaz) → şans düzeltmeli **otomatik zorluk etiketi** [E] | M | Tüm kişiselleştirmenin veri temeli. |
| 2.2 | **Eşik tabanlı gizleme** (Wilson alt sınırı) + topluluk oylaması [E] | M | "Soruyu bildir" bunun ilk adımı (yapıldı). |
| 2.3 | **İkinci geçiş cevap doğrulama** (Batch, ucuz model) — önce en çok gösterilen sorulara [E] | M | ≈ 5–10 $/10k soru **(varsayım)**. |
| 2.4 | **Remote Config etkinlik takvimi** + haftalık tema haftası (kategori çarpanı) [B, A] | S | Gerçek bitiş zamanı; sahte kıtlık yok. |
| 2.5 | **FCM**: düello daveti, günlük hatırlatma, geri dönüş [C] | M | `firebase_messaging 16.5.0` core 4.13.0 ile uyumlu görünüyor (16.6+ pini bozar). 1 aydan uzun açmayan cihaza FCM de ulaşmaz. |
| 2.6 | **Kilometre taşı kutlaması** (animasyon/mesaj) [A] | S | Bonus zaten var. |
| 2.7 | **UAC bütçe pilotu** (yalnızca yükleme hacmi, Türkiye): tCPI için günlük bütçe ≥ 50× hedef CPI; ilk 100 dönüşüme kadar büyük değişiklik yok [D] | S | tROAS için Firebase gelir olayı yok → şimdi uygun değil. |

### Faz 3 — 3–6 ay: derinlik
| # | İş | Efor |
|---|---|---|
| 3.1 | **Kategori ustalığı** (seviye + "zayıf konu" modu) [A, E] | M–L |
| 3.2 | **Elo (oyuncu+soru)** ve uygun zorluk eşleştirme [E, A] | M–L |
| 3.3 | **SM-2 benzeri tekrar kuyruğu** (SQLite `due`) [E] | S–M |
| 3.4 | **Arkadaş serisi / ortak hedef** (Friend Streak benzeri; üst sınır 5, davet huni) [A] | M |
| 3.5 | **Sezonluk lig katmanı** (4 haftalık sezon, yumuşak düşüş, çıkış seçeneği) [A] | M |
| 3.6 | **Kozmetik koleksiyon** (ustalığa bağlı avatar/çerçeve seti) [A, B] | M |
| 3.7 | **Sunucu doğrulamalı ödül** + ekonomi alanlarını istemci yazımına kapatma [C] | M–L |

### Faz 4 — 6–12 ay: gelir ve ölçek
| # | İş | Efor | Not |
|---|---|---|---|
| 4.1 | **Ödüllü reklam SSV** (imza doğrulamalı callback) [B] | M | Ödül ekonomiyi etkiliyorsa. |
| 4.2 | **Jeton paketi IAP + reklamsız** (Billing Library v8, sunucu doğrulama, `purchaseToken`) [B] | M | Billing v8 zorunluluğu (uzatma 1 Kas 2026). |
| 4.3 | **Sezon + ücretsiz pass** (az kademeli beta) [B] | L | Denge ve destek yükü. |
| 4.4 | **Mediation** (+1–2 ağ) [B] | M | Families uyumu kontrolü. |
| 4.5 | **Ana ekran widget'ı** (`home_widget`, yerel Kotlin) [C] | L | Kullanıcı rızasıyla eklenir. |
| 4.6 | **Wikidata tabanlı olgusal kategoriler** (CC0) ve **yerel içerik** (çeviri dışı) [E] | L | Çeviri tek başına yetmez: Global-MMLU'da soruların %28'i kültüre özgü. |

---

## 3. Güncelleme ritmi (release train)

| Ritim | İçerik | Uygulama güncellemesi gerekir mi? |
|---|---|---|
| **Her 2 hafta** | Hata düzeltmeleri + 1 küçük özellik / ayar | Evet (küçük sürüm) |
| **Haftalık** | Tema haftası, hafta sonu etkinliği, ödül çarpanları | **Hayır** (Remote Config) |
| **Aylık** | Yeni içerik/etkinlik paketi, koleksiyon seti | Çoğunlukla hayır (RC + önceden gömülü varlık) |
| **3 ayda bir** | Büyük özellik (ör. sezon, ustalık, arkadaş serisi) | Evet |

**Her sürüm öncesi kontrol listesi:**
1. `flutter analyze` temiz.
2. **`assembleRelease`/`bundleRelease` ile derle** (debug yetmez: Crashlytics ve workmanager sorunları yalnızca release'te çıktı).
3. Firebase paket sabitlemeleri bozulmadı (`firebase_core 4.13.0`, `dependency_overrides`).
4. Yeni metinler 26 dilde; "Yenilikler" anahtarları güncel.
5. Data safety formu ve Play politikaları (yeni SDK/izin var mı?).
6. Remote Config varsayılanları kodda; yeni parametreler konsola eklendi.
7. Cihazda test (en az 1 gerçek, düşük RAM'li telefon).
8. Sürüm/`versionCode` artırıldı, AAB imzalı.

**Takvim önerisi:** B raporunda 12 aylık tema takvimi taslağı var (Kasım başlangıçlı; bayram/sezonlar Türkiye'ye uyarlanmalı).

---

## 4. Ölçüm çerçevesi

| Katman | Metrik | Kaynak |
|---|---|---|
| Edinme kalitesi | Kurulum → `fs_splash_done` → `fs_guest_login(ok)` → `quiz_start` → `quiz_completed` | Firebase hunisi |
| Elde tutma | D1 / D7 / D30 (kohort, kanal bazlı) | Play Console + Firebase |
| Kalite (guardrail) | Çökme/ANR, `question_reported` oranı, bildirim izni iptali, silme oranı | Vitals + Analytics |
| Ekonomi | Faucet/sink oranı, bakiye P90, `token_wall_hit` | Analytics (+ ileride panel) |
| Mekanik | `daily_goal_reached`, `timer_chest_claimed`, `streak_milestone` | Analytics |

**Kural:** aynı anda tek değişken, değişiklik başına ≥ 2 hafta bekle; Firebase A/B Testing için ~14 gün; **küçük hacimde istatistik değil, önce/sonra + nitel gözlem.**

---

## 5. Şimdilik YAPMAYIN

- **Düşük hacimde A/B testi ile karar vermek** (D).
- **tROAS kampanyası** (gelir olayı yok) ve **abonelik** (düşük DAU) [D, B].
- **Kalıcı bildirimli arka plan servisi**, tam zamanlı alarm izni, sahte geri sayım/kıtlık [0].
- **`firebase_in_app_messaging`** (core ^5 ister, mevcut pinle uyumsuz) ve **`firebase_messaging`/`cloud_functions`'ın 16.6+/6.4+ sürümleri** (pini bozar) [C].
- **Play Asset Delivery** (Flutter ile resmi yol yok) [C].
- Gelir hedefini hayal ürünü koymak: casual yalnız-reklam ARPDAU 0,01–0,05 USD (ikincil) → düşük DAU'da gelir sınırlıdır [B].

---

## 6. Sizin vermeniz gereken kararlar

1. **Firebase Blaze planı** (Cloud Functions, FCM sunucu tetikleme, Gemini proxy için gerekli; maliyet/ödeme yöntemi).
2. **Firestore kurallarını sertleştirme** (sunucu doğrulamalı ekonomi için gerekir). Sandık/hedef ödülleri şu an istemci tarafında; bunu kapatmak kural + Cloud Function demektir. Kuralları yayınlamama tercihinizle çelişir, bilinçli bir takas.
3. **UA bütçesi** (UAC için 50× CPI kuralı) ve ülke/dil önceliği.
4. **Para kazanma sırası** (IAP / reklamsız / pass) — kullanıcı tabanı büyüyene kadar ertelemek makul.
5. **Çocuk kitlesi ihtimali** varsa Families politikası (kişiselleştirilmiş reklam yok, onaylı SDK) tüm planı etkiler. [0]

---

## 7. Doğrulanamayanlar (özet; ayrıntı her raporun §5/§7/§9'unda)

- Trivia'ya özgü güncel D1/D7/D30 ve silme oranı; Türkiye eCPM/ARPDAU/CPI.
- Supercell/King/Playtika/Niantic birincil live-ops verisi; Fortnite/Genshin pass için birincil kaynak.
- Flutter 3.32.7 motorunun 16 KB hizası; `home_widget`/`app_links` minimum Flutter sürümü; Flutter için Install Referrer paketi.
- LLM üretimli trivia için doğrudan hata oranı çalışması; Grounding gösterim zorunlulukları.
- `firebase_messaging`/`cloud_functions` uyumu **pub.dev bağımlılık sayfalarına dayanıyor**, kilit dosyasıyla doğrulanmadı.
- Silme oranının Play sıralamasındaki ağırlığı (resmi olarak yok).

---

## 8. Bu paketin (bu oturumun) durumu

- **Uygulandı ve release derlemesi geçti, cihazda test edilmedi:** günlük hedef + sandık kartı, hatırlatma motoru (WorkManager), seri kilometre taşları, "Soruyu bildir" (kuralsız, yerel + havuz sayacı), 26 dil çevirisi, "Yenilikler" metinleri. Ayrıntı: [PLAN_YENI_OZELLIKLER_2026-10.md](PLAN_YENI_OZELLIKLER_2026-10.md).
- **Yol haritasının ilk uygulanacak işleri:** Faz 0 (özellikle 0.1 anahtar ve 0.2 Crashlytics) ve Faz 1.1 (nitel gözlem).
