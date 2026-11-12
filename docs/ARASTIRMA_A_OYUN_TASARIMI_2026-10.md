# Araştırma A: Oyun Tasarımı ve Bağlılık Mekanikleri (Trivia için) — 2026-10

Tarih: 2026-10-20. Yalnızca araştırma; kod değiştirilmedi. Önceki dosya (`ARASTIRMA_RETENTION_VE_ARKA_PLAN_2026-10.md`) tekrar edilmedi; Duolingo streak/lig bulguları orada özetlenmişti, burada yalnız yeni eklenenler ve yorum var.

Etiketler: **[B]** birincil kaynak (şirketin kendi blogu/yatırımcı belgesi/hakemli makale/ön baskı/resmi sayfa), **[İ]** ikincil (haber, analiz, wiki, blog), **[GÇ]** geliştirici çıkarımı/öneri (kaynak yok, benim yorumum). "Birincil" şirket kaynağı olsa da KENDİ BEYANIDIR: yöntem/örneklem/anlamlılık çoğunlukla verilmemiştir; bunu her sayıda "ölçüt" ile belirttim.

Araştırma notu: Birçok PDF (Ryan&Deci 2000, Zagal 2013 tam metin) araçla metin olarak okunamadı; o makaleler için yalnızca özet/arama sonucu kullanıldı ve etiketlendi.

---

## 1) Özet (15 madde)

1. **Duolingo'nun yayımladığı en güçlü ölçülmüş sonuç "kilidi azaltma" yönünde:** streak'i günlük hedeften ayırıp "günde 1 ders yeter" yapmak (A/B, göreli değişim): 14. gün geri dönüş +%3,3, günlük aktif öğrenici +%1, streak'li günlük öğrenici +%10,5; kullanıcının günlük hedefi "yoğun" seçmesinin alışkanlık için engel olduğu sonucuna varılmış. [B] https://blog.duolingo.com/improving-the-streak
2. Streak kilometre taşı animasyonu: yeni kullanıcıda 7. gün hâlâ aktif olma olasılığı +%1,7; en fazla 2 freeze: günlük aktif öğrenici +%0,38 (göreli; örneklem/anlamlılık verilmemiş). 7 günlük streak–kurs tamamlama 3,6x = korelasyon. [B] https://blog.duolingo.com/how-duolingo-streak-builds-habit/
3. **Bildirim optimizasyonu mütevazı kazanç verdi:** Duolingo'nun "recovering bandit" algoritması hatırlatma bildirimlerinde toplam DAU +%0,5, yeni kullanıcı tutmada +%2 (güçlü bir temel çizgiye göre; özet). Yani bildirim "sihirli değnek" değil. [B] https://paperswithcode.com/paper/a-sleeping-recovering-bandit-algorithm-for (özet aynası); makale: https://research.Duolingo.com/papers/yancey.kdd20.pdf
4. **Friend Streak:** en az bir friend streak'i olanların günlük dersi tamamlama olasılığı %22 daha yüksek (korelasyon; metrik tanımı yok); üst sınır 5, "ilk daveti göndermek" en büyük hunisi. Birincil kaynakta kullanıcıların %57'sinin en az bir arkadaşı olduğu yazıyor. [B] https://blog.duolingo.com/product-lessons-friend-streak/
5. **Yatırımcı belgesi:** S-1'de DAU/MAU 2019 ≈%19, 2020 ≈%22 (benim hesabım: DAU 5,2M/8,2M; MAU 27,3M/36,7M); "yılda binlerce/yüzlerce A/B testi" (belge kendi içinde tutarsız: "thousands", "hundreds per quarter", "more than 500 per quarter"). [B] https://www.sec.gov/Archives/edgar/data/1562088/000162828021013065/duolingos-1.htm
6. **Wordle:** günde tek bulmaca = "atılım" (Wardle); bildirim yok, reklamsız, ~3 dk; paylaşım düğmesi (spoiler'sız emoji ızgarası) kullanıcıların elle yaptığı davranışı otomatikleştirmiş. [İ] https://www.boston.com/news/national-news/2022/01/04/he-made-wordle-for-his-partner-now-its-an-online-hit/ (NYT röportajını aktaran haber; NYT'nin kendi sayfası okunamadı)
7. **HQ Trivia çöküşü** tek nedenli değil: yenilik sönmesi, hile (ödül bölüşümü), taklitçiler, teknik sorunlar, yeni oyun türü/viral özelliklerin geç gelmesi, kurucu ölümü, yönetim çatışması, satışın düşmesi; Temmuz 2019'da indirmeler önceki yılın %8'i. [İ] https://techcrunch.com/2020/02/14/hq-trivia-shuts-down (Sensor Tower verisini aktarıyor)
8. **QuizUp/Trivia Crack dersi:** QuizUp asenkron 1v1 ile "kısa/uygun zamanda" trivia'yı yaygınlaştırdı ama sonunda gelirleştirilemedi ve bakım moduna alındı; Trivia Crack uzun ömrünü kullanıcı üretimi soru (Questions Factory) ve geniş yerelleştirmeyle anlatıyor. İkisi de [İ]: https://fortune.com/2013/12/11/how-an-icelanders-viking-journey-helped-create-a-trivia-sensation ; https://techcrunch.com/2020/06/17/quizup-founder-gets-back-to-trivia-roots-with-the-launch-of-trivia-royale ; https://www.pocketgamer.biz/interview/77477/user-generated-content-key-trivia-crack/
9. **SDT (akademik):** oyun çekiciliği ve iyi oluş etkisi özerklik/yeterlilik/ilişkililik ihtiyaçlarının doyumuna dayandırılıyor; Sailer ve ark. (2017, randomize deney) rozet/liderlik tablosu/performans grafiği → yeterlilik; avatar/hikaye/takım arkadaşı → ilişkililik; özerklik manipülasyonu işe yaramadı. [B] https://repository.essex.ac.uk/7228/ ; https://epub.ub.uni-muenchen.de/53202
10. **Dışsal ödül riski:** Deci, Koestner, Ryan (1999) meta-analizi (128 çalışma): katılım/tamamlama/performansa bağlı somut ödüller serbest seçimde içsel motivasyonu azaltıyor (d=-0,28…-0,40); alan tartışmalı (karşı görüş: Cameron ve ark.). Bu çalışmalar çoğunlukla laboratuvar/eğitim bağlamında; oyun jeton ekonomisine doğrudan aktarılamaz [GÇ]. [B] https://leeds-faculty.colorado.edu/dahe7472/deci%201999.pdf
11. **Gamification genel kanıtı "bağlama bağlı":** Hamari ve ark. (HICSS 2014) incelemesi: etkiler olumlu ama bağlam, kullanıcı özellikleri ve yenilik etkisine (novelty) çok bağlı. [B] https://research.aalto.fi/fi/publications/does-gamification-work-a-literature-review-of-empirical-studies-o/
12. **Loss aversion kanıtı:** 607 tahminli meta-analiz ortalama katsayıyı ~1,8–2,1 buluyor (1992 tahmini 2,25'ten düşük ama benzer); başka bir meta-analiz risk seçimi verisinin kalitesini zayıf buluyor. Yani "kayıp acısı kazanç hazzının 2 katı" kesin yasa değil. [B/özet] https://dlab.sauder.ubc.ca/sjdm/journal/22/220414/jdm220414.html ; https://wrap.warwick.ac.uk/185745
13. **Temporal dark pattern (Zagal, Björk, Lewis 2013):** "playing by appointment" gibi oyuncunun programını oyunun belirlemesi örnek; yazarların amacı suçlamak değil değer tartışması açmak. [B-özet] https://research.chalmers.se/en/publication/177148
14. **Uzun vadeli tükenme riski için en iyi (ölçülmemiş ama mantıklı) yaklaşım:** ödül zorunluluğu değil seçenek, af/freeze, kapatılabilir sosyal özellikler, "doğal bitiş" (Wordle). Bu bir tasarım çıkarımıdır [GÇ]; Duolingo'nun "alışkanlık için engeli düşür" bulgusu (madde 1) ile uyumlu.
15. **Doğrulanamayan çok şey var:** Supercell sandık deneyi sonucu yayımlanmamış; King can sistemi, Pokémon GO etkinlik ritmi ve Fortnite/Genshin pass mantığı için birincil veri bulunamadı (bkz. §6).

---

## 2) Vaka incelemeleri

### 2.1 Duolingo
| Mekanik | Ne yapıyor (kaynaklı) | Etiket |
|---|---|---|
| Streak | Yeni kullanıcıda küçük artışlar büyük hissettirir (2→3 gün = %50, 200→201 = %0,5); büyüdükçe kayıp korkusu ana motivasyon (blog beyanı, sayı yok). Milestone animasyonu: 7. gün aktiflik +%1,7 (yeni kullanıcı, göreli, ölçüt: "7 gün sonra hâlâ kullanıyor"). https://blog.duolingo.com/how-duolingo-streak-builds-habit/ | B |
| Streak + günlük hedef ayrımı | Önceden streak için günlük hedefe ulaşmak gerekiyordu; "günde 1 ders" yapıldı. 14. gün geri dönüş +%3,3, DAU +%1, streak'li günlük öğrenici +%10,5 (20 gün içinde), yeni kullanıcıda +%19; ödün: günlük hedefe ulaşan azaldı. Bir yıl sonra 7+ gün streak'li günlük öğrenici payı ~1/3'ten "yarıdan biraz fazla"ya. https://blog.duolingo.com/improving-the-streak (19 Kasım 2020) | B |
| Freeze | En fazla 2 equip: günlük aktif öğrenici +%0,38 (göreli), "daha fazla izin günü" doğurmadığı beyanı. Gerekçe olarak UPenn/UCLA "slack" çalışması anılıyor (rakam yok). https://blog.duolingo.com/how-duolingo-streak-builds-habit/ | B |
| Friend Streak | En çok 5 slot (veri bilimi analizi, büyük aktif arkadaş grubu küçük kitle); 6 adımlı huni (uygunluk → davet → ortak streak → daha çok davet → 5 streak → freeze'siz sürdürme); doğrudan etkileşim gerektirmez. https://blog.duolingo.com/product-lessons-friend-streak/ (geliştirme Ocak 2024'te başlamış) | B |
| Ligler | 10 lig, haftalık (pazar), benzer alışkanlık ve saat dilimi grubu, XP sahtekârlığına karşı denetim, profil gizleyerek çıkış, sayısal etki yok. https://blog.duolingo.com/duolingo-leagues-leaderboards/ . S-1: "Leaderboards ortalama öğrenme süresini ~%20 artırdı" iddiası ikincil bir özetten geldi; S-1'in okunan 100.000 karakterinde bulunamadı → **doğrulanamadı**. | B |
| Enerji (ücretsiz kullanıcı) | Q2 2025 mektubu: her egzersiz 1 enerji harcar (doğru/yanlış fark etmez), art arda doğrularla geri gelir, "sopa değil havuç"; iOS'ta DAU, medyan öğrenme süresi ve abone dönüşümünü artırdığı söylenmiş, sayı yok. DAU Q2'25 47,7M (+%40 y/y; ölçüt: takvim günü başına benzersiz kullanıcı, dönem ortalaması). https://www.sec.gov/Archives/edgar/data/1562088/000156208825000165/q2fy25duolingo6-30x25share.htm | B |
| Bildirimler | KDD 2020: 35 günde 200M hatırlatma örneği; "recovering bandit" ile DAU +%0,5, yeni kullanıcı tutma +%2 (özet; temel çizgi). Veri seti: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/23ZWVI . "Duolingo bildirim stratejisi" blog URL'si 404 verdi. | B |
| Kişiselleştirme (Birdbrain) | Her egzersizin doğru yapılma olasılığını tahmin eden model; Session Generator ders için uygun zorlukta egzersiz seçer. Ekim 2020 itibarıyla derslerin >%20'si Birdbrain ile (Mart 2020'de %0). Daha çok ders tamamlama/geri dönüş "A/B testlerinde tutarlı", sayı yok. https://blog.duolingo.com/learning-how-to-help-you-learn-introducing-birdbrain | B |
| Deney kültürü | S-1: "binlerce A/B testi" / "çeyrekte 500+" (tutarsız ifade). https://www.sec.gov/Archives/edgar/data/1562088/000162828021013065/duolingos-1.htm . "600+ streak deneyi" iddiası ikincil bir podcast özetinde: https://www.recall.it/summary/lennys-podcast/behind-the-product-duolingo-streaks-or-jackson-shuttleworth-group-pm-retention-team | B / İ |

Çıkarım [GÇ]: Duolingo kazanımları küçük yüzdelerin birikimi (+%0,38, +%0,5, +%1…). Büyük bir trivia oyununun da tek büyük mekanikten değil, ölçülü çoklu deneyden kazanması beklenmeli. Duolingo'nun en büyük etkisi "alışkanlık için engeli düşürmek" olmuş; trivia'daki karşılığı "streak için tek kısa tur yeter".

### 2.2 Wordle / NYT Games
- Günlük tek bulmaca "breakthrough/scarcity"; "günde ~3 dk"; bildirim yok; reklam yok; paylaşım düğmesi 16 Aralık 2021'de (kullanıcıların elle yaptığı emoji ızgarasından). Wardle paylaşım metnine oyun linki koymamayı bilinçli seçmiş. [İ] https://www.boston.com/news/national-news/2022/01/04/he-made-wordle-for-his-partner-now-its-an-online-hit/ ; ikinci özet: https://en.wikipedia.org/wiki/Wordle
- NYT'nin streak verisi: 2023 GDC konuşmasından aktarılan "PARER" kelimesi yılın en çok streak bozan cevabı, ortalama günlük bozulan streak'i 4 kat artırmış. [İ] https://www.axios.com/2023/03/23/new-york-times-wordle-game-developers-conference (sayfa 403 verdi; yalnızca arama özeti, doğrudan okunmadı). Bu, "zor bir günün streak'i toplu bozduğunu" gösteriyor [GÇ: zorluk dalgalanması streak ölçümünü bozar].
- Wordle 300 bin → >2 milyon günlük oyuncu iddiası bir iş okulu blogunda [İ] https://www.ivey.uwo.ca/hba/blog/2025/03/the-daily-puzzle-phenomenon-how-nyt-turned-games-into-a-subscription-goldmine/ ; kaynak/ölçüt gösterilmemiş, düşük güven.
- Doğrulanamadı: NYT'nin kendi sayfalarından (nytco.com, 10-K) Games abone sayısı/streak etkisi.

### 2.3 Supercell / Clash Royale
- Zamanlayıcılı sandık slotu lansmandan beri var; **15 Ocak 2025 deneyi**: King Tower 1–9 için Gümüş/Ahşap anında, Crown sandığı 24 saat; toplam ödül değeri aynı; neden: yeni oyuncu beklentileri farklı olabilir. **Sonuç yayımlanmamış** (yalnızca geri bildirim isteniyor). [B] https://supercell.com/en/games/clashroyale/blog/news/chest-experiment-king-tower-levels-1-9
- Sandıklar ilerleme hızını yönetir; aynı anda 1 sandık açılır, en çok 4 tutulur; kazanma doğrudan para vermez, kart şansı verir. [İ] https://www.gamedeveloper.com/design/the-math-of-clash-royale
- Sezonlar: 2021 yaz güncellemesinde "yukarı çıktıkça sezon sonunda daha az sıfırlanma". [İ] https://www.dualshockers.com/clash-royale-summer-update-2021-patch-notes-new-goblin-drill-card/ (özet üzerinden)
- Doğrulanamadı: GDC Vault'ta Supercell'in sandık/ilerleme konuşması bu aramada bulunamadı.

### 2.4 King / Candy Crush
- Birincil kaynak (help.king.com / GDC "lives") bulunamadı. GDC oturumları: King Veri Bilimi Direktörü Xavier Guardiola'nın bölüm zorluğu/etkileşim modellemesi; "10 yılda 15.000+ seviye" istatistik oturumu; Candy Crush Soda iletişim/navigasyon yeniden tasarımı (Mart 2026). https://schedule.gdconf.com/session/sugary-statistics-what-we-have-learned-about-candy-crush-content-after-10-years-and-over-15000-levels/900207 ; https://schedule.gdconf.com/session/the-invisible-layer-redesigning-communication-and-navigation-in-candy-crush-soda-saga/915587 . Oturum içerikleri okunmadı; yalnızca başlık/özet [B-özet].
- Can sistemi ve etkinlik takvimi için birincil: **doğrulanamadı** (önceki dosyada fan wiki ikincil olarak vardı).

### 2.5 HQ Trivia, QuizUp, Trivia Crack, Kahoot
- **HQ Trivia** [İ, TechCrunch → Sensor Tower]: Eki 2017 lansman; Şubat 2018 zirve ~2M indirme/ay, 2,3M eşzamanlı oyuncu; Tem 2019 indirmeler önceki yılın %8'i, %20 işten çıkarma; Şubat 2020'de kapanış (alıcı son anda çekildi). Nedenler (yazarın değerlendirmesi): yenilik sönmesi, hile, taklitçiler, teknik hatalar, yeni oyun türlerinin geç gelmesi. https://techcrunch.com/2020/02/14/hq-trivia-shuts-down . Bloomberg da yönetim kargaşası ve yeni hit bulamamayı sayıyor. https://www.bloomberg.com/news/articles/2020-02-15/hq-trivia-is-shutting-down-after-brief-run-as-media-sensation (yalnızca arama özeti).
  Çıkarım [GÇ]: "Randevulu canlı oyun" modeli ölçeklenme/hile/saat bağımlılığı yükü getiriyor ve tek tür (tek oyun biçimi) yenilik sönmesine açık; bu projenin asenkron yapısı bu risklerin bir kısmından kaçınıyor.
- **QuizUp** [İ]: asenkron 2 kişilik, doğruluk+hız puanı; 8 farklı quiz uygulaması deneyip lansman; sonradan monetizasyon yapılamadı ve bakım moduna alındı. https://fortune.com/2013/12/11/how-an-icelanders-viking-journey-helped-create-a-trivia-sensation ; https://techcrunch.com/2020/06/17/quizup-founder-gets-back-to-trivia-roots-with-the-launch-of-trivia-royale (ikisi de arama özeti üzerinden).
- **Trivia Crack (Etermax)** [İ]: kullanıcı üretimi soru ve yerelleştirme (180+ ülke, 34'e kadar dil, 50M+ soru) uzun ömür gerekçesi (CPO beyanı; retention rakamı yok). https://www.pocketgamer.biz/interview/77477/user-generated-content-key-trivia-crack/
- **Kahoot** [B-akademik, küçük çalışmalar]: 277 ilkokul öğrencisi/6 hafta quasi-deneysel: somut+soyut ödül grubu daha çok kazanım (p<0,05); başka çalışmada canlı liderlik tablosu %24 öğrenci için stresli. Hepsi küçük, tek kurum. https://ijvlms.sums.ac.ir/article_51408.html ; https://files.cdha.ca/profession/journal/2841.pdf
- Kahoot/Trivia Crack/QuizUp'ın kendi retention verisi: **doğrulanamadı**.

### 2.6 Pokémon GO / Niantic
- Community Day 2018'de yerel parklarda buluşmaya çağrı olarak duyuruldu [İ] https://www.gameinformer.com/b/news/archive/2018/01/12/niantic-announces-pokemon-go-community-day.aspx ; 2022'de 6 saatten 3 saate indirildi; Niantic geliştiricileri "yalnızca birkaç yüzde oyuncu 3 saatten fazla katılıyor" demiş (aktarma) ve topluluk bunu engagement manevrası olarak eleştirmiş [İ] https://automaton-media.com/en/?p=10815 .
- Akademik: 199 kişilik açık anket (80 aktif/56 eski/62 hiç oynamayan) — devamlılık/bırakma motivasyonları; temsil gücü düşük. [B-akademik] https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5399220/
- Niantic'in birincil etkinlik ritmi verisi: **doğrulanamadı**.

### 2.7 Genshin / Fortnite (sezon/battle pass)
- Birincil (Epic/HoYoverse blog, GDC, hakemli) bulunamadı. İkincil: Fortnite pass'ın tüm ödülleri baştan görünür (loot box'ın tersi) ve pass'ın sonraki sezonu karşılayacak şekilde fiyatlanması [İ] https://experience.thinkvermont.com/exp/fortnites-battle-pass-evolution-how-a-single-game-shaped-live-service-gaming (güvenilirliği düşük bir sayfa); Genshin pass'ı geç eklenmiş (15–25 saat) [İ] https://www.pocketgamer.biz/an-analysis-of-genshin-impacts-mobile-success-and-how-it-could-grow-even-bigger ; Genshin D1 %41,2 / D30 %7,5 (AppMagic aktarımı, ölçüt belirtilmemiş, düşük güven) [İ] https://www.blog.udonis.co/mobile-marketing/mobile-games/genshin-impact-monetization .
- Çıkarım [GÇ]: pass'ın bağlılık gücü "görünür ilerleme çubuğu + sezon bitiş tarihi (gerçek)" kombinasyonundan geliyor; bitiş tarihi FOMO üretir → dikkat (bkz. §4).

---

## 3) Davranış bilimi çerçevesi

| Kavram | Kaynak | Ne diyor | Sınır/kanıt gücü |
|---|---|---|---|
| Self-Determination Theory (SDT) | Ryan & Deci 2000 [B-özet] https://selfdeterminationtheory.org/SDT/documents/2000_RyanDeci_SDT.pdf (PDF okunamadı; künye arama sonucundan) | Motivasyon özerklik, yeterlilik, ilişkililik ihtiyaçlarına dayanır | Genel kuram |
| SDT + video oyun | Przybylski, Rigby, Ryan 2010 [B] https://repository.essex.ac.uk/7228/ | Oyun çekiciliği/iyi oluş ihtiyaç doyumundan gelir; bozulmuş (kompulsif) oyun örüntüleri de ele alınır | Gözden geçirme |
| Hangi öğe hangi ihtiyaç | Sailer ve ark. 2017 [B] https://epub.ub.uni-muenchen.de/53202 | Rozet, liderlik, performans grafiği → yeterlilik; avatar, hikâye, takım → ilişkililik; özerklik manipülasyonu başarısız; bazı katılımcılar öğeleri fark etmedi | Çevrim içi simülasyon, yapay görev; gerçek oyuna aktarım sınırlı |
| Dışsal ödül paradoksu | Deci, Koestner, Ryan 1999 [B] https://leeds-faculty.colorado.edu/dahe7472/deci%201999.pdf | Katılım/tamamlama/performansa bağlı somut ödüller serbest seçim içsel motivasyonunu azaltır (d≈-0,28…-0,40); sözel övgü etkisi farklı | Tartışmalı alan (Cameron ve ark.); laboratuvar/eğitim |
| Gamification genel | Hamari ve ark. 2014 [B] https://research.aalto.fi/fi/publications/does-gamification-work-a-literature-review-of-empirical-studies-o/ ; tanım: Deterding ve ark. 2011 https://pure.itu.dk/en/publications/from-game-design-elements-to-gamefulness-defining-gamification/ | Etki bağlam/kullanıcı/yenilik etkisine bağlı | Eski derleme (yazarların sonraki işi "yıl geçtikçe eskiyor" diyor) |
| Loss aversion | Brown ve ark. meta-analizi [B] https://dlab.sauder.ubc.ca/sjdm/journal/22/220414/jdm220414.html ; Walasek ve ark. 2024 [B-özet] https://wrap.warwick.ac.uk/185745 ; 19 ülke replikasyonu (Nat Hum Behav 2024) [İ-haber] https://www.publichealth.columbia.edu/news/global-study-confirms-influential-theory-behind-loss-aversion | Kayıp ≈ kazançtan ~1,8–2,1 kat ağır (607 tahmin, 150 makale); ancak riskli seçimde veri kalitesi düşük | Para kararları; "streak kaybı" için doğrudan ölçüm değil [GÇ] |
| Temporal dark pattern | Zagal, Björk, Lewis 2013 [B-özet] https://research.chalmers.se/en/publication/177148 ; tam metin PDF https://gup.ub.gu.se/file/101018 (okunamadı) | 7 tür/3 kategori (temporal, parasal, sosyal sermaye); "playing by appointment" örneği | Kuramsal; tam metin okunamadı |
| Dark pattern'i "karanlık" yapan | Mathur, Mayer, Kshirsagar CHI 2021 [B] https://arxiv.org/abs/2101.04843 | Tek tanım yok; psikoloji/ekonomi/etik/hukuktan normatif perspektifler; öznel eleştiri yerine ampirik yöntem önerir | — |
| Değişken ödül | Kao 2012 Princeton yüksek lisans tezi [B-ama hakemsiz] https://www.cs.princeton.edu/techreports/2012/931.pdf ; Avustralya Senatosu raporu https://aph.gov.au/Parliamentary_Business/Committees/Senate/Environment_and_Communications/Gamingmicro-transactions/Report/c03 | Değişken oran takviyesi hızlı edinme/tekrar; tezde sıfır/çok küçük ödül aralığında tercih düşüyor | İnsan nedensel kanıtı popüler anlatıdan zayıf (araç özeti) |
| Hook Model | Nir Eyal [İ] (resmi site okunamadı; arama özetleri): https://concepts.dsebastien.net/concept/hook-model/ | Tetik → eylem → değişken ödül → yatırım; sonlu değişkenlikte etki azalır; Eyal'in etik soruları | Akademik değil, pratik çerçeve |
| Bildirim yükü | Pielot ve ark. [B-akademik]: "Dismissed!" 278 kullanıcı, 794.525 bildirim; mesajlaşma dışı bildirimlerde etkileşim ~%15–25 https://www.interruptions.net/literature/Pielot-MobileHCI18.pdf ; 2014 küçük saha çalışması: daha fazla bildirim, daha olumsuz duygu (15 kişi) https://ic.unicamp.br/~oliveira/doc/MHCI2014_An-in-situ-study-of-mobile-phone-notifications.pdf | Bildirim yoğunluğu ve duygu arasında ilişki (küçük örnek) | Oyun/trivia'ya özgü değil |

### Mekanik başına psikolojik ihtiyaç, tükenme ve etik sınır (özet)
Bu tablo [GÇ] — yukarıdaki kaynaklardan ve Duolingo bulgularından türetilen yorumdur, ölçülmüş değildir.

| Mekanik | İhtiyaç (SDT) | Uzun vadeli tükenme riski | Etik sınır |
|---|---|---|---|
| Streak | Yeterlilik (ilerleme görme), kısmen kayıp kaçınması | Seri uzadıkça kayıp korkusu = zorunluluk; seri kopunca toplu terk ("what-the-hell" etkisi, [GÇ]) | Kolay af (freeze, "onar"), ödülü seriye bağlama, kayıp için utandırma yok |
| Freeze/kurtarma | Özerklik (kontrol) | Para ile satış baskısı | Ücretsiz kazanılabilir; satın alma baskısı metni yok |
| Lig | Yeterlilik + sosyal kıyas | Alt liglerde moral bozulması, hile | Çıkış (opt-out), düşüşe ceza hafif, hile kontrolü |
| Günlük meydan okuma | Yeterlilik, ilişkililik (paylaşım) | Her gün aynı bulmaca → rutin sıkıcılığı | Gün kaçırınca kaybolan tek şey "bugünün" ödülü olsun |
| Sandık/zamanlayıcı | — (özerklikle çatışabilir) | Bekleme sıkıntısı, atlama için para | Zaman atlama satışı varsa şeffaf; çocuk kitlesinde dikkat |
| Değişken ödül | Merak/yeterlilik | Sonlu havuzda etkisi söner, kumar benzeri | Olasılıklar açık, ücretli rastgele ödül yok |
| Başarım/rozet | Yeterlilik | Yenilik etkisi sönümlenir | Kozmetik/bilgi ağırlıklı, zorunlu "hepsini topla" baskısı yok |
| Arkadaş meydan okuması | İlişkililik | Spam, tek taraflı baskı | Rehber taraması/otomatik davet yok |
| Sezon | Yeterlilik + yenilik | FOMO, sezon sonu bırakma | Gerçek bitiş tarihi, kaçırılan içerik sonra geri dönebilir |

---

## 4) Trivia'ya uyarlama tablosu

Efor: S (≤1 hafta), M (1–3 hafta), L (>1 ay) — [GÇ] tahmin. "Mevcut" sütunu projenin yalnızca görev metninde sayılan özelliklerine göredir (kod incelenmedi; gerçek kapsam doğrulanmadı).

| # | Öneri | Psikolojik dayanak | Etkilenecek metrik | Efor | Risk | Mevcut ile ilişki |
|---|---|---|---|---|---|---|
| 1 | **"Hafif streak":** seriyi bir kısa tur (örn. 3–5 soru) veya günün sorusu ile koru; günlük hedeften ayır | SDT yeterlilik; Duolingo ayrım deneyi (+%3,3 D14, bkz. §2.1; kendi beyanları) [B] | D1/D7/D14, streak'li DAU oranı | S–M | Günlük hedefe ulaşan oran düşebilir (Duolingo'da da düştü) | Seri/freeze var; koşulu gevşetmek mümkün |
| 2 | **"Bugünün sorusu" paylaşılabilir kart** (herkese aynı, spoiler'sız sonuç ızgarası) | Wordle: scarcity + paylaşım; ilişkililik [İ] | Organik yükleme, D1, paylaşım oranı | M | Soru kalitesi/yanlış soru; herkese aynı soru için sunucu üretimi | Günlük meydan okuma var |
| 3 | **Kategori ustalığı (uzmanlık seviyeleri)** — kategori başına seviye, "zayıf kategori" önerisi | Yeterlilik; Birdbrain mantığı (uygun zorluk) [B] | D7/D30, oturum/gün | M–L | Kategori başına yeterli soru şart; havuz tükenmesi | Başarımlar var; ustalık ilerlemesi yok olabilir [doğrulanmadı] |
| 4 | **Uygun zorluk eşleştirme** (doğruluk geçmişine göre zorluk) | Yeterlilik/flow; Duolingo Birdbrain beyanı (sayı yok) [B] | D7, tamamlama, hatalı bırakma | L | Soru zorluk etiketi gerektirir (zorluk verisi yoksa önce ölçüm) | Soru havuzu zorluğu doğrulanmadı |
| 5 | **Sezonluk lig** (haftalık veya 4 haftalık sezon, küçük gruplar, kolay yumuşak düşüş, çıkış seçeneği) | Yeterlilik + sosyal kıyas; Duolingo ligleri (etki sayısı yok) [B] | D7/D30, oturum/gün | M (var olan lig mantığı) | Küçük kullanıcı tabanında lig doldurma (bot şeffaflığı) | Haftalık lig var; sezon/ödül katmanı eklenebilir |
| 6 | **Haftalık temalı etkinlik** (örn. "Tarih haftası", gerçek bitiş tarihi) | Yenilik (novelty), merak | D7, geri dönüş oranı | M | İçerik üretim yükü; FOMO | Mevcut soru havuzu kategorileriyle yapılabilir |
| 7 | **Kozmetik koleksiyon** (avatar/çerçeve/rozet) kategori ustalığına bağlı | Yeterlilik + kimlik; ödül kozmetik olunca içsel motivasyon baskısı azalır [GÇ, Deci 1999 mantığı] | D30, jeton ekonomisi | M | Aşırı koleksiyon baskısı | Avatarlar/başarımlar var |
| 8 | **Arkadaş meydan okuması + ortak streak (Friend Streak benzeri)** | İlişkililik; Duolingo: %22 daha yüksek günlük tamamlama (korelasyon) [B] | D7/D30, viral katsayı | M | Davet spam'i; pasif arkadaş baskısı | Arkadaşlar + 1v1 var |
| 9 | **Takım/klan (küçük, 3–5 kişi) haftalık ortak hedef** | İlişkililik, ortak hedef (Sailer: takım arkadaşı → ilişkililik [B]) | D30, stickiness | L | Moderasyon, çocuklar için sohbet riski (sohbet yok tasarla) | Yeni özellik |
| 10 | **Ücretsiz sandık / günlük hedef yeniden çerçeveleme:** "geri kazan" değil "bugünkü hedef" | Özerklik; Duolingo Energy "doğruyu ödüllendir" [B] | Oturum/gün, reklam izleme isteği | S | Zaman atlama baskısı yoksa düşük | Sandık + günlük hedef var |
| 11 | **Kilometre taşı kutlaması** (3/7/14/30 gün animasyonu, kısa) | Yeterlilik; Duolingo +%1,7 (yeni kullanıcı 7. gün) [B] | D7 | S | Düşük | Kilometre taşı bonusları var; animasyon/mesaj katmanı eklenebilir |
| 12 | **Bildirim: 1 gün 1 mesaj, seçilmiş saat, gerçek içerik** (seri sona eriyor, düello daveti) | Hatırlatma; Duolingo bildirim optimizasyonu: DAU +%0,5 / yeni kul. tutma +%2 [B] | D1/D7, izin iptali, kaldırma | M | Fazla gönderim kaldırma artırır [Pielot: bildirim yükü olumsuz duygu, küçük örnek] | FCM/yerel bildirim önceki dosyada |
| 13 | **"Yanlış soru" bildirimi + düzeltme akışı** | Güven; HQ'da hile/adalet sorunu ders [İ] | Şikayet oranı, yorumlar | S–M | Moderasyon yükü | Gemini üretimli içerik riski [GÇ] |
| 14 | **Kullanıcı üretimi soru önerisi** (Trivia Crack'in Questions Factory'si gibi) | Özerklik, katkı | İçerik hacmi | L | Moderasyon, telif, kalite | Yeni |
| 15 | **Bir günlük "af"/geri dönüş kampanyası** (3+ gün gelmeyen: "seri yenileme" tek seferlik) | Kaybı yumuşatma | D7/D30, geri dönen oranı | S | Suiistimal, seri değerini düşürür | Kurtarma/freeze var |

Yaklaşım önerisi (hepsini birden değil) [GÇ]: Önce 1, 11, 10, 2 (S–M, düşük risk, Duolingo/Wordle'da ölçülmüş yön), sonra ölçüm yeterliyse 5/6/8, en sona 3/4/9.

---

## 5) Ölçüm

Kaynaklı olan: DAU ve MAU tanımları (günlük/aylık benzersiz kullanıcı), DAU/MAU oranı bu iki sayıdan türetilir (S-1'de DAU 2019 5,2M / MAU 27,3M → ~%19; ben hesapladım). [B] https://www.sec.gov/Archives/edgar/data/1562088/000162828021013065/duolingos-1.htm . Duolingo'nun kendi metrikleri: "7. gün hâlâ aktif", "14. gün retention", "günlük aktif öğrenici", "streak'li günlük öğrenici payı", "günlük dersi tamamlama" (tanımlar formal verilmemiş). [B] §2.1 blogları.

Önerilen metrik seti [GÇ]:
- **Birincil:** D1, D7, D30 geri dönüş (klasik: kurulum gününden N gün sonra oyuncu olan oran; "N. gün tam o gün" mü "N. gün ve sonrası" mı olduğunu başta sabitleyin). Firebase A/B Testing'te ~14 gün sonra lider belirlenebilir [B önceki dosya].
- **İkincil:** DAU/MAU (stickiness), oturum/gün, gün başı tamamlanan tur, streak uzunluğu dağılımı (histogram + 1, 3, 7, 14, 30 gün eşiklerinin payı), streak sonrası kopuş (streak kopunca ertesi hafta geri dönüş oranı), freeze kullanım oranı, sandık açma oranı, 1v1 başlatma oranı.
- **Streak dağılımı yorum notu:** Duolingo "7+ günlük streak'li günlük öğrenici payı"nı izliyor; NYT örneğinde zor bir cevap streak kopuşunu 4 kat artırdı → günlük içerik zorluğunu da kaydedin.
- **Guardrail:** bildirim izni iptali/kaldırma (uninstall) oranı, oturum başı süre (aşırı uzun = zorlama sinyali), şikayet/puan, "yanlış soru" bildirimi oranı, ödül suiistimali, jeton enflasyonu, reklam gösterimi başına D1 düşüşü, çocuk kullanıcı oranı (Families politikası). Duolingo da gerçek sonuçlarda ödünleri yazıyor (hedef tamamlayan azaldı) → her deneyde ödün metriğini de ölç.
- **Deney disiplini:** Duolingo sonuçları kendi blogunda göreli ve küçük (+%0,38…+%3,3); kendi küçük kitlenizde bu etkiler tespit edilemez. Kitleniz küçükse A/B yerine ardışık dönem karşılaştırması + nitel geri bildirim, tek seferde tek mekanik. [GÇ]
- Gürültü: kitle az olduğunda D7 yüzde puan dalgalanması büyük olur; kohort başına en az birkaç yüz kurulum gerekir [GÇ, kaynaksız].

---

## 6) Etik sınırlar

- Zagal ve ark. sınıflaması: temporal/parasal/sosyal sermaye; "playing by appointment" temporal örnek. [B-özet] https://research.chalmers.se/en/publication/177148
- Mathur ve ark.: dark pattern'i belirlerken kullanıcının özerkliğine, bilgi dengesizliğine, ölçüsüz etkiye bakan çok perspektifli bir değerlendirme önerilir (özet düzeyi). [B] https://arxiv.org/abs/2101.04843
- Duolingo'nun kendi gerekçesi: "alışkanlık için engeli düşür" + "doğruyu ödüllendir" (Energy) → ceza yerine pozitif çerçeve [B]. Bu ahlaki bir iddia olarak değil, ürün tercihi olarak okunmalı; kritikler Energy'yi "cash grab" olarak da değerlendirdi [İ] https://androidauthority.com/quitting-duolingo-energy-system-3599842 (arama özeti).
- Hook Model'in yazarı kendi etik sorularını önerir ("Siz kullanır mıydınız? İnsanların hayatını iyileştiriyor mu?") [İ].
- FTC/AB/Play politikaları önceki dosyada (§3 ve §4); sahte geri sayım ve gerçek olmayan kıtlık yasak/riskli.
- Pratik kurallar [GÇ]: (1) her zaman nasıl-bırakılır/kapatılır net olsun (opt-out lig, bildirim kapatma); (2) streak kopması için utandırma metni yok; (3) FOMO yalnız gerçek ve geri getirilebilir içerikle; (4) ücretli rastgele ödül yok; (5) çocuk kitlesi ihtimaline karşı yaş/reklam ayarları (önceki dosya, Families); (6) streak freeze/kurtarma yalnız satın almaya bağlı olmasın.

---

## 7) Doğrulanamayanlar

- Ryan & Deci 2000 ve Zagal ve ark. 2013 tam metni (PDF araçla okunamadı): yalnızca özet/künye.
- S-1'deki "Leaderboards öğrenme süresini ~%20 artırdı" ve "streak'li kullanıcılar yarıdan fazla" ifadeleri bir arama özetinde geçti; okunan ilk 100.000 karakterde yok (belgenin kalanı okunmadı).
- Duolingo bildirim strateji blogu (URL 404), Friend Streak sonrası ölçülmüş etki, Streak Society/Quests.
- NYT/Wordle birincil kaynakları (nytimes.com, nytco.com, Axios 403); Games abone sayıları; Wordle günlük oyuncu rakamları (yalnızca ikincil, ölçütsüz).
- King can sistemi/etkinlik takvimi (birincil yok); GDC King/Supercell konuşma içerikleri okunmadı.
- Supercell sandık deneyi sonuçları (yayımlanmamış); Pokémon GO/Niantic'in etkinlik ritmi birincil verisi.
- Fortnite/Genshin pass için Epic/HoYoverse birincil veya hakemli çalışma; Genshin retention (D1 %41,2 vb.) ikincil ve ölçütsüz.
- Kahoot, Trivia Crack, QuizUp'ın kendi retention verisi.
- Streak kaybı için "loss aversion" etkisinin büyüklüğü (Duolingo yalnız beyan ediyor; sayı yok).
- "What-the-hell etkisi" (seri kopunca toplu terk) bu çalışmada kaynaklanmadı; tasarım çıkarımı.
- Bu projenin mevcut özelliklerinin gerçek kapsamı (kod incelenmedi).

---

## 8) Kaynak listesi

Birincil [B]
1. https://blog.duolingo.com/how-duolingo-streak-builds-habit/
2. https://blog.duolingo.com/improving-the-streak
3. https://blog.duolingo.com/product-lessons-friend-streak/
4. https://blog.duolingo.com/duolingo-leagues-leaderboards/
5. https://blog.duolingo.com/learning-how-to-help-you-learn-introducing-birdbrain
6. https://research.duolingo.com/ (KDD 2020 veri seti notu)
7. https://research.Duolingo.com/papers/yancey.kdd20.pdf (özet arama sonucundan; PDF okunmadı)
8. https://www.sec.gov/Archives/edgar/data/1562088/000162828021013065/duolingos-1.htm (S-1, ilk 100.000 karakter)
9. https://www.sec.gov/Archives/edgar/data/1562088/000156208825000165/q2fy25duolingo6-30x25share.htm (Q2 2025)
10. https://supercell.com/en/games/clashroyale/blog/news/chest-experiment-king-tower-levels-1-9
11. https://research.chalmers.se/en/publication/177148 (Zagal ve ark., özet)
12. https://gup.ub.gu.se/file/101018 (Zagal tam metin, okunamadı)
13. https://selfdeterminationtheory.org/SDT/documents/2000_RyanDeci_SDT.pdf (okunamadı)
14. https://repository.essex.ac.uk/7228/ (Przybylski ve ark. 2010)
15. https://epub.ub.uni-muenchen.de/53202 (Sailer ve ark. 2017)
16. https://leeds-faculty.colorado.edu/dahe7472/deci%201999.pdf (Deci ve ark. 1999)
17. https://research.aalto.fi/fi/publications/does-gamification-work-a-literature-review-of-empirical-studies-o/ (Hamari ve ark. 2014)
18. https://pure.itu.dk/en/publications/from-game-design-elements-to-gamefulness-defining-gamification/ (Deterding ve ark. 2011)
19. https://dlab.sauder.ubc.ca/sjdm/journal/22/220414/jdm220414.html (loss aversion meta-analizi)
20. https://wrap.warwick.ac.uk/185745 (Walasek ve ark.)
21. https://arxiv.org/abs/2101.04843 (Mathur ve ark. 2021)
22. https://www.interruptions.net/literature/Pielot-MobileHCI18.pdf (Pielot ve ark. 2018)
23. https://ic.unicamp.br/~oliveira/doc/MHCI2014_An-in-situ-study-of-mobile-phone-notifications.pdf
24. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5399220/ (Pokémon GO anketi)
25. https://ijvlms.sums.ac.ir/article_51408.html (Kahoot ödül/liderlik)
26. https://files.cdha.ca/profession/journal/2841.pdf (Kahoot canlı liderlik, stres)
27. https://www.cs.princeton.edu/techreports/2012/931.pdf (Kao 2012, tez)
28. https://schedule.gdconf.com/session/sugary-statistics-what-we-have-learned-about-candy-crush-content-after-10-years-and-over-15000-levels/900207 (GDC oturum sayfası)
29. https://schedule.gdconf.com/session/the-invisible-layer-redesigning-communication-and-navigation-in-candy-crush-soda-saga/915587

İkincil [İ]
30. https://techcrunch.com/2020/02/14/hq-trivia-shuts-down
31. https://www.bloomberg.com/news/articles/2020-02-15/hq-trivia-is-shutting-down-after-brief-run-as-media-sensation
32. https://fortune.com/2013/12/11/how-an-icelanders-viking-journey-helped-create-a-trivia-sensation
33. https://techcrunch.com/2020/06/17/quizup-founder-gets-back-to-trivia-roots-with-the-launch-of-trivia-royale
34. https://www.pocketgamer.biz/interview/77477/user-generated-content-key-trivia-crack/
35. https://www.boston.com/news/national-news/2022/01/04/he-made-wordle-for-his-partner-now-its-an-online-hit/
36. https://en.wikipedia.org/wiki/Wordle
37. https://www.axios.com/2023/03/23/new-york-times-wordle-game-developers-conference (arama özeti)
38. https://www.ivey.uwo.ca/hba/blog/2025/03/the-daily-puzzle-phenomenon-how-nyt-turned-games-into-a-subscription-goldmine/
39. https://www.gamedeveloper.com/design/the-math-of-clash-royale
40. https://www.dualshockers.com/clash-royale-summer-update-2021-patch-notes-new-goblin-drill-card/
41. https://www.gameinformer.com/b/news/archive/2018/01/12/niantic-announces-pokemon-go-community-day.aspx
42. https://automaton-media.com/en/?p=10815
43. https://www.pocketgamer.biz/an-analysis-of-genshin-impacts-mobile-success-and-how-it-could-grow-even-bigger
44. https://www.blog.udonis.co/mobile-marketing/mobile-games/genshin-impact-monetization
45. https://experience.thinkvermont.com/exp/fortnites-battle-pass-evolution-how-a-single-game-shaped-live-service-gaming (düşük güven)
46. https://androidauthority.com/quitting-duolingo-energy-system-3599842
47. https://www.recall.it/summary/lennys-podcast/behind-the-product-duolingo-streaks-or-jackson-shuttleworth-group-pm-retention-team
48. https://concepts.dsebastien.net/concept/hook-model/
49. https://www.publichealth.columbia.edu/news/global-study-confirms-influential-theory-behind-loss-aversion
50. https://aph.gov.au/Parliamentary_Business/Committees/Senate/Environment_and_Communications/Gamingmicro-transactions/Report/c03
51. https://paperswithcode.com/paper/a-sleeping-recovering-bandit-algorithm-for (KDD 2020 özet aynası)
