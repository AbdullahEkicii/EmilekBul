# Araştırma E: İçerik Kalitesi, Zorluk Kalibrasyonu ve Kişiselleştirme — 2026-10

Tarih: 2026-10-20. Yalnızca araştırma; kod değiştirilmedi. Önceki rapor (retention/arka plan) tekrar edilmedi: `docs/ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md`.

Etiketler: **[B]** birincil (resmi doküman / hakem denetimli veya arXiv makale), **[İ]** ikincil (blog, özet, arama özeti), **[GÇ]** geliştirici çıkarımı/tahmin (kaynak yok; varsayım belirtilir). Fiyatlar ve model adları 2026-10-20'de Google sayfalarından çekildiği gibidir; değişebilir.

---

## 1) Özet (15 madde)

1. Gemini'de yapılandırılmış JSON çıktı yalnızca sözdizimini garanti eder; Google doküman bunu açıkça yazar: şemaya uyum ≠ doğruluk, değerler uygulama tarafında ayrıca doğrulanmalı. [B] https://ai.google.dev/gemini-api/docs/structured-output
2. "Grounding with Google Search" (Gemini 3+ modellerde): aylık 5.000 ücretsiz arama, sonrası 1.000 arama başına 14 $; modelin çalıştırdığı HER sorgu faturalanır (Gemini 2.5'te istem başına, 1.000 grounded prompt başına 35 $). [B] https://ai.google.dev/gemini-api/docs/google-search ; https://ai.google.dev/gemini-api/docs/pricing
3. Gemini 3 için Google, sıcaklığı varsayılan 1.0'da tutmayı "şiddetle" öneriyor; düşürmek döngü/performans düşüşü yapabilir. "Düşük sıcaklık ile doğruluk" varsayımı yeni modellerde resmi olarak önerilmiyor. [B/arama özeti] https://ai.google.dev/gemini-api/docs/gemini-3
4. Halüsinasyon azaltmada kanıtlı genel teknikler: self-consistency (çoklu örnek + çoğunluk), SelfCheckGPT (örnekler arası tutarsızlık = halüsinasyon sinyali), Chain-of-Verification (doğrulama soruları), FActScore (atomik olgu + güvenilir kaynak). Hiçbiri trivia sorusu üretimi için doğrudan ölçülmedi. [B] bkz. §2
5. LLM ile üretilen çeldirici (distractor) kalitesi: öğretmen çalışmasında ChatGPT çeldiricilerinin ortalama %53'ü "olduğu gibi kullanılabilir" bulundu (Bitew vd., öğretmen derecelendirmesi); yani yaklaşık yarısı elle düzeltme gerektirir. [B] https://arxiv.org/abs/2307.16338v1
6. Wikidata yapılandırılmış verisi CC0 (atıf zorunlu değil); Wikipedia/Wikidata metin sayfaları CC BY-SA 4.0. Open Trivia DB verisi CC BY-SA 4.0. Wikidata tabanlı üretim lisans açısından en temiz yol; ama Wikipedia metninden soru üretmek atıf+share-alike getirebilir (hukuki görüş değildir). [B] https://www.wikidata.org/wiki/Wikidata:Licensing ; https://opentdb.com/api_config.php
7. Zorluk için küçük veride pratik yöntem: soru başına doğru/yanlış sayaçları + Wilson alt/üst sınırı veya Beta öncülü ile yumuşatılmış doğru oranı; Elo (oyuncu+soru) bunun akışlı ve dengeli genellemesi. Pelánek, Elo'nun "basit, sağlam, etkili" olduğunu savunuyor ve uygulama kılavuzu veriyor. [B] https://www.fi.muni.cz/~xpelanek/publications/CAE-elo.pdf (özet); Wilson: [İ] https://www.evanmiller.org/how-not-to-sort-by-average-rating.html
8. Duolingo Birdbrain: öğrenci bilgisi ve egzersiz zorluğunu sürekli tahmin eden ML modeli; Ekim 2020'de derslerin >%20'si bununla kişiselleştirilmiş; A/B'de daha çok öğrenme ve geri dönüş bildirilmiş (yöntem/örneklem verilmemiş). Blog Elo/IRT'den söz etmiyor. [B-blog] https://blog.duolingo.com/learning-how-to-help-you-learn-introducing-birdbrain/
9. Öğrenme için "tatlı nokta" kavramı: Wilson vd. 2019, ikili sınıflandırmada SGD tabanlı öğrenme için ~%85 eğitim doğruluğu (~%15,87 hata) optimum; yazar kesin yüzdenin değil "tatlı nokta"nın önemli olduğunu söylüyor, ve bu insan trivia'sı için doğrudan kanıtlanmış değil. [B] https://pmc.ncbi.nlm.nih.gov/articles/PMC6831579 ; arama özeti: https://neurosciencenews.com/learning-optimized-15171/
10. Test etkisi: Roediger & Karpicke 2006'da geciktirilmiş testte (2 gün/1 hafta) test edilen madde, yeniden çalışılana göre belirgin daha iyi hatırlandı (metin parçaları, serbest hatırlama; trivia değil). Cepeda vd. 2006 meta-analizi: 317 deney/184 makale, optimum aralık, ne kadar uzun süre hatırlanması isteniyorsa o kadar uzuyor. [B] §5
11. Yüksek güvenle verilen yanlış cevaplar geri bildirimle daha kolay düzelir (hypercorrection); genel bilgi soruları bu literatürün standart malzemesi. Trivia'da "emin olduğun yanlış" sonrası doğru cevabı net göstermek öğrenmeyi destekler. [B] https://pmc.ncbi.nlm.nih.gov/articles/PMC4036076
12. Google Play UGC politikası: kullanıcılar içerik görüyorsa/ekliyorsa uygulama içi içerik/kullanıcı raporlama ve engelleme işlevi şart, bildirimlere yanıt verilmeli. Projedeki "soru bildir" özelliği bu açıdan doğru yönde; moderasyon yanıtı ve ToS tarafı kontrol edilmeli. [B] https://support.google.com/googleplay/android-developer/answer/9876937
13. Çeviri yeterli değil: Global-MMLU'da sorunun %28'i kültüre özgü bilgi gerektiriyor; coğrafya sorularının %84,9'u Kuzey Amerika/Avrupa odaklı (MMLU analizi). BLEnD (NeurIPS 2024 D&B): 16 ülke/13 dilde 52,6 bin soru-cevap; modeller yaygın kültürlerde çok daha iyi, farklar en iyi modelde kısa cevapta %57,34'e kadar. [B] https://arxiv.org/abs/2412.03304 ; https://arxiv.org/abs/2406.09948
14. IARC/Play içerik derecelendirmesi: yanlış beyan uygulamanın kaldırılmasına/askıya alınmasına yol açabilir; LLM üretimli içerik beyanı etkileyebilir (ör. şiddet/nefret içeren sorular) — anket içerik değişince yeniden doldurulmalı. [B] https://support.google.com/googleplay/android-developer/answer/9859655
15. En yüksek getiri/maliyet: (a) soru başı sayaç + otomatik zorluk yeniden etiketleme, (b) bildirim eşiği + Wilson tabanlı otomatik gizleme, (c) üretim anında ucuz "ikinci geçiş" doğrulama (batch), (d) yalnızca "doğrulanabilir olgusal" kategorilerde grounding/Wikidata.

---

## 2) LLM doğruluk ve halüsinasyon

### 2.1 Akademik temel
- **Halüsinasyon anketi** (Huang vd., arXiv:2311.05232): LLM'lerin "inandırıcı ama olgusal olmayan" içerik üretmeye yatkın olduğunu, halüsinasyon nedenleri/tespiti/azaltma yöntemlerini derliyor; RAG'in de sınırları olduğunu belirtiyor. Sayfada yalnızca özet okundu; taksonomi ayrıntısı doğrulanmadı. [B] https://arxiv.org/abs/2311.05232
- **Self-consistency** (Wang vd., arXiv:2203.11171, ICLR 2023): CoT'te açgözlü kodlama yerine çoklu akıl yürütme yolu örnekleyip en tutarlı cevabı seçiyor. Özette bildirilen iyileşmeler: GSM8K +17,9, AQuA +12,2, SVAMP +11,0, StrategyQA +6,4, ARC-challenge +3,9 (mutlak mı göreli mi ve hangi model olduğu özet sayfasında yok; ölçümler akıl yürütme/matematik görevleri, trivia değil). [B] https://arxiv.org/abs/2203.11171
- **SelfCheckGPT** (arXiv:2303.08896): kara kutu, kaynaksız; aynı soruya çoklu örnek karşılaştırarak halüsinasyon tespiti; WikiBio üzerinde GPT-3 ile üretilmiş, elle etiketlenmiş biyografi cümleleri; cümle düzeyinde AUC-PR'de gri kutu yöntemlerden iyi (sayısal değerler okunan sayfada yok). [B] https://arxiv.org/abs/2303.08896
- **Chain-of-Verification** (arXiv:2309.11495): taslak → doğrulama soruları → bağımsız cevap → nihai yanıt; Wikidata liste soruları, kapalı kitap MultiSpanQA ve uzun metinde halüsinasyonu azalttığı bildirilmiş (sayılar okunmadı). [B] https://arxiv.org/abs/2309.11495
- **FActScore** (arXiv:2305.14251): metni atomik olgulara ayırıp güvenilir kaynakla desteklenme yüzdesi; ChatGPT için %58 (kişi biyografileri, insan değerlendirmesi); otomatik tahminci hata oranı <%2 bildirilmiş; 13 model/6.500 metin otomatik değerlendirilmiş. Kanıt: biyografi alanı, trivia sorusu değil. [B] https://arxiv.org/abs/2305.14251
- **LLM çeldirici kalitesi:** Bitew vd. (arXiv:2307.16338): ChatGPT + soru bankasından örnekle istem; öğretmen çalışmasında sunulan çeldiricilerin ortalama %53'ü yüksek kalite (hemen kullanılabilir). [B] https://arxiv.org/abs/2307.16338v1. Programlama sorularında 1.071 öğrenci/22 sınıf verisiyle GPT-4o'nun insan yazımı işlevsel çeldiricilerin yaklaşık %50'sini eşleştirdiği bildirilmiş (arama özeti, NSF PAR; birincil metin açılmadı). [İ] https://par.nsf.gov/biblio/10613695-generating-effective-distractors-introductory-programming-challenges-llms-vs-humans
- **Boşluk:** Doğrudan "LLM üretimli genel kültür trivia'sında hata oranı" ölçen bir birincil çalışma bulunamadı (bkz. §9).

### 2.2 Doğrulama stratejileri (bu proje için)
| Strateji | Dayanak | Not |
|---|---|---|
| Şema + kural doğrulama (4 seçenek, tek doğru, seçenekler tekrar etmiyor, uzunluk sınırı, dil kodu, cevap indeksi aralıkta) | Google: şema uyumu doğruluğu garanti etmez [B] https://ai.google.dev/gemini-api/docs/structured-output | Çok ucuz, yerel yapılabilir; "çok uzun soru" sorununu doğrudan çözer |
| İkinci model/ikinci geçiş "cevap anahtarı doğrulayıcı": soruyu cevapsız ver, model kendi cevabını bulsun; üretilen anahtarla uyuşmazsa at | Self-consistency/SelfCheckGPT mantığı [B]; trivia için doğrudan ölçüm yok | Uyuşmazlık = belirsiz/yanlış sinyali; fakat model aynı yanlışı tekrarlayabilir (ortak hata) [GÇ] |
| Çoklu örnek tutarlılığı (3 örnek, çoğunluk) | Self-consistency [B] | 3x maliyet; ucuz modelle (Flash-Lite) ve Batch ile azaltılır |
| Grounding with Google Search ile doğrulama | Resmi doküman [B]; fiyat yukarıda | Yalnızca ucuz ön elemeden geçen, "tartışmalı/zamana duyarlı" sorulara uygulanabilir; bir istem birden çok arama = birden çok ücret |
| Wikidata/Wikipedia'dan kaynaklı üretim | Wikidata CC0 [B] | Yapılandırılmış olgu kategorilerinde (başkent, nüfus, doğum yılı, yazar) hata riski çok düşük; çeldirici = aynı özellikten (property) başka değerler (MemToC makalesinde benzer teknik anılıyor, arama özeti [İ]) |
| Kaynak URL'li soru alanı | Grounding `url_citation` ek açıklaması (start/end index, url, title) [B] | Havuza `sourceUrl` saklayıp bildirim incelemesini hızlandırır |

### 2.3 Gemini özelinde
- **Grounding:** `google_search` aracı; model aramaya kendisi karar verir; yanıtta `url_citation` açıklamaları ve UI'da gösterilmek üzere `search_suggestions` HTML parçası döner. Gösterim zorunlulukları Hizmet Koşulları'nda; sayfada ayrıntı yok. [B] https://ai.google.dev/gemini-api/docs/google-search. **Doğrulanamadı:** zorunlu gösterim kuralları (bkz. §9). Yani önbelleğe alınan sorularda `search_suggestions` göstermek zorunlu mu bilinmiyor; ilke olarak grounding'i sadece sunucu/üretim hattında "doğrulama aracı" olarak kullanıp çıktı metnini göstermemek, ancak bu yorum hukuki doğrulama gerektirir [GÇ].
- **Fiyat (2026-10-20, ücretli Standard, 1M token):** Gemini 3.5 Flash-Lite 0,30 $ giriş / 2,50 $ çıkış; 3.1 Flash-Lite 0,25 / 1,50; 2.5 Flash-Lite 0,10 / 0,40; 3 Flash Preview 0,50 / 3,00; 3.6 ve 3.8 Flash 0,75 / 3,75 (2026 sonuna kadar), 1 Ocak 2027'den 1,50 / 7,50. Çıkış fiyatı düşünme token'larını içerir. Batch: %50 indirim. [B] https://ai.google.dev/gemini-api/docs/pricing
- **Batch API:** %50 maliyet, hedef süre 24 saat, JSONL en çok 2 GB, sonuç 6 hafta saklanır, 48 saatten uzun işler sona erer, iş oluşturma idempotent değil. Önceden doğrulama/yeniden etiketleme için uygun (anlık oyun akışı için değil). [B] https://ai.google.dev/gemini-api/docs/batch-api
- **Güvenlik filtreleri:** Gemini 2.5+ modellerde ayarsız kategoriler varsayılan "Off"; kategoriler harassment, hate_speech, sexually_explicit, dangerous_content, jailbreak; engellemede HTTP 400. Çocuk güvenliği korumaları ayarlanamaz. Nefret söylemi/hassas konu riski için eşikleri açıkça `block_medium_and_above` gibi ayarlamak makul [GÇ]. [B] https://ai.google.dev/gemini-api/docs/safety-settings
- **Sıcaklık:** Gemini 3 için varsayılan 1.0 önerilir (arama özeti; birincil sayfa doğrudan açılmadı). [B/arama özeti] https://ai.google.dev/gemini-api/docs/gemini-3 . Eski model (2.5) kullanılıyorsa düşük sıcaklığın etkisi bu çalışmada ölçülmedi.

### 2.4 Lisans notları
- Wikidata ana/Property/Lexeme/EntitySchema ad alanlarındaki yapılandırılmış veri **CC0**; atıf gerekmez. Diğer ad alanlarındaki metin **CC BY-SA 4.0**. [B] https://www.wikidata.org/wiki/Wikidata:Licensing
- Open Trivia DB: tüm veri **CC BY-SA 4.0**; API sınırı IP başına 5 sn'de bir istek; oturum jetonu aynı soruyu tekrar vermeyi engelliyor (6 saat hareketsizlikte silinir); zorluk Kolay/Orta/Zor, soru durumları Total/Pending/Verified/Rejected. Share-alike nedeniyle ticari uygulamada doğrudan kopyalama yerine yalnızca "fikir/biçim" referansı olarak kullanmak güvenli [GÇ, hukuki görüş değil]. [B] https://opentdb.com/api_config.php
- Wikipedia metninin CC BY-SA 4.0 olması **bu çalışmada Wikipedia'dan doğrulanmadı**; Wikidata sayfası "diğer ad alanları metni CC BY-SA 4.0" diyor ama Wikipedia lisansını kendi sayfasından teyit etmedim.
- **Wikidata Query Service** zaman aşımı/kullanım limiti/User-Agent politikası okunan sayfada yoktu → doğrulanamadı.

---

## 3) Zorluk kalibrasyonu

### 3.1 Kuram
- **IRT:** Rasch/1PL modelinde yalnızca madde zorluğu b ve yetenek θ vardır (ayırt edicilik a=1 sabit); 2PL'de a serbest. [B/ikincil barındırma] Baker, *The Basics of Item Response Theory* (ERIC): bkz. arama sonucu https://rasch.org/rmt/rmt161o.htm ; metin barındıran https://www.fisica.net/enem/The-Basics-of-Item-Response-Theory.pdf (üçüncü taraf kopya; ERIC orijinaliyle karşılaştırılmadı → [İ]).
- **Elo eğitimde** (Pelánek 2016, Computers & Education, DOI 10.1016/j.compedu.2016.03.017): öğrenci cevabı = öğrenci ile madde arasında "maç"; hem beceri hem madde zorluğu çevrim içi tahmin edilir; varyantlar, alternatiflerle karşılaştırma, coğrafya olgularının uyarlanabilir pratiği vaka çalışması, uygulama kılavuzu. [B] özet: https://is.muni.cz/publication/1376317 ; yazar elyazması: https://www.fi.muni.cz/~xpelanek/publications/CAE-elo.pdf (tam metin bu çalışmada okunmadı).
- **Olguların uyarlanabilir pratiği:** Papoušek, Pelánek, Stanislav (EDM 2014): sistem üç parça (önceki bilgi, güncel bilgi, soru seçimi); Elo ve PFA tabanlı modellerin çevrim içi için yeterince doğru ve basit olduğu savunuluyor. [B] https://www.fi.muni.cz/~xpelanek/publications/EDM14-adaptive-facts.pdf ; 2017 UMUAI uzantısı (Pelánek vd., 26(1):89-118): https://www.ics.muni.cz/en/research/publications/1359654
- **Duolingo İngilizce Testi** (Settles, LaFlair, Hagiwara; TACL 8:247-263, 2020): ML/NLP ile ölçek ve madde zorluğu tahmini, insan pilot testi gerektirmeden; skorların diğer yüksek riskli İngilizce testlerle anlamlı hizalandığı bildirilmiş. Arama özetinde "IRT" terimi geçmiyor; IRT tabanlı olduğu bu çalışmada doğrulanamadı. [B] https://aclanthology.org/2020.tacl-1.17 ; https://research.duolingo.com/papers/settles.tacl20.pdf
- **Birdbrain** (Duolingo blog): bkz. özet 8. Elo'dan veya IRT'den söz etmiyor; dolayısıyla "Duolingo Elo kullanıyor" diye yazılmamalı. [B-blog]
- **LLM ile zorluk tahmini:** Zotos vd. (arXiv:2412.11831): model belirsizliği özellik olarak eklenince zorluk tahmini iyileşiyor (USMLE ve CMCQRD'de SOTA bildirilmiş; arama özeti). [İ] https://arxiv.org/pdf/2412.11831 . arXiv:2601.09953: LLM'ler zorluğun doğrudan yargıcı olarak zayıf, simüle öğrenci + IRT daha umut verici (NAEP madde istatistikleriyle korelasyon ~0,75-0,82, arama özeti; birincil sayfa açılmadı). [İ] https://arxiv.org/abs/2601.09953v1 . BEA 2024 ortak görev (Rogoz & Ionescu): zorluk tahmini, yanıt süresi tahmininden daha zor. [İ] https://aclanthology.org/2024.bea-1.41. **Çıkarım [GÇ]:** Gemini'ye "zorluk etiketi ver" demek güvenilir değil; gerçek oyuncu verisi asıl ölçüt olmalı, LLM etiketi yalnızca başlangıç öncülü.

### 3.2 Küçük veriyle pratik yöntem (sayaç tabanlı) [GÇ, kaynaklı bileşenlerle]
Soru dokümanında (zorluk dilden bağımsız olduğundan temel soru kimliğinde; dil çevirisi ayrı alt belgede kalsın):
- `shown` (gösterildi), `correct` (doğru), `timeSumMs` veya `fastCount` (isteğe bağlı), `diffLabel` (Kolay/Orta/Zor/İmkansız), `diffUpdatedAt`.
- **Yumuşatılmış doğru oranı:** `p = (correct + α) / (shown + α + β)` (öncül, ör. α=β ya da LLM etiketine göre kayık öncül) veya Wilson alt/üst sınırı [İ] https://www.evanmiller.org/how-not-to-sort-by-average-rating.html. Etiket yalnızca `shown ≥ N_min` (ör. 30-50, [GÇ: ayarlanmalı]) sonrası güncellenir; 4 şıklı soruda şans doğruluğu 0,25'tir, bu yüzden ham oranı şansa göre düzeltmek gerekir: `p_adj = (p - 0.25) / 0.75` [GÇ; klasik şans düzeltmesi, bu çalışmada kaynaklanmadı].
- **Eşikler (başlangıç önerisi, kalibre edilmeli) [GÇ]:** p_adj > ~0,85 Kolay; 0,55-0,85 Orta; 0,25-0,55 Zor; <0,25 İmkansız. Eşikler oyuncu popülasyonuna bağlıdır; ilk 1-2 haftada gerçek dağılımın yüzdeliklerinden (ör. çeyrekler) türetmek daha sağlam.
- **Çok oyunculu önyargı:** Aynı soruyu kolay seviyede gören kitle ile zor seviyede gören kitle farklı olur; ham oran seviye-koşullu hesaplanmalı veya Elo kullanılmalı (Elo oyuncu beceri tahminiyle düzeltir). [GÇ]
- **Elo geçişi (M efor):** Her cevapta `P(doğru) = 1/(1+10^{-(θ_oyuncu - b_soru)/s})`; her ikisi `K·(sonuç - P)` ile güncellenir; K belirsizlik azaldıkça düşürülür (Pelánek'in uyarlamaları). [B] CAE-elo.pdf (tam metin okunmadı → formül ayrıntısı [GÇ]). Şans payı için tahmin edilen 4 şıklı tabanı ekleyin (`P = 0.25 + 0.75·σ(...)`) [GÇ].
- **Firestore'da tutma:** Tek doküman yazma sıklığı yüksek soru için çakışma riski; resmi dağıtık sayaç çözümü shard'lı `count` alanları ve `FieldValue.increment` (10 shard = 10x yazma kapasitesi). [B] https://firebase.google.com/docs/firestore/solutions/counters . Küçük/orta trafikte sayaçları cihazda biriktirip toplu (örn. oyun sonu batch) yazmak yeter [GÇ]; tek doküman başına ~1 yazma/sn sınırı resmi kotalar sayfasında teyit edilemedi (yalnızca counters sayfasının "her shard saniyede bir artırma" ifadesi var). 1 MiB doküman, transaction 270 sn. [B] https://firebase.google.com/docs/firestore/quotas
- **Maliyet:** Spark/ücretsiz kota: günde 50.000 okuma, 20.000 yazma, 20.000 silme, 1 GiB depolama; birim fiyatlar çekilen sayfada yok (Cloud pricing sayfasına yönlendiriyor → doğrulanamadı). [B] https://firebase.google.com/docs/firestore/pricing . Her cevap için 1 yazma yerine cevapları günlük toplu "özet" belgesine yazmak (ör. gün başına 1 yazma/kullanıcı + soru başı artış yalnızca eşiğe yaklaşınca) maliyeti düşürür [GÇ].
- **Yerel SQLite:** Cihazdaki her soru için `localShown/localCorrect/lastSeen/ease` tutulur → hem kişiselleştirme (§5) hem havuz sayacına toplu gönderim için kaynak [GÇ].

### 3.3 Hedef doğruluk bandı
Wilson vd. 2019: "%85 kuralı" ikili sınıflandırma + SGD için türetilmiş; yazar sayıdan çok tatlı nokta kavramını vurgular. [B] https://pmc.ncbi.nlm.nih.gov/articles/PMC6831579 . İnsan trivia'sında %85 doğru hedefi KANITLANMADI; "oyuncuya yakın zorluk" hedefi için başlangıç olarak ~%70-85 aralığı denenip A/B ile ayarlanmalı [GÇ].

---

## 4) Geri bildirim döngüsü ve moderasyon

### 4.1 Politika zorunlulukları
- Google Play UGC: kullanıcı içeriği görünüyorsa uygulama içi içerik/kullanıcı raporlama ve engelleme işlevi; kabul edilebilir kullanım koşulları; makul moderasyon; sürekli yanıtsız kalmak ihlal örneği. Sayfada trivia'ya özel hüküm yok; LLM üretimli içeriğin UGC sayılıp sayılmadığı net değil → **doğrulanamadı**, ama kullanıcı soru ekliyorsa kesin UGC. [B] https://support.google.com/googleplay/android-developer/answer/9876937
- Uygunsuz içerik: nefret söylemi (korunan gruplar), gereksiz şiddet, hassas olaylardan duyarsızca yararlanma/inkâr yasak; eğitsel bağlam genelde izinli. [B] https://support.google.com/googleplay/android-developer/answer/9878810

### 4.2 Proje için tasarım [GÇ, sayaç/Wilson bileşenleri kaynaklı]
- **Bildirim nedeni sınıflandırması:** yanlış cevap anahtarı / belirsiz-çift anlam / eski bilgi / çok uzun / yanlış dil-çeviri / uygunsuz. Sebep başına ayrı sayaç; "uygunsuz" tek bildirimde bile hızlı gizleme.
- **Eşik tabanlı otomatik gizleme:** `reports / shown` oranının Wilson **alt** sınırı eşiği aşarsa gizle (az görüntülemeyle tek bildirim yanlış alarm üretmesin); örn. `reports ≥ 3` ve alt sınır > ~0,02 [eşik GÇ]. Gizlenen soru "inceleme kuyruğu"na düşer.
- **Soruyla çelişen davranış sinyali:** `p_adj` çok düşük veya şık dağılımı tek bir "yanlış" şıkta yığılıyorsa (cevap anahtarı hatası şüphesi; çoğunluk yanlış şıkkı seçiyor) otomatik inceleme [GÇ].
- **Kötüye kullanma önleme:** kullanıcı başına soru başına tek bildirim (`reportsByUser/{uid}`), günlük bildirim sınırı, hesap yaşı/oyun sayısı ağırlığı, bildirimlerin doğru çıkma oranına göre kullanıcı güvenilirliği; kendi bildirdiği sorunun yerelde gizlenmesi zaten var. Dağıtık sayaç (shard) yalnızca bildirimler çok yoğunsa gerekir. [GÇ] Firestore sayaç kalıbı: https://firebase.google.com/docs/firestore/solutions/counters
- **Moderasyon iş akışı:** Open Trivia DB'de soru durumları Pending/Verified/Rejected [B] https://opentdb.com/api_config.php — havuza `status: active|flagged|retired|verified` ve `reviewedBy` eklemek benzer akış verir [GÇ]. Gizlenen soruyu LLM'e ikinci geçiş doğrulamasına gönderip (grounding'li) otomatik "yeniden-etkinleştir / emekli et" önermek; kararı insan onaylar.
- **Topluluk doğrulaması (oylama):** "Bu soru doğru/net mi?" 👍/👎 sonrası yanıt ekranında; Wilson alt sınırıyla sıralama/kalite skoru [İ] https://www.evanmiller.org/how-not-to-sort-by-average-rating.html. Oylama manipülasyonu için cihaz/hesap başına tek oy.
- **Bildirim yanıtı (Play UGC):** bildirim alındı mesajı + sonuçlandığında soru emekli etme kaydı; sürekli yanıtsız kalmak Play politikasında ihlal örneği.

---

## 5) Kişiselleştirme / uyarlanabilir zorluk

### 5.1 Bilimsel temel
- **Flow:** Csikszentmihalyi'nin "zorluk-beceri dengesi" çerçevesi; oyun bağlamında Chen (CACM 2007) bunu oyun tasarımına uygulayan görüş yazısı (ampirik çalışma değil) [İ-viewpoint] https://cacmb4.acm.org/magazines/2007/4/5692-flow-in-games-and-everything-else/fulltext ; Sweetser & Wyeth (2005) GameFlow modeli, 8 öğe, Computers in Entertainment 3(3) [B-arama özeti] https://ntnu.no/wiki/download/attachments/197920535/GameFlow.pdf?api=v2 . Arama sonuçlarında bazı araştırmacıların dengeyi sorguladığı ve bazı ölçümlerde "aşırı zorluğun" can sıkıntısından daha keyifli çıkabildiği belirtilmiş (ikincil özet; birincil makale doğrulanmadı). Csikszentmihalyi'nin orijinal kitabı bu çalışmada okunmadı.
- **Test etkisi:** Roediger & Karpicke 2006 (Psychological Science 17(3):249-255): düzyazı metinleri, 1 veya 3 anlık serbest hatırlama testi vs yeniden çalışma; son test 5 dk/2 gün/1 hafta sonra; 5 dk'da yeniden çalışma önde, gecikmeli testlerde testle öğrenilen madde belirgin önde. [B] https://www.psychologicalscience.org/observer/test-enhanced-learning (arama özeti; birincil PDF'ler: https://www.gwern.net/docs/spaced-repetition/2006-roediger.pdf). Çıkarım [GÇ]: trivia yanıtlamak = geri çağırma pratiği; yalnızca bu uygulama bağlamında kanıt doğrudan değil.
- **Aralıklı tekrar (spacing):** Cepeda vd. 2006 (Psychological Bulletin 132(3):354-380): 839 değerlendirme, 317 deney, 184 makale; optimal aralık, hatırlama aralığı uzadıkça uzuyor. [B] https://pubmed.ncbi.nlm.nih.gov/16719566/
- **Hypercorrection:** yüksek güvenle verilen yanlışlar geri bildirimle daha çok düzeliyor; bir hafta sonra bile düzelmiş kalıyor (Fazio tezi özeti). Kang 2009 (merak ve trivia) doğrulanamadı. [B/İ] https://pmc.ncbi.nlm.nih.gov/articles/PMC4036076 ; https://dukespace.lib.duke.edu/items/d6ab09ca-f55c-4efb-9d32-2788bc5838b2
- **SM-2** (Wozniak, super-memory.com): başlangıç EF 2,5; ilk iki aralık 1 ve 6 gün; sonra önceki aralık × EF; kalite 0-5; EF alt sınırı 1,3; kalite <3 ise sıfırdan; yazar ilk yılda ~%92 tutma bildiriyor (yazarın kendi iddiası). [B-yazar] https://super-memory.com/english/ol/sm2.htm
- **FSRS:** MaiMemo'nun DHP modelinden türeyen DSR modeli (Difficulty, Stability, Retrievability); kullanıcı belleğine uyum sağlar; gecikmiş/erken tekrara izin verir. Wiki sayfasında SM-2 ile sayısal karşılaştırma ve "istenen retention" ayrıntısı yoktu. [B-topluluk wiki] https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler/wiki/ABC-of-FSRS
- **Leitner kutuları:** bu çalışmada birincil kaynak bulunamadı → doğrulanamadı (klasik tanım: doğru → sonraki kutu, yanlış → ilk kutu [GÇ]).
- **Birdbrain** (bkz. §3): oyuncu seviyesine göre uygun zorlukta egzersiz seçimi; bu fikrin trivia'ya aktarımı [GÇ].

### 5.2 Tasarım önerisi [GÇ]
- **Oyuncu beceri profili:** `categorySkill[cat]` (Elo θ veya yumuşatılmış doğru oranı) + `n`. Kategori başına seviye (ustalık) = θ'nın dilimlere bölünmesi.
- **Soru seçimi (basit):** hedef p≈0,70-0,85'e yakın zorluktan, oyuncunun yakın zamanda görmediği soru; maçın başında "bildiğin" kategoriden 1-2 kolay soru (güven), ortada hedef bandı, ayrı bir "zayıf konu" oyun modunda en düşük θ kategorisi.
- **Mevcut kısmi aralıklı tekrar ile bağlama:** yanlış cevaplanan soruları SQLite'a `due` tarihiyle yaz; SM-2'nin basit sürümü (1 gün → 6 gün → ×EF) yeterli (efor S). FSRS parametre eğitimi gerektirir; küçük projede gereksiz. Tekrar edilen soruyu "farklı açıdan" yeniden üretmek (aynı olgu, farklı soru kalıbı) ezberi değil olguyu pekiştirir; çeviri havuzunda aynı olgunun `factId`'sini saklamak gerekir.
- **Tekrar önleme penceresi:** mevcut "son 14 gün" dışarı bırakmayı, yanlış cevaplanan sorular için bilerek aralıklı yeniden sunumla çatışmayacak şekilde ayırın (ayrı kuyruk) [GÇ].
- **Etik/dark pattern:** önceki raporda tartışıldı; bu bölüm yalnızca içerik seçimini kapsar.

---

## 6) Çok dillilik, kültürel uygunluk, politika, erişilebilirlik

### 6.1 Çevirmek mi, yerel üretmek mi?
- Global-MMLU (arXiv:2412.03304): MMLU çevirisinde sorunun %28'i kültüre özgü bilgi gerektiriyor; coğrafya sorularının %84,9'u Kuzey Amerika/Avrupa; yalnızca çeviri yeterli değil; kültürel duyarlı alt kümede model sıralamaları değişiyor; 42 dil; ücretli profesyonel ve topluluk anotatörleriyle çeviri doğrulaması. [B] https://arxiv.org/abs/2412.03304
- BLEnD (arXiv:2406.09948, NeurIPS 2024 D&B): 16 ülke/bölge, 13 dil, 52,6 bin QA çifti; modeller yaygın kültürlerde daha iyi; düşük kaynaklı dillerde yerel dil yerine İngilizcede daha iyi; en büyük fark en iyi model GPT-4'te kısa cevapta %57,34. [B] https://arxiv.org/abs/2406.09948
- **Çıkarım [GÇ]:** (a) evrensel olgular (bilim, coğrafya, matematik) için "bir kez üret + çevir + dile özgü kontrol"; (b) kültüre bağlı kategoriler (yerel tarih, edebiyat, mutfak, spor, popüler kültür) için o dilin ülkesine göre YEREL üretim veya soruya `culturalScope: global|regional|local` etiketi ve yalnızca ilgili dillerde gösterme; (c) 26 dilin çoğunda LLM'in yerel bilgisi zayıf olabilir (düşük kaynaklı dillerde yerel dil yerine İngilizce daha iyi, BLEnD); bu yüzden çeviriyi İngilizce kaynaktan yapıp çeviri hata bildirimi ayrı sayılsın.
- Çeviri kalitesi: dil başına örneklem (ör. 50 soru) insan/ikinci-model geri çeviri (back-translation) kontrolü; arka-çeviri yönteminin etkinliğine dair bu çalışmada kaynak bulunamadı [GÇ].

### 6.2 Hassas içerik politikası
- Play: nefret söylemi, gereksiz şiddet, hassas olaylar (salgın, çatışma, ölüm) yasak/sınırlı; eğitsel bağlam genelde izinli. [B] https://support.google.com/googleplay/android-developer/answer/9878810
- Gemini güvenlik filtresi eşikleri (bkz. §2.3) üretim hattında açık ayarlanmalı. [B] https://ai.google.dev/gemini-api/docs/safety-settings
- Öneri [GÇ]: dini/siyasi konuları olgusal-tarihsel biçimde tutan, "kimin haklı" yargısı gerektirmeyen bir yönerge; sınır bölgesi/ülke adı, tartışmalı toprak, mezhep karşılaştırması, yaşayan siyasetçi eleştirisi gibi alt konuları kara listeye alın veya `sensitive` etiketi ile varsayılan kapalı tutun; konu başına "angle" üretimine kara liste istemi ekleyin.
- IARC: anket yeni uygulama ve içeriği etkileyen güncellemelerde yeniden doldurulmalı; yanlış beyan kaldırma/askıya alma riski taşır; sonuçlar kurumlara (ESRB, PEGI, USK vb.) göre bölgesel değişebilir. UGC sorusunun ayrıntısı çekilen sayfada yoktu → anketin kendisi okunmalı. [B] https://support.google.com/googleplay/android-developer/answer/9859655

### 6.3 Erişilebilirlik
- WCAG 2.2: 1.4.3 Kontrast (Asgari) AA metin 4,5:1, büyük metin 3:1; 1.4.4 metin %200'e kadar yardımcı teknoloji olmadan büyütülebilmeli ve içerik/işlev kaybolmamalı; 1.4.1 renk tek başına bilgi taşımamalı (doğru/yanlış şık için renk + ikon/metin). [B] https://www.w3.org/TR/WCAG22/ . 2.5.8 hedef boyutu (24×24 CSS px) çekilen kısımda doğrulanamadı.
- Android: Compose'da `contentDescription`, TalkBack etiket yönergeleri (dekoratif için `null`), koleksiyon öğeleri benzersiz etiket; sayfada 48dp/kontrast/sp değerleri yoktu → doğrulanamadı. [B] https://developer.android.com/guide/topics/ui/accessibility/principles
- Flutter'a özgü kaynak (Semantics, textScaler) bu çalışmada çekilmedi.
- Oyun-özel öneri [GÇ]: zamanlayıcıda süre uzatma/kapatma seçeneği, doğru/yanlış için renk dışı gösterge, çok uzun soru metinlerinde kaydırma + %200 yazı ölçeğinde taşma testi (LLM'in "çok uzun soru" sorunu burada da erişilebilirlik sorunu).

---

## 7) Uygulanabilirlik tablosu

Maliyet tahminleri [GÇ] varsayımla: 10.000 soru, soru başı ~600 giriş + ~300 çıkış token'ı, Gemini 3.5 Flash-Lite (0,30 $/2,50 $ per 1M) → giriş 6M tok ≈ 1,8 $; çıkış 3M tok ≈ 7,5 $; toplam ≈ 9,3 $ standart, ≈ 4,7 $ Batch ile (fiyatlar çekilen sayfadan; token varsayımı tahmin; düşünme token'ları çıkışa dahil olduğundan gerçek maliyet daha yüksek olabilir).

| # | Öneri | Efor | Risk | Maliyet | Beklenen etki |
|---|---|---|---|---|---|
| 1 | Sıkı şema + kural doğrulama (şık sayısı, tekrar, uzunluk limiti, cevap indeksi, dil kodu) | S | Düşük (yanlış red = üretim kaybı) | ~0 (yerel) | Uzun/bozuk soru sorununu büyük ölçüde keser; doğruluğu garanti etmez |
| 2 | Soru başı sayaç (`shown/correct`) + şans düzeltmeli otomatik zorluk yeniden etiketleme, `N_min` eşiği | M | Düşük-orta (eşik kalibrasyonu; seviye-koşullu önyargı) | Firestore yazma: ücretsiz kota 20.000 yazma/gün; toplu yazımla düşük | Zorluk uyumsuzluğuna doğrudan çözüm; küçük veriyle uygulanabilir |
| 3 | Bildirim eşiği + Wilson alt sınırı ile otomatik gizleme + inceleme kuyruğu | M | Orta (kötüye kullanma; yanlış gizleme) | Düşük (aynı sayaç altyapısı) | Hatalı soruları hızlı eler; Play UGC politikasıyla uyum |
| 4 | Üretim-sonrası "cevap anahtarı doğrulayıcı" ikinci geçiş (Batch, ucuz model) | M | Orta (ortak hata; yanlış red) | ≈ 5-10 $/10k soru (varsayım) | Halüsinasyon/belirsiz soru azalır; ölçülmüş sayı yok (trivia için kanıt yok) |
| 5 | Grounding ile doğrulama (yalnızca bayraklanmış/tartışmalı sorular) | M | Orta (gösterim koşulları belirsiz; maliyet sorgu başına) | 5.000 sorgu/ay ücretsiz (Gemini 3+), sonra 14 $/1.000 sorgu | Yüksek doğruluk; küçük hacimde bedava kapsanır |
| 6 | Wikidata tabanlı olgusal kategoriler (CC0) + LLM yalnızca ifade/çeviri | L | Orta (SPARQL limit/politika doğrulanmadı; soru çeşitliliği düşük) | Sıfır lisans; mühendislik emeği | Seçili kategorilerde çok düşük hata; yeni içerik kaynağı |
| 7 | Çeviri dışı yerel içerik / `culturalScope` etiketi | M | Orta (üretim karmaşıklığı) | Token maliyeti artışı | Çok dilli kalite; kültürel yanlılık azalır |
| 8 | Elo (oyuncu+soru) zorluk ve beceri modeli | M-L | Orta (parametre ayarı, soğuk başlangıç) | Düşük | Dinamik zorluk, kişiselleştirme temeli |
| 9 | Basit SM-2 benzeri tekrar kuyruğu (SQLite `due`) | S-M | Düşük | ~0 | Retention; test etkisi/spacing literatürüyle uyumlu |
| 10 | Kategori ustalık seviyesi + "zayıf konu" modu | M | Düşük | ~0 | Bağlılık ve öğrenme hissi |
| 11 | Topluluk oylaması (doğru/net mi?) | S | Düşük-orta (manipülasyon) | Düşük | Ek kalite sinyali, bildirimden daha çok veri |
| 12 | Hassas konu kara listesi + güvenlik eşiği ayarı + IARC beyan kontrolü | S | Düşük | ~0 | Play politika riskini azaltır |
| 13 | Erişilebilirlik denetimi (kontrast, renk dışı gösterge, %200 yazı) | S-M | Düşük | ~0 | Kapsayıcılık; uzun soru taşma hatalarını yakalar |

---

## 8) Önerilen uygulama sırası

1. **Hafta 1 (S):** #1 doğrulama kuralları + #12 hassas konu ve güvenlik eşikleri.
2. **Hafta 1-2 (M):** #2 sayaçlar (cihazda biriktir, oyun sonunda toplu yaz) — tüm sonraki işlerin veri temeli.
3. **Hafta 2-3 (M):** #3 eşik tabanlı gizleme + inceleme kuyruğu; #11 oylama.
4. **Hafta 3-4 (M):** #4 Batch ikinci geçiş doğrulama (mevcut havuza geriye dönük çalıştır: önce en çok gösterilen sorular).
5. **Sonra:** #5 grounding yalnızca bayraklı sorularda (ücretsiz kotada); #9 tekrar kuyruğu; #13 erişilebilirlik.
6. **Orta vadeli:** #8 Elo, #10 kategori ustalığı, #7 yerel içerik, #6 Wikidata hattı.

---

## 9) Doğrulanamayanlar / boşluklar

- LLM üretimli genel kültür trivia'sında gerçek hata oranını ölçen birincil çalışma bulunamadı; yukarıdaki doğrulama makaleleri biyografi/matematik/akıl yürütme görevleri.
- Grounding with Google Search'ün zorunlu gösterim koşulları (Hizmet Koşulları bölümü) okunmadı.
- Gemini sıcaklık önerisinin birincil sayfası doğrudan açılmadı; arama sonucu özetine dayanıyor.
- Duolingo İngilizce Testi'nin IRT kullandığı doğrulanamadı; Birdbrain blogu Elo/IRT'den söz etmiyor.
- Pelánek makalesinin tam metni okunmadı (yalnızca özet/arama sonucu); Elo formülü ve K-değeri önerileri bu rapordaki [GÇ] çerçevedir.
- Leitner sistemi için birincil kaynak bulunamadı. FSRS wiki'sinde SM-2 karşılaştırma sayısı yoktu.
- Csikszentmihalyi'nin birincil metni ve Kang 2009 okunmadı/bulunamadı. %85 kuralının insan trivia'sında geçerliliği kanıtlanmadı.
- Wikipedia'nın CC BY-SA lisansı Wikipedia'nın kendi sayfasından teyit edilmedi; Wikidata Query Service limitleri/User-Agent politikası okunmadı.
- Firestore: birim fiyatlar ve "tek doküman ~1 yazma/sn" kuralı resmi sayfada teyit edilemedi.
- WCAG 2.5.8 (24×24), Android 48dp/kontrast/sp değerleri okunan sayfalarda yoktu. Flutter erişilebilirlik dokümanı çekilmedi.
- Play politikalarında "LLM üretimli içeriğin UGC sayılması" ve IARC anketinin UGC sorusu doğrulanamadı.
- Çeviri kalite denetimi (geri çeviri) için akademik kaynak bulunamadı.
- Gemini model adları (3.8 Flash, 3.5 Flash-Lite vb.) fiyat/grounding sayfalarından olduğu gibi aktarıldı; projenin mevcut model kimliği bu raporda kontrol edilmedi.

---

## 10) Kaynak listesi

Gemini / Google / Firebase
1. https://ai.google.dev/gemini-api/docs/google-search
2. https://ai.google.dev/gemini-api/docs/pricing
3. https://ai.google.dev/gemini-api/docs/structured-output
4. https://ai.google.dev/gemini-api/docs/safety-settings
5. https://ai.google.dev/gemini-api/docs/batch-api
6. https://ai.google.dev/gemini-api/docs/gemini-3 (arama sonucu üzerinden)
7. https://firebase.google.com/docs/firestore/solutions/counters
8. https://firebase.google.com/docs/firestore/pricing
9. https://firebase.google.com/docs/firestore/quotas
10. https://support.google.com/googleplay/android-developer/answer/9876937 (UGC)
11. https://support.google.com/googleplay/android-developer/answer/9878810 (uygunsuz içerik)
12. https://support.google.com/googleplay/android-developer/answer/9859655 (içerik derecelendirme/IARC)
13. https://developer.android.com/guide/topics/ui/accessibility/principles
14. https://www.w3.org/TR/WCAG22/

Lisans / veri
15. https://www.wikidata.org/wiki/Wikidata:Licensing
16. https://opentdb.com/api_config.php
17. https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service/queries (limit bilgisi bulunamadı)

Akademik (LLM kalitesi/doğruluk)
18. https://arxiv.org/abs/2203.11171 (self-consistency)
19. https://arxiv.org/abs/2303.08896 (SelfCheckGPT)
20. https://arxiv.org/abs/2309.11495 (CoVe)
21. https://arxiv.org/abs/2305.14251 (FActScore)
22. https://arxiv.org/abs/2311.05232 (halüsinasyon anketi)
23. https://arxiv.org/abs/2307.16338v1 (Bitew vd., çeldirici)
24. https://par.nsf.gov/biblio/10613695-generating-effective-distractors-introductory-programming-challenges-llms-vs-humans [İ]
25. https://arxiv.org/pdf/2412.11831 (belirsizlik ile zorluk tahmini) [İ]
26. https://arxiv.org/abs/2601.09953v1 (simüle öğrenci) [İ]
27. https://aclanthology.org/2024.bea-1.41 (BEA 2024) [İ]

Zorluk kalibrasyonu
28. https://www.fi.muni.cz/~xpelanek/publications/CAE-elo.pdf ; https://is.muni.cz/publication/1376317 (Pelánek 2016)
29. https://www.fi.muni.cz/~xpelanek/publications/EDM14-adaptive-facts.pdf (Papoušek vd. 2014)
30. https://www.ics.muni.cz/en/research/publications/1359654 (Pelánek vd. 2017)
31. https://blog.duolingo.com/learning-how-to-help-you-learn-introducing-birdbrain/
32. https://aclanthology.org/2020.tacl-1.17 (Duolingo English Test, Settles vd.)
33. https://rasch.org/rmt/rmt161o.htm ; https://www.fisica.net/enem/The-Basics-of-Item-Response-Theory.pdf (Baker, IRT)
34. https://www.evanmiller.org/how-not-to-sort-by-average-rating.html [İ]

Öğrenme bilimi / kişiselleştirme
35. https://pmc.ncbi.nlm.nih.gov/articles/PMC6831579 (Wilson vd. 2019) ; https://neurosciencenews.com/learning-optimized-15171/ [İ]
36. https://pubmed.ncbi.nlm.nih.gov/16719566/ (Cepeda vd. 2006)
37. https://www.gwern.net/docs/spaced-repetition/2006-roediger.pdf ; https://www.psychologicalscience.org/observer/test-enhanced-learning (Roediger & Karpicke 2006)
38. https://pmc.ncbi.nlm.nih.gov/articles/PMC4036076 (hypercorrection)
39. https://super-memory.com/english/ol/sm2.htm (SM-2)
40. https://github.com/open-spaced-repetition/free-spaced-repetition-scheduler/wiki/ABC-of-FSRS (FSRS)
41. https://cacmb4.acm.org/magazines/2007/4/5692-flow-in-games-and-everything-else/fulltext (Chen 2007) [İ]
42. https://ntnu.no/wiki/download/attachments/197920535/GameFlow.pdf?api=v2 (Sweetser & Wyeth)

Çok dillilik
43. https://arxiv.org/abs/2412.03304 (Global-MMLU)
44. https://arxiv.org/abs/2406.09948 (BLEnD)
