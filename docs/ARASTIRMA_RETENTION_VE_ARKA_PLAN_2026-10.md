# Araştırma: Retention (Oyuna Bağlama) ve Arka Plan Çalışma — 2026-10

Tarih: 2026-10-20. Yalnızca araştırma; kod değiştirilmedi. Etiketler: **[B]** birincil kaynak, **[İ]** ikincil kaynak, **[GÇ]** geliştirici çıkarımı (kaynak yok). Pub.dev sürüm bilgileri sayfa çekilirken "X gün önce" göreli tarihle görüldü; kesin tarih doğrulanamadı.

---

## 1) Özet (12 madde)

1. Android'de uygulama kapalıyken "sürekli çalışan" kod YOK; yalnızca sistemin zamanladığı iş (WorkManager), alarm ve FCM var. WorkManager periyodik işin minimum aralığı 15 dk ve sistem optimizasyonlarına göre gecikebilir/atlanabilir. [B] https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work
2. Doze'da işler bakım penceresine ertelenir; while-idle alarmlar saatte 7 ile sınırlı; normal öncelikli FCM ertelenir, yüksek öncelikli FCM kısıtsız. Standby bucket'a göre iş kotası değişir (ör. Rare: 24 saatte ~10 dk). [B] https://developer.android.com/topic/performance/power/power-details
3. Arka plandan foreground service başlatmak Android 12+ hedeflerde yasak (istisnalar: yüksek öncelikli FCM, kullanıcı etkileşimi, kesin alarm ile kullanıcı isteği vb.); Android 14+ hedeflerde tür beyanı ve Play Console formu (açıklama + kullanıcı etkisi + video) zorunlu, video "kullanıcının başlattığı" eylem göstermeli. [B] https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start ; https://support.google.com/googleplay/android-developer/answer/13392821
4. Trivia oyunu için kesin alarm izni gerekmez: dokümana göre kesin alarm yalnızca kullanıcıya dönük hassas zamanlama (alarm saati, takvim) gerektiriyorsa; çoğu uygulama için yaklaşık (inexact) alarm/WorkManager önerilir. `SCHEDULE_EXACT_ALARM` Android 13+ hedefte yeni kurulumda varsayılan reddedilir; `USE_EXACT_ALARM` otomatik verilir ama kullanımı sınırlı ve Play incelemesine tabi. [B] https://developer.android.com/develop/background-work/services/alarms/schedule
5. Android 13+ bildirim izni (`POST_NOTIFICATIONS`) yeni kurulumda kapalı gelir; resmi öneri: değer anlaşılana kadar isteği ertele, kullanıcı eylemine bağla. [B] https://developer.android.com/develop/ui/views/notifications/notification-permission
6. Meşru geri çağırma yolları: (a) zaman damgası tabanlı sayaçlar (uygulama açılınca hesapla), (b) `flutter_local_notifications` ile planlı yerel bildirim, (c) FCM sunucu tetikli bildirim, (d) WorkManager ile hafif içerik ön yükleme, (e) ana ekran widget'ı. [B + GÇ, bkz. §2]
7. Duolingo kendi blogunda streak için ölçülmüş sonuç yayınlıyor: kilometre taşı animasyonu yeni kullanıcıda 7. gün geri dönüşü +%1,7; en fazla 2 streak freeze izni günlük aktif öğrenicide +%0,38 (göreli). Yöntem/örneklem verilmemiş. 7 günlük streak–kurs tamamlama 3,6x ilişkisi korelasyondur. [B] https://blog.duolingo.com/how-duolingo-streak-builds-habit/
8. Duolingo ligleri: haftalık döngü (pazar), benzer alışkanlık/saat dilimindeki öğrenicilerle eşleşme, 10 lig, usulsüz XP'ye entegrite denetimi, profil gizleyerek çıkış; "2018 testinde çok öğrenicide işe yaradı" dışında sayısal etki verilmemiş. [B] https://blog.duolingo.com/duolingo-leagues-leaderboards/
9. Streak/appointment-play gibi mekanikler akademik yazında "temporal dark pattern" olarak tartışılıyor (Zagal, Björk, Lewis 2013). Duolingo da kaybetme kaçınmasına (loss aversion) dayandığını kendi blogunda söylüyor. [B] https://research.chalmers.se/en/publication/177148 ; Duolingo blogu yukarıda
10. Play Ads politikası: oyun içi geçiş reklamı seviye/içerik başında çıkamaz, 15 sn içinde kapatılabilmeli; ödüllü reklam kullanıcı seçimiyse bu kurallardan muaf. Reklam sistem bildirimi taklit edemez. [B] https://support.google.com/googleplay/android-developer/answer/9857753 ; https://support.google.com/googleplay/android-developer/answer/9888077
11. Hedef kitle çocukları da içeriyorsa Families politikası devreye girer: yalnızca Families Self-Certified reklam SDK'ları, kişiselleştirilmiş reklam yok, çocuklara yönelik uygulamada açılışta geçiş reklamı ve kapatılamayan tam ekran reklam yasak; sanal jeton ile gerçek para net ayrılmalı. [B] https://support.google.com/googleplay/android-developer/answer/9893335
12. Firebase A/B Testing (Remote Config) ile mekanik denemesi mümkün: Analytics zorunlu, 1 birincil + en fazla 5 ek metrik, ağırlıklar başladıktan sonra değişmez, "lider" tespiti için ~14 gün, projede en fazla 24 eşzamanlı deney. [B] https://firebase.google.com/docs/ab-testing/abtest-config

---

## 2) Soru-soru bulgular

### Soru 1 — Arka plan iş/çalışma

**1.1 WorkManager ve sınırlar** [B]
- Periyodik iş min. 15 dk (JobScheduler ile aynı); gerçek zaman kısıtlara ve sistem optimizasyonlarına bağlı; kısıtlar (ağ, şarj, pil, boşta) çalıştırmayı geciktirebilir veya tamamen atlatabilir. https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work
- WorkManager kalıcı (yeniden başlatmadan sonra da) ama "hemen çalışması gereken" veya uygulama bitince durabilecek iş için tasarlanmamış; AlarmManager yalnızca hassas alarm/bildirim için, Doze'u uyandırdığı için tekrarlayan arka plan iş için verimsiz. https://developer.android.com/develop/background-work/background-tasks/persistent
- Doze/Standby: ekran kapalı + Doze'da işler bakım penceresine ertelenir; Standby bucket tablosu (yaklaşık, garanti değil): Active 60 dk'da 20 dk iş (Android 16 ile değişti), Working set 4 saatte 10 dk, Frequent 12 saatte 10 dk, Rare 24 saatte 10 dk, Restricted günde bir kez ≤10 dk. WorkManager uygulama görünür değilken JobScheduler kullanır, yani bu kotalara tabidir. https://developer.android.com/topic/performance/power/power-details
- Android 14+: görevler çok sık zaman aşımına uğrarsa sistem uygulamayı Restricted bucket'a koyabilir. https://developer.android.com/develop/background-work/background-tasks/optimize-battery
- Sonuç [GÇ]: uygulama uzun süre açılmazsa bucket düşer (Rare/Restricted); yani "geri dönmeyen" kullanıcıda WorkManager en az güvenilir olduğu anda bile çalışmaz. Geri getirme için sunucu tetikli FCM daha güvenilir.

**1.2 Foreground service (FGS)** [B]
- Android 12+ hedef: arka plandan FGS başlatılamaz (`ForegroundServiceStartNotAllowedException`), istisnalar listesi var (yüksek öncelikli FCM, bildirim/widget etkileşimi, kullanıcı isteği için kesin alarm, BOOT_COMPLETED vb.). https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Android 14+: her FGS için tür + ilgili izin; Android 15: `dataSync` için süre limiti (süre bu sayfada yok, "timeout" sayfasında; çekilmedi → doğrulanamadı). https://developer.android.com/develop/background-work/services/fgs/changes
- Play Console: Android 14+ hedefte tür başına beyan; açıklama, kesintinin kullanıcı etkisi, kullanıcı başlatımını gösteren video. "Otomatik veya arka plan davranışı" video olarak kabul edilmez. https://support.google.com/googleplay/android-developer/answer/13392821
- Sonuç [GÇ]: trivia oyunu için meşru bir FGS türü yok (medya oynatma, konum vb. değil). "Kullanıcıyı geri getirmek için kalıcı bildirimli servis" Play incelemesinde reddedilme/kullanıcı kızgınlığı riski taşır; önerilmez.

**1.3 Kesin alarm** [B]
- Bkz. özet madde 4. Ayrıca: izin kullanıcı tarafından iptal edilirse tüm kesin alarmlar silinir; `canScheduleExactAlarms()` kontrolü şart. https://developer.android.com/develop/background-work/services/alarms/schedule
- `flutter_local_notifications` kendi dokümanında da aynı iki seçeneği veriyor; `USE_EXACT_ALARM` "mağaza incelemesine takılabilir" diyor. https://pub.dev/packages/flutter_local_notifications
- Sonuç [GÇ]: günlük hatırlatma için tam saatte olması şart değil; `inexactAllowWhileIdle` yeterli, izin gerekmez ve politika riski yok. (Çekilen sayfada `androidScheduleMode` örneği `exactAllowWhileIdle` gösteriyor; inexact modun adı paket API referansında doğrulanmalı.)

**1.4 Bildirim izni** [B]
- Android 13+ yeni kurulumda bildirimler kapalı; hedef API 33+ ise istemin zamanını siz yönetirsiniz; değer anlaşıldıktan sonra, bağlam içinde, kullanıcı eylemiyle iste; kullanıcılar günlük bildirim sayısını görüp izni kaldırabilir. https://developer.android.com/develop/ui/views/notifications/notification-permission

**1.5 Flutter paketleri**
- `workmanager`: sürüm 0.10.10 (yayın ~42 gün önce, pub.dev), Android/iOS/macOS destekli; Android WorkManager, iOS Background Tasks sarmalayıcısı; `callbackDispatcher` + `@pragma('vm:entry-point')`. macOS görevleri uygulama kapanınca çalışmaz. iOS BGTaskScheduler sınırı ve 15 dk notu pub sayfasında YOK; kurulum ayrıntısı docs.page'de (çekilemedi). [B] https://pub.dev/packages/workmanager
- `flutter_local_notifications`: 22.3.2 (~7 gün önce), Flutter SDK ≥3.38.1, AGP ≥8.11.1, compileSdk ≥35, desugaring zorunlu (v10+), `desugar_jdk_libs` 2.1.4, Java 17; v16'dan beri manifestte yalnız `POST_NOTIFICATIONS` ve `VIBRATE` bildirir; yeniden başlatmada planlı bildirim için `RECEIVE_BOOT_COMPLETED` + alıcılar elle eklenir; `zonedSchedule` + `timezone` paketi (cihaz saat dilimini tespit etmez, `flutter_timezone` gibi paket gerekir); `matchDateTimeComponents` ile günlük/haftalık tekrar. Sınırlar: Xiaomi/Huawei gibi OEM kısıtları; Samsung'da 500 planlı alarm sınırı; iOS'ta 64 bekleyen bildirim sınırı. [B] https://pub.dev/packages/flutter_local_notifications
- `firebase_messaging`: 17.0.0 (~4 gün önce). [B] https://pub.dev/packages/firebase_messaging . NOT [GÇ]: proje hafızasında `firebase_core 4.13.0 + remote_config ^6.5.6` pini var; `firebase_messaging` 17.x'in firebase_core ile uyumu doğrulanmadı — eklemeden önce uyumlu sürüm (pub.dev "Versions"/changelog) kontrol edilmeli, aksi halde Android derlemesi bozulabilir.
- `home_widget`: 0.10.0 (~32 gün önce); veri `saveWidgetData` + `updateWidget(name:)`; widget'lar Flutter ile DEĞİL yerel (Kotlin/XML/Glance) yazılır; "Dart kodu çağıran etkileşimli widget" özelliği listelenmiş (ayrıntı çekilemedi). [B] https://pub.dev/packages/home_widget

**1.6 FCM ile sunucu tetikleme** [B]
- Bildirim mesajı arka planda sistem tepsisine düşer; veri mesajı `onMessageReceived`'a gelir; bu callback kısa süreli, uzun iş için WorkManager. https://firebase.google.com/docs/cloud-messaging/android/receive
- Yüksek öncelik: Doze'da uyandırabilir ama kullanıcı etkileşimine yol açan (görünür bildirim üreten) mesajlar için; görünür bildirim üretmezse FCM 7 günlük davranışa bakıp önceliği düşürür. Android 13: standby bucket artık yüksek öncelikli FCM sayısını belirlemez, ama bildirim üretmeyen yüksek öncelik düşürülür. https://firebase.google.com/docs/cloud-messaging/android/message-priority ; https://developer.android.com/topic/performance/power/power-details
- FCM, bağlanırken 100'den fazla bekleyen mesaj veya 1 aydan uzun süre bağlanmayan cihazda mesaj atlayabilir. Yani uzun süredir açmayan kullanıcıda FCM de garantili değil. https://firebase.google.com/docs/cloud-messaging/android/receive
- Gönderim ölçeği: yükü yay, :00/:15/:30/:45 civarından kaçın, sunucu tarafı throttling. https://firebase.google.com/docs/cloud-messaging/scale-fcm
- Takvim hatırlatması gibi içerik için FCM yerine yerel planlı bildirim öneriliyor (aynı sayfa).
- Firebase konsolu Android'e özgü alanları (priority) desteklemez; Admin SDK/REST gerekir (Cloud Functions gibi). [B] message-priority sayfası.

**1.7 "Uygulama kapalıyken kullanıcıyı geri getirmenin meşru yolları"** [GÇ, bileşenler yukarıdaki birincil kaynaklara dayanır]
- Zaman damgası sayaçları: "can/enerji doluyor", "günlük ödül hazır", "streak X saat sonra bitiyor" değerleri son kayıtlı zaman + sunucu saatinden uygulama açılınca hesaplanır; arka plan çalışması gerekmez. Firestore `FieldValue.serverTimestamp` bu amaçla kullanılabilir (kullanım ayrıntısı çekilemedi → doğrulanamadı; Firestore API referansına bakılmalı).
- Planlı yerel bildirim: seri bozulmadan önce, günlük meydan okuma hazır olduğunda, tam olarak kullanıcının seçtiği saatte; iş bitince/uygulama açılınca iptal ve yeniden planla.
- FCM: 1v1 düello daveti, arkadaş meydan okuması, lig sonu; kullanıcıya özgü ve talep edilmiş olaylar.
- WorkManager: günlük soru paketini önceden indirme (hafif, ağ kısıtlı). Bildirim göstermek için kullanılırsa kota/ertelenme nedeniyle zaman garantisi yok.
- Ana ekran widget'ı (bkz. Soru 4).

### Soru 2 — Retention mekanikleri

| Oyun | Mekanik | Nasıl çalışıyor / kaynak | Dark pattern tartışması |
|---|---|---|---|
| Duolingo | Streak | Her gün en az bir ders; ilk haftalarda kazanç hissi, sonra kaybetme kaçınması; kilometre taşı animasyonları. [B] https://blog.duolingo.com/how-duolingo-streak-builds-habit/ | Blog, loss aversion'a dayandığını söylüyor; akademik yazında "appointment play" temporal dark pattern [B] https://research.chalmers.se/en/publication/177148 |
| Duolingo | Streak Freeze | 1 günlük streak duraklatma, en fazla 2 adet, 400 gem ile yenileme (blogda ekran görüntüsünde). Slack'in kalıcılığa yardım ettiği iddiası UPenn/UCLA çalışmasına dayandırılmış. [B] aynı blog | Harcama baskısı (gem ile satın alma) bir tartışma konusu [GÇ] |
| Duolingo | Ligler | Bkz. özet 8. [B] https://blog.duolingo.com/duolingo-leagues-leaderboards/ | Sosyal kıyaslama; opt-out (profili gizleme) var |
| Duolingo | Energy (ücretsiz kullanıcı) | Q2 2025 mektubuna göre "yanlışları cezalandırmak yerine doğru seriyi ödüllendiriyor"; DAU, öğrenme süresi ve abone dönüşümünü artırdığı belirtilmiş (özet bir çağrı notundan, mektup doğrudan okunmadı). [İ] arama sonucu; SEC 8-K: https://www.sec.gov/Archives/edgar/data/1562088/000156208825000165/q2fy25duolingo6-30x25share.htm | Enerji = ücretsiz oyunu sınırlama; Supercell zamanlayıcıyla benzer |
| Duolingo | Friend Streaks, Quests, Streak Society | Birincil kaynakta detay bulunamadı. [İ] https://duolingo.deconstructoroffun.com/mechanics/streaks | Doğrulanamadı |
| Duolingo | Finansal göstergeler | Q2 2025: DAU 47,7M (+%40 y/y), ücretli abone 10,9M, gelir 252,3M$ (şirket mektubu; arama sonucu özetinden). [B/özet] SEC linki yukarıda | Bu rakamlar tek bir mekaniğin etkisini ölçmez |
| Wordle / NYT | Günde tek bulmaca + paylaşım | Herkese aynı kelime, 6 hak; Wardle günde bir oyunun "insanları aç bırakmak" için olduğunu söylemiş; 16 Aralık 2021'de "spoiler'sız emoji ızgarası" paylaşma düğmesi eklendi; NYT 2022 başında satın aldı. [İ] https://en.wikipedia.org/wiki/Wordle (NYT/nytco sayfaları bu araçla açılamadı → birincil doğrulanamadı) | Düşük; kullanıcıyı zorlamıyor, bitiş doğal |
| Clash Royale / Supercell | Zamanlayıcılı sandık slotları | Supercell blogu: slot sistemi lansmandan beri var; deneyde Gümüş/Ahşap sandık anında, Crown sandık 24 saat açılıyor; toplam ödül değeri aynı. [B] https://supercell.com/en/games/clashroyale/blog/news/chest-experiment-king-tower-levels-1-9 . "Örtük enerji sistemi" yorumu [İ] https://www.gamedeveloper.com/design/energy-systems-are-back-clash-royale | Zamanlayıcıyı gem ile atlama = temporal/monetary dark pattern kategorisi [B] Zagal 2013 |
| Candy Crush / King | Can sistemi | Birincil (help.king.com) bulunamadı. Fan wiki: 30 dk'da bir can, en fazla 5. [İ] https://candycrush.fandom.com/wiki/Lives . Sistem saatini değiştirerek can yenileme hilesi haberi [İ] — yani istemci saatine güvenmeyin [GÇ] | Bekleme + satın alma baskısı |
| Trivia Crack, Kahoot, QuizUp | — | Birincil kaynak çekilemedi (kahoot.com yönlendirdi). Doğrulanamadı. | — |

Zaman damgası/sunucu saati mantığı [GÇ]: Sunucuda (Firestore serverTimestamp / Cloud Functions) son aktivite ve son streak günü tutulur; "gün" kullanıcının saat dilimine göre hesaplanır; istemci saati yalnız UI geri sayımı için kullanılır, ödül kararı sunucuda verilir (King örneği istemci saati hilesini gösteriyor).

### Soru 3 — Etik/politika sınırları

- **Play Deceptive Behavior:** reklamlar sistem bildirimi/uyarısını taklit edemez; kullanıcı bilgisi ve izni olmadan cihaz ayarı/kısayol/widget/ana ekran değişikliği yapılamaz; gizli/belgelenmemiş özellik yok; başlık/ikon/ekran görüntüleri doğru olmalı. [B] https://support.google.com/googleplay/android-developer/answer/9888077 . Bu sayfada ayrı "bildirim sıklığı" kuralı YOK (sayfa içeriğine göre); Play'in ayrı bildirim spam kuralı doğrulanamadı.
- **Play Ads politikası:** zorla reklam tıklatma yok; kapatılabilirlik cezasız; sahte kapatma düğmesi yasak; uygulamadan çıkarken reklam yasak; oyun içi geçiş reklamı seviye başında yasak, 15 sn kapatılabilir; ödüllü reklam kullanıcı seçimiyse muaf; art arda geçiş reklamı yasak. [B] https://support.google.com/googleplay/android-developer/answer/9857753
- **Families:** hedef kitle beyanı Play Console'da; çocuk görünümlü görsel/terim hedef kitle değerlendirmesini etkileyebilir; karma kitlede tarafsız yaş ekranı ve çocuklara kişiselleştirilmemiş reklam; yalnızca Families Self-Certified SDK'lar; çocuk-ağırlıklı uygulamada kalıcı kimlik (AAID) gönderilmemeli; ödüllü reklam 5 sn sonra kapatılabilir; sanal jeton ile gerçek para net ayrılmalı. [B] https://support.google.com/googleplay/android-developer/answer/9893335 . [GÇ]: trivia/quiz görsel olarak çocuklara da çekici olabilir; hedef kitle beyanı ve AdMob yaş/çocuk ayarı kontrol edilmeli (AdMob'un TFCD/TFUA ayarları bu araştırmada çekilmedi → doğrulanamadı).
- **FTC "Bringing Dark Patterns to Light" (Eylül 2022):** dört kategori — yanıltma/reklam gizleme (sahte geri sayım dahil), iptali zorlaştırma, kilit şartları/ücretleri gömme, veri paylaşımına kandırma; çocuk uygulamaları kapsamda; birleşik kullanımda etki artar. "Nagging/confirmshaming" terimleri basın bülteninde geçmiyor (tam rapor PDF'i okunamadı → doğrulanamadı). [B] https://www.ftc.gov/news-events/news/press-releases/2022/09/ftc-report-shows-rise-sophisticated-dark-patterns-designed-trick-trap-consumers ; rapor sayfası https://www.ftc.gov/reports/bringing-dark-patterns-light
- **AB:** DSA'da "dark patterns" 67. gerekçede anılır, Madde 25 aldatıcı/manipülatif arayüz tasarımını genel olarak yasaklar; resmi metin EUR-Lex'ten çekilemedi → birincil doğrulanamadı. İkincil: Digital Fairness Act danışması "tıklama yorgunluğu, sahte sınırlı seçenek, ısrar (nagging), aciliyet/kıtlık baskısı" gibi uygulamaları ele alıyor. [İ] https://www.osborneclarke.com/insights/digital-fairness-act-unpacked-dark-patterns . DFA'nın güncel durumu kontrol edilmedi.
- **Akademik:** Zagal, Björk, Lewis (2013) temporal, monetary, social capital kategorileri; "appointment play" örnek. [B-özet] https://research.chalmers.se/en/publication/177148 (tam metin okunmadı). Mobil oyunlarda dark pattern taraması: https://arxiv.org/pdf/2412.05039 [B-ön baskı; okunmadı, yalnızca başlık].

### Soru 4 — Trivia türü eksikleri

Birincil kaynak çoğunlukla yok; aşağıdakiler **[GÇ]** (ürün incelemesi/rakip bilgisi, kaynaklı değil) ve kendi kod tabanına karşı doğrulanmadı:
- Soru bildirme/itiraz ("yanlış soru") ve hata düzeltme akışı (Gemini ile üretimde kritik).
- Kategori seçimi + zayıf kategori önerisi; "hızlı tur" (60 sn) modu; günlük tek bulmaca benzeri paylaşılabilir sonuç (Wordle örneği, bkz. Soru 2).
- Arkadaşa meydan okuma bağlantısı/paylaşım kartı; takım/sınıf odası (Kahoot tarzı).
- Sezonluk etkinlikler, kozmetik mağaza (avatar/çerçeve) — ekonomi için ödül zorunluluğu içermeyen alternatif.
- Erişilebilirlik: TalkBack testi, dokunma hedefi, kontrast; Play pre-launch raporu bu kategorileri otomatik denetler. [B] https://developer.android.com/guide/topics/ui/accessibility/testing . (48dp rakamı sayfada yok, Material kılavuzundan; doğrulanamadı.)
- Çevrimdışı mod: önceden indirilen soru paketi (WorkManager ön yükleme ile) [GÇ].
- **Android ana ekran widget'ı:** Android dokümanı widget'ı "atıştırmalık/teaser" olarak tanımlıyor (özet bilgi, uygulamaya yönlendir); `updatePeriodMillis` 30 dk altı dikkate alınmaz (bu bilgi sayfada yok, genel Android bilgisi → doğrulanamadı; daha sık güncelleme için uygulamadan veya WorkManager'dan tetikleme önerilir); Glance (Compose) önerilen araç; widget seçicide önizleme eklenmeli. [B] https://developer.android.com/develop/ui/views/appwidgets/overview . Flutter: `home_widget` (yerel widget gerekir, Flutter ile çizilmez) [B] https://pub.dev/packages/home_widget . Widget içeriği örn. "streak: 5 gün", "günlük meydan okuma hazır" [GÇ]. Play politikası: widget kullanıcının eklemesiyle çıkmalı; kullanıcı bilgisi olmadan ana ekran değişikliği yasak (Deceptive Behavior 2.1).

### Soru 5 — Ölçüm (Firebase)

- A/B Testing (Remote Config): Analytics etkin olmalı; Android/iOS/Web; baz çizgisi + ≥1 varyant; ağırlıklar başlayınca değişmez; hedefleme koşulu (kullanılan koşul deney bitene kadar kilitli, deneyin koşulu çakışanların üstünde olmalı); maruz kalma yüzdesi; opsiyonel aktivasyon olayı (`app_install/app_remove/app_update` olamaz); 1 birincil hedef + ≤5 ek metrik; ~14 gün sonra lider; 300 deney/24 eşzamanlı. [B] https://firebase.google.com/docs/ab-testing/abtest-config
- Remote Config: parametre = anahtar-değer, koşullar (sürüm, ülke, özel sinyal), proje başına 3.000 parametre / 2.000 koşul; gizli veri konmamalı. [B] https://firebase.google.com/docs/remote-config/parameters . Fetch aralığı/throttling ve `onConfigUpdated` ayrıntıları çekilemedi → doğrulanamadı (kaynak: https://firebase.google.com/docs/remote-config/optimization-best-practices, okunmadı).
- Kullanıcı kimliği: Analytics `user_id` kişi tanımlayıcı (e-posta vb.) içermemeli; hash'li iç kimlik kabul. [B] https://firebase.google.com/docs/analytics/userid
- Öneri [GÇ]: Remote Config bayrağı ile her mekaniği kapatılabilir yapın; ölçülecek metrikler D1/D7 geri dönüş, oturum/gün, bildirim izin oranı ve bildirimden açılış; guardrail: bildirim izni iptali, kaldırma (uninstall) oranı. Firebase `app_remove` olayı Android'de uninstall göstergesi olarak kullanılabilir (aktivasyon olayı olamaz, ama metrik olarak olabilir; doğrulanmadı).

---

## 3) Kullanılabilir mekanikler ve güvenli uygulama kuralları

| Mekanik | Nasıl çalışır | Android'de nasıl güvenle uygulanır | Risk |
|---|---|---|---|
| Günlük seri (streak) | Her gün ≥1 oyun/ günlük meydan okuma; sunucuda "son gün" tutulur | Sunucu zaman damgası + kullanıcı saat dilimi günü; istemci saatine güvenme; seri koruma (freeze) ücretsiz kazanılabilir | Kaybetme kaçınması baskısı; küçük çocuklarda hassas. Freeze'i yalnız satın almayla bağlama |
| Streak freeze / "seri kalkanı" | Kaçırılan günü affeder, en fazla N adet (Duolingo 2) | Remote Config ile N ayarlanabilir; jetonla alınabilir, ayrıca oynayarak kazanılabilir | Para/jeton baskısı |
| Günlük ödül/ günlük meydan okuma | 24 saatte bir açılır; tek sefer, paylaşılabilir sonuç (Wordle benzeri) | Sunucu tarafı gün kontrolü; paylaşım için Android share sheet | Düşük |
| Zamanlayıcılı jeton/can yenilenmesi | Sabit sürede bir birim (King 30 dk — ikincil kaynak) | Son güncelleme zamanı + birim süresi → açılışta hesapla; arka plan işi gerekmez | Reklam/IAP ile atlama baskısı; çocuk kitlesinde Families kısıtları |
| Planlı yerel bildirim | Kullanıcının seçtiği saatte günlük hatırlatma; seri bitmeden önce | `flutter_local_notifications` + `zonedSchedule`, inexact mod, izin: `POST_NOTIFICATIONS` bağlam içinde; OEM/yeniden başlatma için `RECEIVE_BOOT_COMPLETED` | Sıklık fazlaysa izin iptali/kaldırma; OEM'de gecikme; Samsung 500 alarm sınırı |
| FCM kullanıcıya özgü bildirim | Düello daveti, arkadaş meydan okuması, lig sonucu | Cloud Functions + Admin SDK; yüksek öncelik yalnız kullanıcı etkileşimi gerektiren (düello daveti) olaylar için; token temizliği | Görünür bildirim üretmeyen yüksek öncelik düşürülür; >1 ay bağlanmayan cihaza ulaşmayabilir |
| WorkManager ön yükleme | Günlük soru paketini/Remote Config'i önceden indir | `workmanager`, ağ kısıtlı, şarjda/Wi-Fi'de; zaman garantisi bekleme | Rare/Restricted bucket'ta çalışmaz; iOS'ta farklı |
| Ana ekran widget'ı | Seri/günlük meydan okuma durumu | `home_widget` + yerel Glance/XML widget; kullanıcı kendisi ekler | Yerel Kotlin kodu gerekir; güncelleme sıklığı sınırlı |
| Ligler (haftalık) | Benzer seviye gruplarında haftalık XP sıralaması | Sunucu haftalık sıfırlama; kopya/hile denetimi (Duolingo gibi), profil gizleme opt-out | Sosyal baskı; hile; bot doldurma şeffaf olmalı |
| Arkadaş meydan okuması | Bağlantı/davet ile düello | Dynamic/deep link, paylaşım menüsü | Spam: otomatik rehber davet göndermeyin |
| Başarımlar / sezonluk etkinlik | Hedef tabanlı ödüller | Remote Config ile açıp kapatma; zaman sınırlı olanlarda açık bitiş zamanı | Sahte kıtlık/geri sayım yasak (FTC) — geri sayım gerçek olmalı |
| Ödüllü reklam | Kullanıcı seçimiyle jeton | AdMob rewarded; çocuk modunda Families kuralları | Zorla/örtük izleme yok; ödül kesin verilmeli |

### Güvenli kurallar listesi [GÇ, dayanak: yukarıdaki politika kaynakları]
1. Bildirim iznini ilk açılışta değil, ilk başarılı oyun/seri sonrası ve bağlam içinde iste (Android dokümanı önerisi).
2. Günlük en fazla 1 hatırlatma bildirimi, bildirim türü başına ayrı kanal ve uygulama içi aç/kapat; kolay opt-out. (Sayı sınırı kaynaklı değil, geliştirici önerisidir.)
3. Sessiz saatler (ör. 22:00–08:00 yerel); saat dilimi değişince yeniden planla.
4. Bildirimde gerçek içerik: "seri 3 saat sonra bitiyor" ancak gerçekse; sahte geri sayım/aciliyet yok (FTC: sahte geri sayım dark pattern örneği).
5. Aylar süren hareketsizlikten sonra bildirim gönderimini azalt/durdur; kaldırmayı artırıp izin iptaline yol açar.
6. Jeton/ödül mantığı sunucuda; istemci saati/yerel sayaçlar yalnız gösterim için; her ödül kayıtlı ve geri alınabilir.
7. Ödül/jeton sahteciliği yok: bildirimden "ödül kazandın" deyip ödül vermemek yasak (Deceptive Behavior: yanıltıcı ifade).
8. Çıkış/kapatma düğmeleri açık; kaçınma duygusu (confirmshaming, "gitme..." metinleri) yok.
9. Çocuk kitlesi ihtimali: yaş ekranı, kişiselleştirilmemiş reklam, Families onaylı SDK, sanal jeton–gerçek para ayrımı.
10. Her mekaniği Remote Config bayrağıyla yayınla; A/B testinde guardrail metrikleri (bildirim iptali, uninstall, şikayet) izle.
11. Widget ve kısayolları kullanıcı rızası olmadan ekleme.

---

## 4) Yasak / riskli liste

- Kalıcı bildirimli "keep-alive" foreground service ile geri getirme: tür uyumsuz, Play beyan formu video şartı, arka plan başlatma kısıtları → **yasak/yüksek ret riski**. [B]
- `USE_EXACT_ALARM` veya `SCHEDULE_EXACT_ALARM`'ı yalnız bildirim zamanlamak için talep etmek: dokümana göre yalnız kullanıcıya dönük hassas zamanlama için; `USE_EXACT_ALARM` Play incelemesine tabi → **riskli**. [B]
- Boot/diğer olay alıcılarıyla arka planda FGS başlatmak: Android 15'te kısıtlar sıkılaşmış → **riskli**. [B] FGS changes sayfası
- Bildirimleri sistem uyarısı gibi gösteren/yanıltıcı reklam veya bildirim → **yasak**. [B] Deceptive Behavior
- Kullanıcı eylemi olmadan ana ekrana kısayol/widget/ikon eklemek → **yasak**. [B]
- Uygulamadan çıkarken reklam, kapatma düğmesi gizleme, art arda geçiş reklamı, seviye başında geçiş reklamı → **yasak**. [B] Ads policy
- Çocuk kitlesinde kişiselleştirilmiş reklam, onaysız reklam SDK'sı → **yasak**. [B] Families
- Sahte geri sayım/sahte kıtlık, iptali gizleme, kilit koşulları gömme → FTC dark pattern örneği, **hukuki risk**. [B] FTC
- Yüksek öncelikli FCM'i görünür bildirim üretmeyen "sessiz uyandırma" için kullanmak: FCM önceliği düşürür → **işe yaramaz/riskli**. [B]
- Gerçek ödül/jeton verilmeyen vaat → **yanıltıcı davranış** [GÇ].

---

## 5) Doğrulanamayanlar

- Android 15 `dataSync` FGS zaman aşımı süresi ("timeout" sayfası çekilmedi).
- iOS BGTaskScheduler kısıtları ve `workmanager`'ın iOS sınırlamaları (workmanager docs.page ve Apple dokümanı çekilemedi; pub.dev sayfasında yok).
- `workmanager` kurulum gereksinimleri ayrıntısı; `home_widget` kurulum ve Dart-çağıran etkileşimli widget ayrıntısı (docs.page).
- `updatePeriodMillis` 30 dk alt sınırı (Android dokümanındaki widget genel bakış sayfasında yok, bir araç genel bilgi olarak belirtti).
- Play'in "bildirim sıklığı" özel politikası; AdMob çocuk (TFCD/TFUA) ayarları.
- DSA Madde 25/Gerekçe 67 ve Madde 28 resmi metni (EUR-Lex çekilemedi); Digital Fairness Act'in güncel durumu; FTC raporunun tam metni (PDF okunamadı).
- Wordle/NYT birincil kaynağı (nytimes.com, nytco.com bu araçla erişilemedi); King'in resmi can kuralları (help.king.com bulunamadı); Trivia Crack, Kahoot, QuizUp'a ait birincil mekanik açıklamaları.
- Duolingo Friend Streaks/Quests/Streak Society ve Duolingo bildirim stratejisine dair birincil veri; Duolingo "CURR %21 / churn %40 / DAU 450%" iddiaları yalnız ikincil bloglarda (kullanılmadı).
- `firebase_messaging` 17.x ile projedeki firebase_core 4.13.0 pini uyumu.
- Remote Config minimumFetchInterval/throttling ve Firestore serverTimestamp kullanım ayrıntıları.
- Soru 4'teki "kullanıcı beklentileri" maddeleri birincil kaynakla doğrulanmadı (tümü GÇ).

---

## 6) Kaynak listesi

Birincil [B]
- https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work
- https://developer.android.com/develop/background-work/background-tasks/persistent
- https://developer.android.com/develop/background-work/background-tasks/optimize-battery
- https://developer.android.com/topic/performance/power/power-details
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/develop/background-work/services/fgs/changes
- https://developer.android.com/develop/background-work/services/alarms/schedule
- https://developer.android.com/develop/ui/views/notifications/notification-permission
- https://developer.android.com/develop/ui/views/appwidgets/overview
- https://developer.android.com/guide/topics/ui/accessibility/testing
- https://support.google.com/googleplay/android-developer/answer/13392821
- https://support.google.com/googleplay/android-developer/answer/9888077
- https://support.google.com/googleplay/android-developer/answer/9857753
- https://support.google.com/googleplay/android-developer/answer/9893335
- https://firebase.google.com/docs/cloud-messaging/android/receive
- https://firebase.google.com/docs/cloud-messaging/android/message-priority
- https://firebase.google.com/docs/cloud-messaging/scale-fcm
- https://firebase.google.com/docs/ab-testing/abtest-config
- https://firebase.google.com/docs/remote-config/parameters
- https://firebase.google.com/docs/analytics/userid
- https://pub.dev/packages/workmanager
- https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/packages/firebase_messaging
- https://pub.dev/packages/home_widget
- https://blog.duolingo.com/how-duolingo-streak-builds-habit/
- https://blog.duolingo.com/duolingo-leagues-leaderboards/
- https://www.sec.gov/Archives/edgar/data/1562088/000156208825000165/q2fy25duolingo6-30x25share.htm (arama sonucu özeti üzerinden; doğrudan okunmadı)
- https://supercell.com/en/games/clashroyale/blog/news/chest-experiment-king-tower-levels-1-9
- https://www.ftc.gov/news-events/news/press-releases/2022/09/ftc-report-shows-rise-sophisticated-dark-patterns-designed-trick-trap-consumers
- https://www.ftc.gov/reports/bringing-dark-patterns-light
- https://research.chalmers.se/en/publication/177148 (yalnız özet; tam metin okunmadı)

İkincil [İ]
- https://en.wikipedia.org/wiki/Wordle
- https://candycrush.fandom.com/wiki/Lives
- https://www.gamedeveloper.com/design/energy-systems-are-back-clash-royale
- https://duolingo.deconstructoroffun.com/mechanics/streaks
- https://www.osborneclarke.com/insights/digital-fairness-act-unpacked-dark-patterns
- https://arxiv.org/pdf/2412.05039 (okunmadı)
