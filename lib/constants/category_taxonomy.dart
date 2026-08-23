import 'dart:math';

class CategoryTaxonomy {
  static final Random _random = Random();

  /// 22 Kategorinin tamamı için zenginleştirilmiş mikro-tema ve alt başlık matrisi
  static const Map<String, List<String>> subTopics = {
    // 1. Genel Kültür
    'Genel Kültür': [
      'Antik Keşifler, Arkeoloji ve Batık Şehirler',
      'Nobel Ödülleri, Çığır Açan Mucitler ve Buluşlar',
      'İlginç Coğrafi Sınırlar, Enkavlar ve Mikro-Devletler',
      'Dünya Mimarisi, Heykeller ve Anıtsal Yapılar',
      'Havacılık Tarihi, Zeplinler ve Uzay Görevleri',
      'Sanat Akımları, Kült Tablolar ve Ressamların Hayatı',
      'Dünya Mitolojileri, Efsanevi Yaratıklar ve Destanlar',
      'Felsefi Paradokslar, Mantık Bulmacaları ve Düşünce Tarihi',
      'Dünya Müzik Tarihi, Senfoniler ve Geleneksel Enstrümanlar',
      'Guinness Dünya Rekorları ve Sıra Dışı Doğa Olayları',
      'Uluslararası Antlaşmalar, Tarihi Zirveler ve Kuruluşlar',
      'Dünya Para Birimleri, Merkez Bankaları ve Finans Tarihi',
    ],

    // 2. Yemek Kültürü
    'Yemek Kültürü': [
      'Geleneksel Türk Saray Mutfağı ve Selçuklu Lezzetleri',
      'Anadolu Yöresel Yemekleri, Coğrafi İşaretli Ürünler',
      'Dünya Baharatları, İpek ve Baharat Yolu Rotaları',
      'Michelin Rehberi, Efsane Şefler ve Mutfak Teknikleri',
      'Fermantasyon Sanatı, Peynir Kültürü ve Ekmek Tarihi',
      'Uzak Doğu Mutfağı (Sushi, Dim Sum, Ramen Çeşitleri)',
      'Akdeniz ve İtalyan Makarnaları, Pizza ve Sos Sırları',
      'Sokak Lezzetleri, Gece Pazarları ve Kültürel Atıştırmalıklar',
      'Kahve Kuşakları, Çay Seremonileri ve Demleme Kültürü',
      'Geleneksel Tatlılar, Çikolata Tarihi ve Pastacılık',
    ],

    // 3. Coğrafya
    'Coğrafya': [
      'Fiyortlar, Kanyonlar ve Sıra Dışı Jeolojik Oluşumlar',
      'Dünya Başkentleri, Değişen Başkentler ve Planlı Şehirler',
      'Kıtalararası Boğazlar, Kanallar ve Deniz Ticaret Yolları',
      'Dünyanın En Uç Noktaları (En Yüksek, En Derin, En Soğuk)',
      'Ada Ülkeleri, Mercan Resifleri ve Okyanus Çukurları',
      'İklim Kuşakları, Muson Rüzgarları ve Çölleşme',
      'Volkanik Kuşaklar, Pasifik Ateş Çemberi ve Gayzerler',
      'Nehir Havzaları, Deltalar ve Sınır Çizen Akarsular',
      'Dünya Bayrakları, Armaları ve Sembollerinin Anlamları',
      'Zaman Dilimleri, Tarih Değiştirme Çizgisi ve Kutuplar',
    ],

    // 4. Futbol
    'Futbol': [
      'FIFA Dünya Kupası Unutulmaz Finalleri ve Gol Kralları',
      'UEFA Şampiyonlar Ligi Efsane Geri Dönüşleri ve Rekorlar',
      'Süper Lig Şampiyonlukları, Derbiler ve Tarihi Maçlar',
      'Ballon d\'Or Kazananları, Altın Ayakkabı ve Efsanevi 10 Numaralar',
      'Taktiksel Dizilişler (Tiki-Taka, Catenaccio, Gegenpressing)',
      'Efsanevi Stadyumlar, Taraftar Kültürü ve Marşlar',
      'Dünya Kupası Maskotları, Topları ve İkonik Formalar',
      'Unutulmaz Hakem Kararları, VAR Sistemi ve Kural Tarihi',
      'Transfer Rekorları, Bonservis Tarihi ve Efsane Kulüp Başkanları',
      'Milli Takım Başarıları, Euro Kupaları ve Copa America',
    ],

    // 5. Dini
    'Dini': [
      'İslam Tarihi, Dört Halife Dönemi ve Büyük Gazveler',
      'Kuran-ı Kerim Sureleri, Ayetleri ve Nüzul Sebepleri',
      'Peygamberler Tarihi, Mucizeleri ve Kıssaları',
      'İslam Alimleri (İmam Gazali, İbni Sina, Biruni, Razi)',
      'Hac, Umre, Kabe Mimarisi ve Kutsal Mekanlar',
      'Tasavvuf, Mevlana, Yunus Emre ve Hacı Bektaş Veli',
      'İslam Sanatları (Hat, Tezhip, Minyatür, Ebru Sanatı)',
      'Osmanlı Vakıf Kültürü, Selatin Camileri ve Külliyeler',
      'Fıkıh, Tefsir ve Hadis Usulü Temel Kavramları',
      'İlahi Kitaplar ve Peygamberlere İndirilen Sahifeler',
    ],

    // 6. Bilim
    'Bilim': [
      'Kuantum Fiziği, Parçacık Hızlandırıcılar ve Atomaltı Evren',
      'Genetik Mühendisliği, DNA Sarmalı ve CRISPR Teknolojisi',
      'Periyodik Tablo, Elementlerin Keşfi ve Kimyasal Reaksiyonlar',
      'Gökbilim, Karadelikler, James Webb Teleskobu ve Ötegezegenler',
      'Evrimsel Biyoloji, Fosiller ve Kambriyen Patlaması',
      'Bilgisayar Biliminin Doğuşu (Turing, Ada Lovelace, Von Neumann)',
      'Beyin Mimarisi, Nöronlar ve Bilişsel Sinirbilim',
      'Yenilenebilir Enerji, Füzyon Reaktörleri ve Termodinamik',
      'Efsane Deneyler (Schrödinger, Çift Yarık, Michelson-Morley)',
      'Tıp Tarihi, Aşıların Keşfi ve Penisilin Devrimi',
    ],

    // 7. Sinema ve Dizi
    'Sinema ve Dizi': [
      'Oscar (Akademi) Ödülleri Rekorları ve En İyi Film Kazananları',
      'Kült Yönetmenler (Nolan, Tarantino, Kubrick, Hitchcock)',
      'Sinema Tarihinin İkonik Kurgusal Karakterleri ve Replikleri',
      'Yeşilçam Klasikleri, Şener Şen, Kemal Sunal ve Unutulmaz Sahneler',
      'Film Müzikleri (Hans Zimmer, John Williams, Ennio Morricone)',
      'Bilim Kurgu Başyapıtları (Matrix, Interstellar, Star Wars)',
      'Emmy Ödüllü Kült Diziler (Breaking Bad, Game of Thrones, Sopranos)',
      'Animasyon Stüdyoları (Pixar, Ghibli, Disney) ve Çizgi Sanatı',
      'Film Noir, Bağımsız Sinema ve Cannes Film Festivali',
      'CGI Teknolojisi, Özel Efektler ve Sinematografi Teknikleri',
    ],

    // 8. Tarih
    'Tarih': [
      'Antik Roma ve Yunan Savaşları, Lejyonlar ve Senato Düzeni',
      'Osmanlı Yükselme, Diplomasi ve Askeri Teşkilatı',
      'I. ve II. Dünya Savaşı Kritik Muharebeleri ve Kod Çözücüler',
      'Fransız İhtilali, Aydınlanma Çağı ve Sanayi Devrimi',
      'Soğuk Savaş Dönemi, Küba Krizi ve Casusluk Tarihi',
      'Büyük İpek Yolu, Baharat Yolu ve Coğrafi Keşifler',
      'Orta Çağ Kaleleri, Şövalye Düzeni ve Haçlı Seferleri',
      'Mezopotamya, Babil\'in Asma Bahçeleri ve Sümer Tabletleri',
      'Kurtuluş Savaşı, Çanakkale Muharebesi ve Cumhuriyet Dönemi',
      'Büyük Liderler (İskender, Sezar, Cengiz Han, Fatih, Atatürk)',
    ],

    // 9. Magazin
    'Magazin': [
      'Hollywood\'un Altın Çağı Yıldızları ve Efsanevi Boşanmalar',
      'Dünya Modası, Met Gala Temaları ve İkonik Tasarımcılar',
      'Kraliyet Aileleri (İngiliz Monarşisi, Monako Hanedanı)',
      'Eurovision Şarkı Yarışması Tarihi ve Skandalları',
      'Sosyal Medya Fenomenleri, Viral Olaylar ve Trendler',
      'Ünlülerin Sahne İsimleri ve Gerçek Kimlikleri',
      'Popüler Kültür İkonları (Michael Jackson, Madonna, Elvis)',
      'Cannes ve Venedik Kırmızı Halı Unutulmaz Anları',
      'Ünlü Çiftler, İkonik Düğünler ve Ayrılıklar',
      'Türk Popüler Kültür Tarihi, 90\'lar Magazin Olayları',
    ],

    // 10. Müzik
    'Müzik': [
      'Rock Müzik Tarihi (Queen, Led Zeppelin, Pink Floyd, Beatles)',
      'Klasik Müzik Devleri (Mozart, Beethoven, Chopin, Bach)',
      'Türk Sanat Müziği Makamları ve Efsanevi Sesleri (Zeki Müren vb.)',
      'Türk Halk Müziği Ozanları (Aşık Veysel, Neşet Ertaş)',
      'Hip-Hop ve Rap Kültürünün Doğuşu, Doğu-Batı Rekabeti',
      'Grammy Ödülleri Tarihi, Rekortmen Albümler ve Plaklar',
      'Jazz ve Blues Kökenleri, New Orleans ve Efsane Trompetçiler',
      'Müzik Teorisi, Notalar, Akorlar ve Oktav Kavramları',
      'Elektronik Müzik (Synthwave, Techno, Daft Punk Devrimi)',
      'Dünyanın En Çok Satan Albümleri ve Stadyum Turneleri',
    ],

    // 11. Uzay ve Evren
    'Uzay ve Evren': [
      'Güneş Sistemi Gezegenleri, Uyduları ve Halkaları',
      'Karadelikler, Olay Ufku ve Hawking Radyasyonu',
      'NASA Apollo Görevleri, Ay\'a İniş ve Artemis Programı',
      'Hubble ve James Webb Uzay Teleskobu Keşifleri',
      'Süpernovalar, Nötron Yıldızları ve Pulsarlar',
      'Mars Keşif Araçları (Curiosity, Perseverance) ve Kolonizasyon',
      'Kozmolojik Teoriler (Büyük Patlama, Karanlık Madde, Karanlık Enerji)',
      'Uluslararası Uzay İstasyonu (ISS) ve Astronot Yaşamı',
      'Kuyruklu Yıldızlar, Asteroit Kuşağı ve Meteor Yağmurları',
      'Samanyolu Galaksisi ve Andromeda ile Çarpışma Senaryosu',
    ],

    // 12. Mitoloji ve Efsaneler
    'Mitoloji ve Efsaneler': [
      'Yunan Mitolojisi Olimpos Tanrıları ve Titan Savaşları',
      'İskandinav Mitolojisi (Odin, Thor, Loki, Ragnarök ve Yggdrasil)',
      'Mısır Mitolojisi (Ra, Anubis, Osiris, Mumyalama Ritüelleri)',
      'Türk Mitolojisi (Ergenekon Destanı, Gök Tanrı, Umay Ana)',
      'Kelt ve İrlanda Mitolojisi, Druidler ve Periler',
      'Japon Mitolojisi (Şinto Tanrıları, Kami ve Yokailer)',
      'Mezopotamya ve Gılgamış Destanı (Tufan Efsanesi)',
      'Kral Arthur Efsanesi, Yuvarlak Masa Şövalyeleri ve Excalibur',
      'Mitolojik Yaratıklar (Minotor, Medusa, Grifon, Sfenks)',
      'Aztek ve Maya Mitolojisi, Güneş Tanrıları ve Takvimler',
    ],

    // 13. Antik Uygarlıklar
    'Antik Uygarlıklar': [
      'Eski Mısır Firavunları, Piramitler ve Hiyeroglif Çözümü',
      'Mezopotamya Uygarlıkları (Sümer, Asur, Babil, Akkad)',
      'İnka, Maya ve Aztek İmparatorlukları ve Tapınak Kentleri',
      'Hititler, Kadeş Antlaşması ve Anadolu Medeniyetleri',
      'Antik Yunan Şehir Devletleri (Atina, Sparta, Thebai)',
      'Pers İmparatorluğu, Persepolis ve Kral Yolu',
      'Kayıp Kıtalar ve Efsanevi Kentler (Atlantis, Truva, Petra)',
      'İndus Vadisi Uygarlığı (Mohenjo-daro ve Harappa)',
      'Büyük İskender\'in Helenistik Krallıkları ve İskenderiye Kütüphanesi',
      'Etrüskler ve Erken Roma Dönemi Mühendislik Harikaları',
    ],

    // 14. Video Oyunları & Espor
    'Video Oyunları & Espor': [
      'Konsol Savaşları Tarihi (PlayStation, Xbox, Nintendo, Sega)',
      'Retro Oyunlar ve Arcade Çağı (Pac-Man, Mario, Tetris)',
      'RPG ve Açık Dünya Şaheserleri (Witcher, Skyrim, Elden Ring, Zelda)',
      'Espor Tarihi, The International (Dota 2) ve LoL Dünya Şampiyonası',
      'FPS Efsaneleri (Counter-Strike, Half-Life, Doom, Halo)',
      'Oyun Müzikleri ve Ses Tasarımı (Nobuo Uematsu, Mick Gordon)',
      'İkonik Oyun Karakterleri (Geralt, Kratos, Lara Croft, Master Chief)',
      'Steam Platformu, Valve Tarihi ve Bağımsız (Indie) Oyunlar',
      'Battle Royale Devrimi (PUBG, Fortnite, Warzone)',
      'Oyun Motorları (Unreal Engine, Unity) ve Grafiğin Evrimi',
    ],

    // 15. Dünya Mutfakları
    'Dünya Mutfakları': [
      'Fransız Gastronomisi, Beş Temel Sos ve Pişirme Disiplinleri',
      'İtalyan Bölgesel Lezzetleri (Toscana, Napoli, Sicilya)',
      'Geleneksel Japon Mutfak Felsefesi (Washoku, Kaiseki, Umami)',
      'Meksika Sokak Lezzetleri (Taco, Mole, Enchilada, Guacamole)',
      'Güneydoğu Asya Baharatları (Tayland, Vietnam, Endonezya)',
      'Hint Köri Çeşitleri, Tandoori ve Masala Karışımları',
      'Orta Doğu Mezeleri (Humus, Falafel, Şavurma, Tabule)',
      'Balkan Lezzetleri (Boşnak Böreği, Cevapi, Pljeskavica)',
      'İspanyol Tapas Kültürü, Paella ve Sangria Tarihi',
      'Füzyon Mutfak, Moleküler Gastronomi ve Modern Sunumlar',
    ],

    // 16. Dünya Harikaları & Doğa
    'Dünya Harikaları & Doğa': [
      'Antik Dünyanın 7 Harikası ve Günümüzdeki Kalıntıları',
      'Dünyanın Yeni 7 Harikası (Tac Mahal, Petra, Kolezyum vb.)',
      'Büyük Kanyon, Victoria Şelaleleri ve Iguazu Şelaleleri',
      'Büyük Set Resifi ve Okyanus Biyoçeşitliliği',
      'Kutup Işıkları (Aurora Borealis & Australis) ve Oluşumları',
      'Amazon Yağmur Ormanları ve Dünyanın Akciğerleri',
      'Mariana Çukuru ve Derin Deniz Canlıları',
      'Everest, K2 ve 8000 Metre Üzeri Ölüm Kuşağı Dağları',
      'Galapagos Adaları ve Türlerin Kökeni Keşifleri',
      'Pamukkale Travertenleri, Kapadokya ve Doğa Şaheserleri',
    ],

    // 17. Çizgi Roman & Anime
    'Çizgi Roman & Anime': [
      'Marvel Sinematik Evreni ve Çizgi Roman Kökenleri (Stan Lee)',
      'DC Comics Evreni (Batman, Superman, Gotham Tarihi)',
      'Shonen Anime Efsaneleri (One Piece, Naruto, Bleach, Dragon Ball)',
      'Hayao Miyazaki ve Studio Ghibli Başyapıtları',
      'Çizgi Roman Çağları (Altın, Gümüş, Bronz ve Modern Çağ)',
      'Manga Sektörü, Mangakalar ve Haftalık Shonen Jump Tarihi',
      'Karanlık Anime Başyapıtları (Death Note, Attack on Titan, Berserk)',
      'Grafik Romanlar (Watchmen, V for Vendetta, Sandman)',
      'Süper Kötüler (Joker, Thanos, Magneto, Madara) ve Motivasyonları',
      'Frankofon Çizgi Roman Kültürü (Tenten, Asteriks, Red Kit)',
    ],

    // 18. Felsefe & Düşünce
    'Felsefe & Düşünce': [
      'Antik Yunan Felsefesi (Sokrates, Platon, Aristoteles)',
      'Stoacılık ve Zihin Kontrolü (Marcus Aurelius, Seneca, Epiktetos)',
      'Varoluşçuluk Akımı (Nietzsche, Sartre, Camus, Kierkegaard)',
      'Aydınlanma Çağı Düşünürleri (Kant, Voltaire, Rousseau, Locke)',
      'Doğu Felsefesi (Konfüçyüsçülük, Taoizm, Zen Budizm)',
      'Etik İkilemler (Tramvay Problemi, Mahkum İkilemi, Faydacılık)',
      'Epistemoloji: Bilginin Kaynağı, Rasyonalizm ve Empirizm',
      'Siyaset Felsefesi (Machiavelli, Hobbes\'un Leviathan\'ı, Ütopyalar)',
      'Zihin Felsefesi ve Yapay Zeka Etiği (Turing Testi, Çin Odası)',
      'Nihilizm, Absürdizm ve Hayatın Anlamı Arayışları',
    ],

    // 19. Yapay Zeka & Gelecek
    'Yapay Zeka & Gelecek': [
      'Büyük Dil Modelleri (LLM), Transformatör Mimarisi ve Üretken Yapay Zeka',
      'Yapay Genel Zeka (AGI), Tekillik (Singularity) ve Gelecek Senaryoları',
      'Otonom Araçlar, Sürücüsüz Sistemler ve Robotaksi Devrimi',
      'Sibernetik, Neuralink, Beyin-Bilgisayar Arayüzleri (BCI)',
      'Kuantum Bilgisayarlar, Qubitler ve Geleceğin Kriptografisi',
      'Siber Güvenlik, Kuantum Kriptografi ve Sıfır Gün Açıkları',
      'İnsansı Robotlar (Boston Dynamics, Tesla Optimus) ve Endüstri 5.0',
      'Uzay Kolonizasyonu, Ay Üsleri ve Mars Terraforming Projeleri',
      'Biyoteknoloji, Sentetik Biyoloji ve Yapay Organlar',
      'Transhümanizm, Uzatılmış Yaşam ve Geleceğin Şehirleri (Smart Cities)',
    ],

    // 20. Doğa ve Vahşi Yaşam
    'Doğa ve Vahşi Yaşam': [
      'Büyük Kediler (Aslan, Kaplan, Jaguar, Çita) ve Avlanma Stratejileri',
      'Derin Deniz Canlıları, Biyolüminesans ve Aşırı Uç Yaşam Formları',
      'Kuşların Göç Yolları, Yön Bulma Yetenekleri ve Aerodinamik',
      'Zehirli Canlılar (Koni Salyangozu, Kutu Denizanası, Taipan Yılanı)',
      'Memelilerin Evrimi, Balinalar ve Yunusların İletişim Zekası',
      'Böcekler Alemi, Karınca Kolonileri ve Termit Mimari Harikaları',
      'Kamuflaj Sanatı, Mimikri ve Doğadaki Görünmezlik Teknikleri',
      'Nesli Tükenmekte Olan Türler ve Küresel Koruma Rezervleri',
      'Bitkiler Arası İletişim, Mantar Ağları (Mikoriza) ve Ağaç Zekası',
      'Kutup Hayvanları, Antarktika Ekosistemi ve Soğuk Adaptasyonları',
    ],

    // 21. Klasik Sanat & Mimari
    'Klasik Sanat & Mimari': [
      'İtalyan Rönesansı (Leonardo da Vinci, Michelangelo, Rafael)',
      'Barok Dönemi Sanatı ve Işık-Gölge Ustaları (Caravaggio, Rembrandt)',
      'Gotik Katedraller, Uçan Payandalar ve Vitray Sanatı',
      'Empresyonizm (İzlenimcilik) ve Işığın Ressamları (Monet, Renoir)',
      'Post-Empresyonizm ve Dışavurumculuk (Van Gogh, Gauguin, Munch)',
      'Antik Roma Kemerleri, Su Kemerleri ve Kubbe Mimarisi (Pantheon)',
      'Modern Mimari Öncüleri (Gaudí, Le Corbusier, Zaha Hadid, Mimar Sinan)',
      'Kübizm, Sürrealizm ve Avangard Devrimler (Picasso, Salvador Dali)',
      'Heykel Sanatının Başyapıtları (Davud, Pieta, Kanatlı Zafer Heykeli)',
      'Bauhaus Akımı, Minimalizm ve Form Fonksiyonu İlişkisi',
    ],

    // 22. Edebiyat & Başyapıtlar
    'Edebiyat & Başyapıtlar': [
      'Rus Edebiyatı Devleri (Dostoyevski, Tolstoy, Çehov, Gogol)',
      'Dünya Klasikleri (Suç ve Ceza, Sefiller, Savaş ve Barış, Anna Karenina)',
      'Distopya Edebiyatı (1984, Cesur Yeni Dünya, Fahrenheit 451)',
      'Türk Edebiyatı Romanları (Saatleri Ayarlama Enstitüsü, Tutunamayanlar)',
      'Büyülü Gerçekçilik (Gabriel Garcia Marquez, Yüzyıllık Yalnızlık)',
      'Shakespeare Trajedileri ve Komedileri (Hamlet, Macbeth, Othello)',
      'Dünya Şiir Tarihi (Nazım Hikmet, Dante, Edgar Allan Poe, Baudelaire)',
      'Polisiye Edebiyatının Doğuşu (Sherlock Holmes, Agatha Christie, Poirot)',
      'Nobel Edebiyat Ödüllü Yazarlar ve Başyapıtları',
      'Epik Destanlar (İlyada, Odysseia, Şehname, Kalevala)',
    ],
  };

  /// Soru sorma açısı / format çeşitlendirmesi
  static const List<String> questionAngles = [
    'İstisna & Aykırılık Açısı ("Aşağıdakilerden hangisi bu duruma / gruba / döneme dahil DEĞİLDİR?")',
    'Kronolojik Sıralama & Zaman Açısı ("Aşağıdaki olaylardan / eserlerden hangisi diğerlerinden daha önce / sonra gerçekleşmiştir?")',
    'Vaka / Senaryo & Tarihi Olay Açısı ("Tarihte yaşanan şu kritik olayın sonucunda ortaya çıkan gelişme...")',
    'Öncül & İpucu Analizi ("Hakkında ipuçları verilen (doğum yeri, ödülü, ünlü eseri) kişi / yer / kavram hangisidir?")',
    'Eşleştirme & Eser-Yazar / Şehir-Ülke Açısı ("Aşağıdaki eşleştirmelerden hangisi yanlıştır / doğrudur?")',
    'Köken & Etimoloji / İlk Kez Açısı ("Dünyada ilk kez nerede / kim tarafından ortaya çıkarılmıştır?")',
    'Sebep-Sonuç İlişkisi ("Bu tarihi/bilimsel kırılmanın arkasındaki temel itici güç neydi?")',
  ];

  /// Verilen kategori için rastgele bir mikro-tema döner
  static String getRandomSubTopic(String categoryName) {
    final list = subTopics[categoryName];
    if (list != null && list.isNotEmpty) {
      return list[_random.nextInt(list.length)];
    }
    return 'Tarihsel ve Kültürel Gelişmeler';
  }

  /// Rastgele bir soru sorma kurgusu / açısı döner
  static String getRandomQuestionAngle() {
    return questionAngles[_random.nextInt(questionAngles.length)];
  }

  /// Yüksek entropili yaratıcı tohum döner
  static int generateEntropySeed() {
    return DateTime.now().microsecondsSinceEpoch ^ (_random.nextInt(1000000));
  }
}
