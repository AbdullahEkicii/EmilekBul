# Araştırma D: Büyüme, Kullanıcı Kazanımı (UA), Mağaza Optimizasyonu (ASO) ve İlk Deneyim — 2026-10

Tarih: 2026-10-20. Yalnızca araştırma; kod değiştirilmedi. Önceki rapor (`ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md`) tekrar edilmedi; bildirim izni ve Firebase A/B Testing orada işlendi, burada yalnızca bağlantılı noktalar var.

Etiketler: **[B]** birincil kaynak (Google/Android/Firebase/şirket kendi yayını), **[İ]** ikincil kaynak (haber, blog, ASO/benchmark şirketi, arama özeti), **[GÇ]** geliştirici çıkarımı/hesabı (kaynak değil, benim akıl yürütmem). Araç kısıtı: birçok Google Ads/Play yardım sayfası "özet çıkarıcı" ile okundu; alıntılar sayfanın özetidir, birebir metin değildir. Sayısal iddialarda ölçüm/bağlam belirtildi.

---

## 1) Özet (15 madde)

1. Google, App campaign bütçesi için resmi çarpanlar veriyor: kurulum (tCPI) kampanyasında günlük bütçe >= hedef CPI x 50; uygulama içi eylem (tCPA, "ACi") kampanyasında >= hedef CPA x 10; etkileşim kampanyasında x 15. Öğrenme için "ilk 100 dönüşüm tamamlanmadan" büyük değişiklik yapma. [B] https://support.google.com/google-ads/answer/14104492
2. Yeni kurulum hedefleyen ACi kampanyasında önerilen strateji "yükleme hacmi" ile başlamak ve veri biriktikçe uygulama içi eyleme geçmek; uygulama içi eylemde birden fazla olay seçilmesi önerilmiyor; gözlenen CPA'nın ~%20 üstü tCPA olarak önerilir. [B] https://support.google.com/google-ads/answer/12073727
3. tROAS yalnızca Google Analytics for Firebase SDK + dinamik gelir değeri geçiren olaylarla çalışır; bu projede gelir olayı yok/az ise tROAS bu aşamada uygun değil. [B] https://support.google.com/google-ads/answer/7100895 [GÇ: gelir olayı durumu kod tabanında doğrulanmadı]
4. Küçük bütçede Maximize conversions teklifi bütçeden büyük çıkabilir ve kampanya hiç dönüşüm alamayabilir (Google'ın kendi uyarısı). [B] https://support.google.com/google-ads/answer/7100895
5. Günde 3-5 kurulum ve kalıcı kitle yokluğu: A/B testler için örneklem yetmez. Bu rapordaki hesaba göre D1 elde tutmada 19% -> 25% farkı yakalamak için kolu başına ~740 kurulum gerekir (>= 300 gün) [GÇ hesap]. Gerçekçi yöntem: nitel gözlem (NN/g: 5 kullanıcı ≈ %85 sorun), büyük etkili değişiklikler, sıralı (önce-sonra) ölçüm.
6. Play Console mağaza listesi deneyleri: varsayılan dilde grafik deneyi (aynı anda 1) veya en fazla 5 yerelleştirilmiş deney; en fazla 2 varyant; metrik "benzersiz kurulum tıklaması"; araç gereken kurulum sayısını tahmin ediyor; 6 ay sonra otomatik durur. [B] https://support.google.com/googleplay/android-developer/answer/6227309
7. Android vitals: kullanıcı-algılı çökme oranı >%1,09 veya ANR >%0,47 (28 günlük, tüm cihazlar) eşiğini aşarsa Play görünürlüğü azaltabilir ve mağaza sayfasında uyarı gösterebilir. [B] https://developer.android.com/vitals
8. Google Play sıralama faktörlerini kendisi şöyle listeliyor: relevans, uygulama deneyimi (listeleme, destek, performans/stabilite), editoryal değer, reklamlar, "kurulum sonrası kullanıcıların uygulamayı kullanmaya devam etmesi"; ağırlıklar yüzeye göre değişir. Kurulum-silme oranının kesin ağırlığı resmi olarak yok. [B] https://support.google.com/googleplay/answer/11906913 ; https://support.google.com/googleplay/android-developer/answer/9958766
9. Mağaza metni sınırları: uygulama adı 30, kısa açıklama 80, uzun açıklama 4000 karakter; anahtar kelime doldurma resmi olarak kötü deneyim/sıralamaya etkisiz diye tarif edilmiş; "en iyi/#1/indir" gibi ifadeler önerilmiyor. [B] https://support.google.com/googleplay/android-developer/answer/9859152 ; https://support.google.com/googleplay/android-developer/answer/9866151
10. Özel mağaza listeleri: 50'ye kadar, ülke bazlı (bir ülke tek listeye), "28 gündür açmayan (lapsed)" ve "kaldıran (churned)" gibi kullanıcı segmentlerine ayrı listeleme gösterilebilir; otomatik çeviri yok. [B] https://support.google.com/googleplay/android-developer/answer/9867158
11. Duolingo (şirket yöneticisi, First Round röportajı): kayıt ekranını birkaç adım geriye alıp deneme dersini önce vermek DAU'yu ~%20 artırdı; "yeni uygulama %20-30 etki arayın, olgun uygulamada >=%1"; A/B için kabaca >=100.000 DAU önerilmiş — yani küçük ekip için dersi nicel test değil nitel gözlem olmalı. [B-röportaj, aracı site] https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker/
12. Android resmi öneri: bildirim izninde (API 33+) zamanlamayı sen belirlersin; değeri anlatmadan isteme. [B] https://developer.android.com/develop/ui/views/notifications/notification-permission (önceki raporda da)
13. Trivia Royale vaka (TechCrunch): bütçe < $500K, %40'ı TikTok influencer'a; yeni kullanıcıların ~%85'i ücretsiz; iOS D1/hafta-1 %45, Android hafta-1 %21; dört sosyal özelliğin tümünü kullananlarda D1 %84. Tek vaka, kendi beyanı. [İ-şirket beyanı] https://techcrunch.com/2020/07/10/how-thor-fridrikssons-trivia-royale-earned-2-5m-downloads-in-3-weeks/
14. Türkiye: Android payı StatCounter'a göre Eylül 2026'da ~%77 (iOS ~%23); Adjust 2025 H1 oyun D1 %19, D7 %5, D30 %1 (küresel kıyas D1 %26, D7 %12, D30 %5). Bu projenin "ilk gün siliyor" gözlemi sektör ortalamasıyla uyumlu olabilir. [İ] https://gs.statcounter.com/os-market-share/mobile/turkey ; https://gamedevreports.substack.com/p/adjust-the-mobile-market-of-turkiye
15. Sosyal/viral büyümede akademik uyarı: teşvikli yönlendirme ağlarında öneriler genelde zayıf yayılır, satın alma olasılığı birkaç öneriden sonra platoya oturur (Leskovec vd. 2007). Viral katsayı (K) > 1 beklenmemeli; paylaşım kartı "ek organik katkı" olarak değerlendirilmeli. [B-akademik] https://arxiv.org/abs/physics/0509039

---

## 2) Google Ads App Campaigns (UAC)

### 2.1 Nasıl çalışır [B]
- Metin satırları, teklif ve varlıklar (metin, görsel, video, HTML5) verilir; sistem kombinasyonları test edip Search, Google Play, YouTube, Discover ve Display Ağı'nda yayınlar. https://support.google.com/google-ads/answer/6247380
- Uygulamanın Play'de yayınlanmış olması, ödeme yöntemi, hedef kitle/kategori bilgisi gerekir (aynı sayfa).

### 2.2 Optimizasyon hedefleri [B] https://support.google.com/google-ads/answer/7100895 ; https://support.google.com/google-ads/answer/12073727
| Hedef | Teklif | Not |
|---|---|---|
| Yükleme hacmi (ACi) | tCPI veya "Maximize conversions for installs" | "Tüm kullanıcılar" en yüksek kurulum hacmi. Örnek: $100 bütçe, $2 hedef = ~50 kurulum/gün |
| Uygulama içi eylem (ACi) | tCPA / Maximize conversions for in-app actions | Ad: "uygulamayı yükleyen ve sonra eylemi yapma olasılığı yüksek" kullanıcılar. Birden çok eylem seçilmesi önerilmiyor. Gözlenen CPA +%20 tCPA |
| Uygulama içi eylem değeri | tROAS / Maximize conversion value | Firebase SDK ve dinamik gelir değeri gerekir; başlangıç tROAS = benzer kampanyanın gerçekleşen ROAS'ı |
| Etkileşim (ACe) | tCPA | Mevcut kullanıcıları geri getirme; bütçe >= 15x teklif; "tCPA'yı >100 dönüşüm getirecek kadar yüksek tut" |

- Bu projeye uygunluk [GÇ]: Gelir ağırlıklı değil; "tutundurma" odaklı. En mantıklı sıra: (1) yükleme hacmi, (2) tek bir "aha olayı" (ör. `tutorial_complete` veya ilk testin bitişi) üzerine in-app action. tROAS gelir değeri yoksa kullanılmaz.

### 2.3 Firebase olaylarını Google Ads'e bağlama [B] https://support.google.com/google-ads/answer/13823256 ; https://support.google.com/google-ads/answer/6397604
1. Analytics for Firebase SDK; `first_open`, `in_app_purchase` otomatik.
2. Firebase konsolunda Analytics'i bağla; hedef olayı Analytics'te "key event" işaretle (en az Viewer yetkisi).
3. Analytics'i Google Ads ile bağla (Editor yetkisi), otomatik etiketlemeyi aç.
4. Google Ads'te Goals > dönüşüm eylemi oluştur; hem "web" hem "uygulama" kutusu işaretli olsun.
5. Yeni içe aktarılan eylem mevcut birincil eylemlerle çakışıyorsa "ikincil" yap.
- Analytics verisiyle yapılan kitleler (yeniden pazarlama) yalnızca Display kampanyalarında kullanılabilir. [B] https://support.google.com/google-ads/answer/13823256 (arama özeti) / Firebase-Ads sayfası. Kalıcı kitle ihtiyacı için bu bir fırsat olabilir ama App campaign'de değil [GÇ].
- Olay adları (oyun için standart): `tutorial_begin`, `tutorial_complete`, `level_start`, `level_end`, `post_score`, `share`, `select_content`, `unlock_achievement`, `join_group` [B-referans listesi, açıklamaları yok] https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event

### 2.4 Minimum hacim ve öğrenme dönemi [B]
- Google bütçe/teklif oranı: tCPI >= 50x, ACi tCPA >= 10x, ACe tCPA >= 15x. https://support.google.com/google-ads/answer/14104492
- "İlk 100 dönüşüm kaydedilmeden" dönüşüm ayarı, yüksek performanslı varlık, teklif döngüsü, optimizasyon hedefi/olay veya coğrafya gibi büyük değişiklikleri yapma. (aynı kaynak)
- Bütçe/CPI değişimini >%20 yapma. https://support.google.com/google-ads/answer/9176652 (aynı öneri). Kampanya "ilk günlerde (hatta haftalarda) CPI şişkin görünebilir", dönüşüm gecikmesi payı bırakılmalı. (aynı sayfa)
- Genel Smart Bidding öğrenme süresi üç etkene bağlı: dönüşüm hacmi, dönüşüm döngüsü uzunluğu, teklif stratejisi; genelde 1-2 dönüşüm döngüsü; kesin dönüşüm sayısı verilmemiş. https://support.google.com/google-ads/answer/13020501
- Eski Google UAC blog önerisi: "günde en az 10 farklı kişinin yaptığı bir olay seç" (arama özeti; blog kendisi açılmadı, **doğrulanamadı**).
- "Günde 10 dönüşüm" tCPA eşiği ve "100 dönüşüm" rakamı üçüncü taraf kaynaklarda; Google'ın bu rakamı kuralı olarak yayımladığı doğrulanamadı. [İ]

### 2.5 Küçük bütçe (günde birkaç kurulum) için strateji [GÇ, resmi çarpanlara dayanır]
- Mevcut hacim (~3-5 kurulum/gün) çok küçük. 50x tCPI kuralı: hedef CPI $0,5 ise günlük bütçe ≥ $25; 10x tCPA kuralı: eylem başı $2 ise ≥ $20/gün. (Rakamlar varsayımsal örnek; Türkiye CPI'ı için güvenilir kaynak bulunamadı.)
- Küçük bütçede tek kampanya, tek ülke (Türkiye), tek optimizasyon hedefi, tek dil; coğrafya/hedef değişimleri öğrenmeyi sıfırlar.
- "Aha olayı" günde 10'dan az gerçekleşiyorsa in-app action yerine yükleme hacmiyle başla; ilk ~100 dönüşüm bitene kadar dokunma. Türkiye'de 100 eylemin ne kadar süreceği: günde 3-5 kurulum ve ~%20-30 aha oranıyla ~100 eylem = **~70-170 gün** [GÇ hesap]; bu yüzden ya bütçe/kurulum hacmi artmalı ya da olay daha erken/kolay seçilmeli (ör. ilk soruyu cevaplama).

### 2.6 Hedefleme [B/İ]
- Google, App campaign'de çok sıkı kısıtlamalardan (çok sayıda ülke/yerleşim dışlama) kaçınmayı öneriyor — büyümeyi sınırlar. https://support.google.com/google-ads/answer/9176652
- Dil/konum: Google Ads genel kılavuzu — dil, kullanıcının cihaz/arayüz dili ayarına göre eşleşir; konum ve dil tutarlı olmalı. https://support.google.com/google-ads/answer/1722072 (arama özeti; App campaign'e özgü kural doğrulanamadı).
- Oyun 26 dilli; Ads varlıkları dil başına ayrı yüklenebilir [GÇ, doğrulanmadı]. Öneri: önce Türkiye + Türkçe; ikinci adımda tek bir ikinci dil/ülke.

### 2.7 Yaratıcı (creative) gereksinimleri [B] https://support.google.com/google-ads/answer/9234183 (ACe sayfası; ACi için aynı ailedir, tam örtüşme doğrulanmadı)
- Metin zorunlu: >= 2 başlık, >= 1 açıklama; metin noktalama ile bitmeli.
- Görsel (isteğe bağlı): 1200x1200, 1200x628, 1200x1500 önerilir; min 200x200 / 600x314 / 320x400; 1:1, 1.91:1, 4:5; <= 5 MB; logo dışında metin içermemeli.
- Video: ad grubu başına en fazla 20, YouTube URL, >= 10 sn; mümkün olduğunca çok video yükle.
- Çağrı butonu metni sistemce üretilir.
- Her reklam grubunda en az "Good" reklam gücü hedeflenmeli. https://support.google.com/google-ads/answer/14104492
- Test [GÇ]: küçük hacimde "kazanan creative" istatistiksel olarak seçilemez; Google'ın otomatik kombinasyon mantığına bırak, varlıkları 3-4 farklı mesaj ekseninde ("60 sn'de bilgini test et", "arkadaşına meydan oku", "günlük soru") yükle ve Ads panelinin varlık derecelendirmesine (Low/Good/Best) bak.

### 2.8 Düşük kaliteli trafik işaretleri [GÇ + kısmen İ]
- Resmi App campaign "invalid traffic" kılavuzu bulunamadı. Gözlenebilir işaretler: Play Console'da yüksek mağaza ziyareti ama sıfır oturum süresi, Firebase'de `first_open` var ama `tutorial_begin` yok, aynı gün kaldırma, ülke/dil uyumsuzluğu. 
- İkincil kıyas: üçüncü taraf bir hizmet App campaign geçersiz tık oranını ortalama %3,3 olarak veriyor (Display/Video %35,5). Kaynağın yöntemi doğrulanamadı. [İ] https://fraudblocker.com/articles/invalid-click-rate-benchmarks-for-google-ads

### 2.9 Ücretli kurulum dışında organik büyüme
- Bkz. §5. Önemli not: Duolingo kendi blogunda kullanıcıların ~%80'inin (2023 başı) organik edinildiğini yazıyor; yani büyük ölçek organik/ürün-kaynaklı. [B] https://blog.duolingo.com/growth-model-duolingo

---

## 3) Google Play mağaza listesi (ASO)

### 3.1 Metin ve grafik kuralları [B]
- Ad 30, kısa açıklama 80 (ilk görülen metin), uzun açıklama 4000 karakter. https://support.google.com/googleplay/android-developer/answer/9859152
- Anahtar kelime tekrarı/ilgisiz kullanımı kötü deneyim; kısa açıklamada "anahtar kelime doldurma sıralamayı etkilemez ve kötü deneyim"; "Best/#1/Top/New/Discount/Million Downloads", "download now" ve emoji/ALL CAPS önerilmiyor; görsellerle metin tutarlı olsun. https://support.google.com/googleplay/android-developer/answer/9866151 (sayfa özeti)
- Kategori ve etiketler keşfe yardım eder. https://support.google.com/googleplay/android-developer/answer/9859152
- Google'ın "kaliteli uygulama" rehberi: açıklamayı kısa/öz tut, grafik, ekran görüntüsü ve videoyu deneyimi doğru yansıtacak şekilde optimize et, deneylerle test et, yerelleştir. https://google.play/business/guides/build-a-high-quality-app-or-game/
- Bu projeye uygunluk [GÇ]: Adlandırma tutarsızlığı ("Trivia Quiz"/"Bilgi Yarışması"/"Quiz Arena") marka tanınırlığı ve reklam-mağaza tutarlılığını bozuyor; reklam metni, ikon, uygulama içi ad ve mağaza adı tek isimde birleşmeli (S efor, düşük risk, yön: olumlu ama ölçülemez).

### 3.2 Sıralama ve keşif [B]
- Faktörler: relevans, uygulama deneyimi, editoryal, reklam, kullanıcı deneyimi (kurulum sonrası kullanımın devamı); ağırlık yüzeye göre farklı: Top Charts popülerlik; arama sorgu relevansı. https://support.google.com/googleplay/answer/11906913
- "Keşfi artırmanın en iyi yolu insanların sevdiği/tavsiye ettiği uygulama yapmak"; kalite = ikon/başlık/ekran görüntüsü + uygulama içi deneyim. https://support.google.com/googleplay/android-developer/answer/9958766
- Üçüncü taraf ASO blogları install-to-uninstall oranının, ratinglerin, güncellemenin ağırlığını sayıyor; ağırlıklar Google tarafından doğrulanmamış. [İ] https://www.apptweak.com/en/aso-blog/google-play-ranking-factors

### 3.3 Android vitals [B] https://developer.android.com/vitals
| Metrik | Genel eşik | Telefon modeli başına |
|---|---|---|
| Kullanıcı-algılı çökme | %1,09 | %8 |
| Kullanıcı-algılı ANR | %0,47 | %8 |
| Aşırı pil | %1 | — |
| Aşırı partial wake lock | %5 | — |
- Aşılırsa görünürlük azalabilir, mağaza sayfasında uyarı çıkabilir. Değerlendirme son 28 gün; 7 günden uzun süren çökme/ANR kümeleri "emerging issue" (21 gün düzeltme süresi).
- Bu projeye uygunluk [GÇ]: Firebase Crashlytics ve Play vitals'ı haftalık kontrol; eşiğin altında olduğundan emin ol. Efor S, risk düşük, etki yönü: korunma (negatif etkiyi önler).

### 3.4 Mağaza listesi deneyleri [B] https://support.google.com/googleplay/android-developer/answer/6227309
- Varsayılan dilde grafik (ikon, feature graphic, ekran görüntüleri); yerelleştirilmiş: grafik ve/veya açıklama, en fazla 5 dil. Eşzamanlı: 1 varsayılan grafik veya 5 yerel; her deney en fazla 2 varyant; bir seferde tek tür varlık öneriliyor.
- Metrik: benzersiz kurulum tıklaması / açılış tıklaması / ön kayıt tıklaması.
- Gereken kurulum tahmini kurulum ekranında; "minimum algılanabilir etki" ve güven düzeyi ayarlanabilir; farkın altı "berabere"; 6 ayda otomatik durur; minimum süre yok, "daha fazla veri gerekli" durumu olabilir.
- Küçük örneklemde [GÇ]: sadece büyük etki beklenen varyantları (ör. tamamen farklı ikon) dene; ayarlanan MDE'yi yüksek tut; tek deney, 2-4 hafta sonra "daha fazla veri gerekli" ise sonucu ciddiye alma.

### 3.5 Özel mağaza listeleri [B] https://support.google.com/googleplay/android-developer/answer/9867158
- En fazla 50; ülke başına tek liste; URL parametresi `&listing=...` ile bağlanabilir; segmentler: kaldıran, 28 gündür açmayan, ikisi, satın almayan, vb.; yeni uygulamalarda churned/lapsed seçenekleri geçerli değil; otomatik çeviri yok; reklam hedefli listeler yalnızca AdMob Android üzerinden görünür, Play arama reklamlarında değil.
- Bu projeye uygunluk [GÇ]: Kalıcı kitle yokluğu sorununda "28 günde açmayan kullanıcıya özel liste" yeni bir yol ama Play içi mağaza sayfası ziyaretine bağlıdır; hacim düşükse etkisi küçük. Reklamla gelen yeni kullanıcı için ayrı landing listesi mantıklı ama ads-hedefli liste yalnızca AdMob'dan görünür (kampanya türü uyumsuz olabilir).

### 3.6 Yerelleştirme (26 dil) [B + İ]
- Google: Play Console'da 29 dile ücretsiz makine çevirisi, 48 dile insan çevirisi; çeviri siparişinde kategori bazında "hangi dil/ülkeden kurulum yüzdesi" önerileri gösteriliyor; "çevrilmiş uygulamalar 24 milyar+ kez yüklendi". https://google.play/business/translationservices/
- Otomatik çeviri Ermenice, Retoromanca, Tagalog, Zulu için desteklenmez. https://support.google.com/googleplay/android-developer/answer/9859152
- Dil önceliği için kaynak: Play Console çeviri öneri ekranı (kategori bazında; ekran projede açılıp doğrulanmadı) + Play Console Acquisition raporundaki ülke/dil kırılımı (kendi veriniz). Pazar büyüklüğü/yarışma konusunda birincil açık kaynak **bulunamadı**; ASO şirketi rehberi (ikincil): https://www.apptweak.com/en/aso-blog/guide-to-app-store-localization
- Öneri [GÇ]: önce Play'in kendi önerisi ve kendi kurulum verisindeki ilk 3-5 dil; mağaza metni için makine çeviri + ana dil gözden geçirmesi; tek tek 26 dil için ayrı optimizasyon yapma.

### 3.7 Anahtar kelime araştırma yöntemleri [İ/B]
- Resmi: Play Console acquisition raporu "arama" ve "keşif"i ayırır; 2018 blog arama terimleri ve hangi terimlerin en çok kurulum getirdiğini gösterdiğini söyler (güncel menü doğrulanamadı). https://android-developers.googleblog.com/2018/08/new-organic-acquisition-insights-now.html ; https://support.google.com/googleplay/android-developer/answer/6263332
- Yöntem [GÇ]: Play arama otomatik tamamlamayı elle tara (Türkçe: "bilgi yarışması", "soru cevap oyunu", "genel kültür"), rakiplerin başlıklarını karşılaştır, Console'daki arama terimlerine bak; başlığa yalnızca 1 anahtar ifade (marka + "Bilgi Yarışması") ekle (30 karakter sınırı).

### 3.8 Derecelendirme ve yorum [B]
- Gösterilen puan son puanlara göre ağırlıklandırılır; yeni yorumlar ~24 saat tutulur; yorum başına bir herkese açık yanıt, düzenlenebilir; kullanıcıya bildirim gider; yanıt tonu: ilgili, nazik, tanıtım yok. https://support.google.com/googleplay/android-developer/answer/138230
- In-app review: yeterli deneyim sonrası iste; aşırı isteme; öncesinde "beğendin mi?" gibi soru sorma; kartı değiştirme; "puan ver" butonu API'yi tetiklememeli (kota nedeniyle gösterilmeyebilir; Play'e yönlendir); kota değeri açıklanmamış. https://developer.android.com/guide/playcore/in-app-review
- Gram Games vaka: Android vitals ile 1 yıldızlı yorumları %50 azaltmış (tek vaka, şirket beyanı). https://google.play/business/guides/build-a-high-quality-app-or-game/
- Bu projeye uygunluk [GÇ]: İlk günler yerine, kullanıcı örn. 3. oturumda veya belirli bir başarıdan (rekor, streak) sonra; kötü deneyim (yanlış soru raporu, bağlantı hatası) sonrası asla. Efor S; risk düşük; etki yönü: olumlu ama günde 3-5 kurulum hacminde ölçülmesi zor.

### 3.9 Kurulum-silme oranı
- Play Console'da acquisition raporunda "Retained installers" (7. ve 30. gün tutulan kurulumcular) var; kaldırma verisi Statistics'te. https://support.google.com/googleplay/android-developer/answer/6263332
- Sıralamaya doğrudan ağırlığı resmi olarak açıklanmamış; yalnız "kurulum sonrası keyif/devam" faktörü anılıyor. https://support.google.com/googleplay/answer/11906913

---

## 4) İlk deneyim / onboarding

### 4.1 Kanıtlar
- **Duolingo kayıt zamanı:** Kayıt ekranını birkaç adım geriye alıp önce ders vermek DAU'yu ~%20 artırdı; sonradan yumuşak/sert "duvarlar" eklenmesi %8,2 daha; "Discard my progress" yerine "Later" düğmesi. [B-röportaj] https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker/ . (Retention'a çevrilen %20 rakamları ikincil bloglarda tutarsız; kaynak izlenemedi. [İ] https://taplytics.com/blog/duolingo-ab-test-onboarding)
- **Duolingo bildirim zamanlaması/metin:** "Hi, it's Duo" metni DAU +%5; bildirim zamanı son kullanımdan ~23,5 saat sonra; uygulama simgesine kırmızı nokta +%6 DAU; bu deneylerde örneklem büyük (>=100K DAU). [B-röportaj, aynı kaynak]
- **Duolingo CURR/NURR:** Duolingo mevcut-kullanıcı elde tutmasını (CURR) büyüme motoru olarak buldu; yeni kullanıcı elde tutmayı D1→D2 dönüş oranı (NURR) olarak tanımlıyor; sayısal NURR değişimi blogda yok. [B] https://blog.duolingo.com/growth-model-duolingo
- **Onboarding akışı (ikincil analiz):** dil seç, günlük hedef belirle, yerleştirme dersi, seri hedefi (7/14/30), kayıt öncesi gün 1 başlar; hedef seçeneklerinde "1/3/7/30 gün" ve düğme metninde %7-10 artış iddiası tek bir blogdan, doğrulanamadı. [İ] https://taplytics.com/blog/how-duolingo-ran-an-experiment-on-their-streaks-feature
- **Bildirim izni:** Android 13+ varsayılan kapalı; zamanlama senin; değer anlatıldıktan sonra iste. [B] https://developer.android.com/develop/ui/views/notifications/notification-permission
- **Trivia Royale:** dört sosyal özelliğin tümünü kullananlarda D1 %84 (ortalama iOS D1 %45; Android hafta-1 %21; avatar yokluğu notu) — korelasyon, nedensellik değil. [İ-şirket beyanı] https://techcrunch.com/2020/07/10/how-thor-fridrikssons-trivia-royale-earned-2-5m-downloads-in-3-weeks/
- **Ölçüm olayları:** Firebase `tutorial_begin`/`tutorial_complete`/`level_start`/`level_end`/`select_content`/`share` standart olay adlarıdır. https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event
- Akademik/derin "aha anı" kaynağı bu araştırmada **bulunamadı**; "ilk 60 saniye" için birincil rakam yok.

### 4.2 Bu projeye somut öneriler [GÇ; kaynaklı rakam yok]
1. Hesap/giriş olmadan ilk testi oynat; kayıt/ad/avatar adımını ilk testten sonra "ilerlemeni kaydet" diye iste (Duolingo desenine paralel).
2. İlk 60 sn: tek ekran dil/kategori seçimi (cihaz diliyle önceden doldurulmuş) -> hemen 5 soruluk "hızlı tur" -> sonuç ekranında ilerleme (ör. "5 sorudan 4"), paylaşım kartı.
3. İlk testten sonra "Yarın için hedef seç" (ör. günde 1 test / 3 test / 5 dk); seçimi `goal_set` olayı olarak ölç; bu seçim bildirim izni isteği için bağlam (bkz. önceki rapor).
4. Bildirim iznini ilk açılışta değil, hedef seçimi sonrası "yarın hatırlatalım mı?" bağlamında iste.
5. Kişiselleştirme sorusu: 1 soru ("hangi konularda iyisin?") -> Kategori sıralaması; sonuçları zayıf kategori önerisine bağla.
6. İlk oturumda görünür ilerleme çubuğu (ör. "Günün 3 sorusu: 1/3").
7. İlk oturum hunisi olayları: `first_open` -> `onboarding_begin` -> `first_question_answered` -> `first_quiz_complete` -> `goal_set` -> `notification_perm_prompt/granted` -> `share_tap`; her adımda kaybı say (GA4 funnel).
8. Her adım Remote Config bayrağı ile kapatılabilir olsun (önceki rapordaki A/B Testing yapısı).

---

## 5) Organik / sosyal büyüme

- **Paylaşılabilir sonuç kartı (Wordle):** Emoji-ızgara paylaşım düğmesi Aralık 2021 ortasında eklendi; Wardle, oyuncuların elle emoji paylaştığını görmüştü; paylaşılan metinde bağlantı olmaması bilinçli bir tercih (spoiler vermiyor, gizemli). Sayılar kaynaklar arası tutarsız (günde 90 oyuncudan Şubat 2022'de ~10 milyona anılıyor); nedensellik kanıtlanmış değil. [İ] https://syntax.fm/show/430/creator-of-wordle-josh-wardle/transcript ; https://www.thequint.com/amp/story/news/world/how-josh-shows-love-backstory-rules-viral-wordle . Uygulama [GÇ]: günlük 5 soru, "3/5, 38 sn" kartı + oyun ismi + kısa link; paylaşım olayını `share` ile ölç.
- **Referral/viral katsayı (akademik):** Leskovec, Adamic, Huberman (2007), ~4 milyon kişi/16 milyon öneri/~500 bin ürün: öneriler ortalamada zayıf, yayılma kısa; alım olasılığı birkaç öneriden sonra plato; aynı çiftte tekrar öneri etkisini kaybeder; pahalı/küçük topluluk ürünleri daha iyi. Çıkarım [GÇ]: arkadaş davetini "ödüllü referral" yerine "meydan okuma" (1v1) olarak sun; K>1 hedefleme. [B-akademik] https://arxiv.org/abs/physics/0509039
- **Topluluk/TikTok:** Trivia Royale TikTok influencer içeriğine bütçe ayırdı; ücretli indirmelerin çoğu TikTok kaynaklı; "organik" kullanıcıların çoğu App Store'da isimle arama yapıyor (yani sosyal içerik marka aramasına dönüştü). Tek vaka, büyük bütçe. [İ] https://techcrunch.com/2020/07/10/how-thor-fridrikssons-trivia-royale-earned-2-5m-downloads-in-3-weeks/ . Discord/Reddit'te trivia'ya özel yayımlanmış vaka **bulunamadı**; genel Discord büyüme yazıları ikincil ve doğrulanmamış. [İ] https://www.alexanderjarvis.com/discord-doing-things-that-dont-scale
- **Duolingo:** kullanıcıların ~%80'i organik (2023 başı) [B]. https://blog.duolingo.com/growth-model-duolingo
- **Ürün listeleme/basın siteleri:** Bu araştırmada kaynak bulunamadı (doğrulanamadı).
- **Twitter/TikTok kısa video [GÇ]:** "Bu soruyu kaç kişi bilebiliyor?" formatında 15-30 sn videolar; sıfır bütçe; metrik: marka araması (Play Console "arama" kırılımı) ve profil bağlantısından kurulum; sonuç ölçülmesi zor (günde 3-5 kurulum).

---

## 6) Türkiye notları

- Android payı: StatCounter Eylül 2026 Türkiye mobil işletim sistemi: Android %76,99, iOS %23 (aylık pageview-tabanlı ölçüm; kullanıcı sayısı değil). [İ] https://gs.statcounter.com/os-market-share/mobile/turkey . Diğer aylar (Mayıs-Temmuz 2026) %74-76 (arama özeti).
- Altyapı: 81,9 milyon mobil bağlantı (nüfusun %93,3'ü), 77,5 milyon internet kullanıcısı (%88,3), 62,3 milyon sosyal medya kimliği (Ekim 2025); medyan hücresel indirme 68,19 Mbps (Ookla). [İ-DataReportal] https://datareportal.com/reports/digital-2026-turkey
- Oyuncu davranışı: Adjust (5.000 ortak uygulama, Oca 2023-Tem 2025; H1 2025): Türkiye oyun D1 %19, D7 %5, D14 %3, D30 %1; küresel kıyas D1 %26, D7 %12, D30 %5; en iyi D1: Kart %25, Aile %25, Bulmaca %23. [İ] https://gamedevreports.substack.com/p/adjust-the-mobile-market-of-turkiye (Android/iOS kırılımı ve trivia türü bu özette yok)
- Gelir: AppMagic'in aktardığı rakamlara göre Türkiye yerli mobil oyun geliri 2025'te $347M (+%6), indirmeler -%4 (1,8 milyar) [İ] https://wnhub.io/news/finance/item-51073 ; Adjust $427,5M diyor; tanım farkı. (Trivia'ya özgü rakam yok.)
- **Ödeme alışkanlıkları (kart/operatör faturalandırma/hediye kartı), Android'de "pay %" harcama, Türkiye'de reklam/CPI benchmark'ı: güvenilir birincil/ikincil kaynak bulunamadı** — doğrulanamadı. Küçük bütçeli Türkiye kampanyasında CPI'ı kendi hesabında gözlemle.
- Türkiye çevrimiçi süre: haftalık 41 sa 37 dk (Meltwater, hükümet yetkilisi aktarımıyla; ikincil, düşük güven). https://www.dailysabah.com/turkiye/turkiye-leads-global-social-media-use-with-41-hours-weekly/news

---

## 7) 90 günlük deney planı taslağı (küçük ekip)

**Örneklem gerçekliği [GÇ hesap, yöntem: iki oran farkı, %95 güven, %80 güç, kolu başına n ≈ (1,96+0,84)² x (p1q1+p2q2)/Δ²]:**
- Hacim: 3-5 kurulum/gün x 90 gün = ~270-450 kurulum.
- D1 %19 (Adjust Türkiye kıyası; projenin kendi D1'i bilinmiyor) -> %25 (6 puan): kolu başına ~740 kurulum, toplam ~1.500 = 300-500 gün. Gerçekçi değil.
- D1 %19 -> %40 (21 puan): kolu başına ~70, toplam ~140 = ~28-47 gün. Ancak 21 puanlık etki neredeyse bir "yeniden tasarım" büyüklüğü.
- Sonuç: A/B testi yerine (a) nitel gözlem, (b) büyük etkili önce/sonra karşılaştırma (haftalık kohort, aynı kanal), (c) Play Console deneylerinde yüksek MDE, (d) bütçe artırarak hacim.

| Hafta | Deney / iş | Başarı kriteri | Not |
|---|---|---|---|
| 1-2 | Ölçüm kur: GA4 funnel olayları (§4.2 madde 7), Play vitals kontrolü, tek isim | Hunide her adım görünüyor; çökme < %1,09, ANR < %0,47 | Tüm deneylerin ön koşulu |
| 1-3 | 5-8 kişilik gözlem (NN/g: 5 kullanıcı ≈ %85 sorun; 3 tur x 5 kişi öneriliyor) | İlk testi tamamlayamayan/ne yapacağını bilmeyen sayısı; "kayıt/izin" tıkanması | Hedef kitleye benzer, kanal dışı kişiler; ses/ekran kaydı |
| 3-5 | Onboarding v2: girişsiz ilk test + sonuç ekranı + "yarın hedefi" | Gözlemde tıkanma azalması; funnel `first_quiz_complete` oranı kabaca 2x (büyük etki) | Remote Config bayrağıyla; önce/sonra kohort |
| 5-8 | Paylaşım kartı + 1v1 davet | `share` olay oranı (paylaşan/oturum); paylaşım bağlantısından gelen kurulum sayısı | Küçük hacimde sayı düşük; nitel geri bildirim |
| 6-9 | Mağaza listesi: ikon/ekran görüntüsü deneyi (Play Console, tek yerelleştirme) | Konsolun "tahmini kurulum" ve MDE'si; yalnızca büyük fark | Tek varlık türü |
| 8-10 | Bildirim izni bağlamı + günlük hatırlatma | İzin kabul oranı; bildirimden açılış; kaldırma artışı yok (guardrail) | Önceki rapora göre |
| 9-13 | Bütçe artışı pilotu: Türkiye, yükleme hacmi hedefi, 50x tCPI kuralına uygun bütçe, 2 hafta | >=100 kurulum (öğrenme için ilk 100 dönüşüm) | Değişiklik >%20 yapma; dönüşüm gecikmesi payı |
| 13 | Gözden geçirme | D1/D7 (Play Console retained installers + Firebase), kanal bazında | Bir sonraki 90 gün planı |

Kural: aynı anda tek değişken; her değişiklikten sonra en az 2 hafta; yorum yapmadan önce Firebase A/B Testing "14 gün" beklemesi (Remote Config için). https://firebase.google.com/docs/ab-testing/abtest-config

Kapalı test notu: Yeni kişisel geliştirici hesaplarında üretim erişimi için >=12 test kullanıcısı x 14 gün zorunluluğu var (Google yardımı; tarihi/istisnaları doğrulanamadı) — projenin zaten üretimde olması muhtemel, geçerli değil [GÇ]. https://support.google.com/googleplay/android-developer/answer/14151465

---

## 8) Uygulanabilirlik tablosu

| # | Madde | Uygulanabilirlik | Efor | Risk | Beklenen etki yönü |
|---|---|---|---|---|---|
| 1 | Tek ürün adı (başlık/ikon/ads) | Yüksek | S | Düşük | + (marka/arama; ölçmesi zor) |
| 2 | Funnel olayları (GA4/Firebase) | Yüksek | S-M | Düşük | Ölçüm kapasitesi (dolaylı +) |
| 3 | Android vitals eşik takibi | Yüksek | S | Düşük | Negatif etkiyi önler |
| 4 | Girişsiz ilk test + yarın hedefi | Yüksek | M | Orta (hesap/kayıt akışı değişir) | + D1/D7 (büyüklük bilinmiyor) |
| 5 | Bildirim izni bağlama | Yüksek | S | Düşük | + izin oranı; kötü uygularsa iptal |
| 6 | Paylaşım kartı | Yüksek | M | Düşük | + organik; hacim küçük |
| 7 | 1v1 meydan okuma daveti | Orta (altyapı var mı doğrulanmadı) | M-L | Orta | + organik/sosyal |
| 8 | Play mağaza deneyi (grafik) | Orta (hacim düşük) | S-M | Düşük | Belirsiz; yalnız büyük fark |
| 9 | Özel mağaza listesi (reklam/lapsed) | Düşük-Orta | M | Düşük | Belirsiz, hacim küçük |
| 10 | Yerelleştirme önceliklendirme (Play önerileri) | Orta | S | Düşük | + uzun vadeli |
| 11 | UAC yükleme hacmi, Türkiye, bütçe >= 50x CPI | Orta (bütçe gerekli) | S | Orta (para kaybı) | + hacim; kalite değişken |
| 12 | UAC in-app action (aha olayı) | Düşük (günde <10 olay olası) | M | Orta | + kalite; öğrenme uzun |
| 13 | tROAS | Çok düşük (gelir olayı yok) | M | Orta | — |
| 14 | In-app review zamanlaması | Yüksek | S | Düşük | + puan; ölçmesi zor |
| 15 | Yorumlara cevap | Yüksek | S | Düşük | + güven |
| 16 | TikTok/kısa video içeriği | Orta | M-L (sürekli) | Düşük | + marka araması; belirsiz |
| 17 | Nitel kullanıcı gözlemi (5-8 kişi) | Çok yüksek | S | Düşük | En hızlı öğrenme |

---

## 9) Doğrulanamayanlar / bulunamayanlar

- Play Console Academy içeriği (başlık/ekran görüntüsü/video en iyi uygulamaları) ve grafik asset ölçüleri: ilgili "preview assets" sayfası okunamadı; yalnızca metin limitleri doğrulandı.
- Play'in kurulum-silme oranına verdiği sıralama ağırlığı: resmi kaynak yok (yalnız ikincil ASO blogları).
- Google Ads'te kesin "minimum dönüşüm sayısı": resmi sayı yok (yalnızca "ilk 100 dönüşüm" ve bütçe çarpanları); "günde 10 dönüşüm" ikincil.
- App campaign'e özgü dil/konum hedefleme kuralları, düşük kaliteli trafik işaretleri için resmi sayfa.
- Türkiye'de reklam CPI, ödeme alışkanlıkları (operatör faturası/hediye kartı), trivia türüne özgü D1/D7 kıyası, Türkiye Android/iOS oyun harcama payı.
- 26 dil için pazar büyüklüğü/rekabet verisi (açık kaynak yok; Play Console öneri ekranı konsolda görülmeli).
- Trivia'ya özgü Discord/Reddit vaka çalışması; basın/ürün listeleme siteleri.
- "Aha anı"/ilk 60 sn için akademik kaynak.
- Duolingo %20 retention rakamları (ikincil bloglar tutarsız); %240 "7 günlük seri" iddiası doğrulanamadı.
- Taplytics sayfası tam çekilemedi (yönlendirme); özetler arama sonuçlarından.

---

## 10) Kaynak listesi

Google Ads / Firebase
1. https://support.google.com/google-ads/answer/6247380 (App campaigns nasıl çalışır) [B]
2. https://support.google.com/google-ads/answer/7100895 (App campaign teklif) [B]
3. https://support.google.com/google-ads/answer/12073727 (teklif stratejisi seçimi) [B]
4. https://support.google.com/google-ads/answer/14104492 (App campaign en iyi uygulamalar) [B]
5. https://support.google.com/google-ads/answer/9831945 (in-app eylem sayma) [B]
6. https://support.google.com/google-ads/answer/9176652 (teklif, bütçe, öğrenme) [B]
7. https://support.google.com/google-ads/answer/9234183 (varlık gereksinimleri) [B]
8. https://support.google.com/google-ads/answer/13020501 (öğrenme süresi) [B]
9. https://support.google.com/google-ads/answer/13823256 (Firebase ile uygulama dönüşümleri) [B]
10. https://support.google.com/google-ads/answer/6397604 (Firebase + Ads) [B]
11. https://support.google.com/google-ads/answer/1722072 (konum/dil, arama özeti) [B]
12. https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event [B]
13. https://firebase.google.com/docs/ab-testing/abtest-config [B]

Google Play / Android
14. https://support.google.com/googleplay/android-developer/answer/6227309 (mağaza deneyleri) [B]
15. https://support.google.com/googleplay/android-developer/answer/9867158 (özel listeler) [B]
16. https://support.google.com/googleplay/android-developer/answer/9859152 (liste temelleri/limitler) [B]
17. https://support.google.com/googleplay/android-developer/answer/9866151 (metin kuralları) [B]
18. https://developer.android.com/vitals (eşikler) [B]
19. https://developer.android.com/guide/playcore/in-app-review [B]
20. https://support.google.com/googleplay/android-developer/answer/138230 (puan/yorum) [B]
21. https://support.google.com/googleplay/answer/11906913 (keşif/sıralama) [B]
22. https://support.google.com/googleplay/android-developer/answer/9958766 (keşfedilebilirlik/kalite) [B]
23. https://google.play/business/translationservices/ [B]
24. https://google.play/business/guides/build-a-high-quality-app-or-game/ [B]
25. https://support.google.com/googleplay/android-developer/answer/6263332 (acquisition raporu) [B, arama özeti]
26. https://android-developers.googleblog.com/2018/08/new-organic-acquisition-insights-now.html [B, arama özeti, eski]
27. https://developer.android.com/develop/ui/views/notifications/notification-permission [B]
28. https://support.google.com/googleplay/android-developer/answer/14151465 (kapalı test) [B, arama özeti]

Onboarding / büyüme / pazar
29. https://blog.duolingo.com/growth-model-duolingo [B]
30. https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker/ [B-röportaj/aracı site]
31. https://taplytics.com/blog/duolingo-ab-test-onboarding ; https://taplytics.com/blog/how-duolingo-ran-an-experiment-on-their-streaks-feature [İ, arama özeti]
32. https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/ [B-uzman kuruluş]
33. https://arxiv.org/abs/physics/0509039 (Leskovec vd.) [B-akademik, özet]
34. https://techcrunch.com/2020/07/10/how-thor-fridrikssons-trivia-royale-earned-2-5m-downloads-in-3-weeks/ [İ]
35. https://syntax.fm/show/430/creator-of-wordle-josh-wardle/transcript ; https://www.thequint.com/amp/story/news/world/how-josh-shows-love-backstory-rules-viral-wordle [İ, arama özeti]
36. https://gs.statcounter.com/os-market-share/mobile/turkey [İ]
37. https://datareportal.com/reports/digital-2026-turkey [İ]
38. https://gamedevreports.substack.com/p/adjust-the-mobile-market-of-turkiye [İ]
39. https://wnhub.io/news/finance/item-51073 (AppMagic aktarımı) [İ]
40. https://www.dailysabah.com/turkiye/turkiye-leads-global-social-media-use-with-41-hours-weekly/news [İ]
41. https://www.apptweak.com/en/aso-blog/google-play-ranking-factors ; https://www.apptweak.com/en/aso-blog/guide-to-app-store-localization [İ]
42. https://fraudblocker.com/articles/invalid-click-rate-benchmarks-for-google-ads [İ]
43. https://www.alexanderjarvis.com/discord-doing-things-that-dont-scale [İ]
