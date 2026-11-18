import '../models/question.dart';

/// Curated offline question bank keyed by normalized language (`tr`, `en`)
/// and canonical category name matching `AppCategories.categories`.
final Map<String, Map<String, List<Question>>> offlineCategoryQuestions = {
  'tr': {
    'Genel Kültür': [
      Question(
        question: "Türkiye Büyük Millet Meclisi hangi yıl açılmıştır?",
        options: ["1919", "1920", "1921", "1923"],
        correctIndex: 1,
      ),
      Question(
        question: "Bir satranç tahtasında toplam kaç kare vardır?",
        options: ["48", "56", "64", "72"],
        correctIndex: 2,
      ),
      Question(
        question: "UNESCO Dünya Mirası Listesi'ndeki Göbeklitepe hangi ilimizdedir?",
        options: ["Gaziantep", "Şanlıurfa", "Mardin", "Adıyaman"],
        correctIndex: 1,
      ),
      Question(
        question: "Olimpiyat bayrağındaki iç içe geçmiş halka sayısı kaçtır?",
        options: ["4", "5", "6", "7"],
        correctIndex: 1,
      ),
      Question(
        question: "Türk Lirası'nın uluslararası ISO para birimi kodu nedir?",
        options: ["TRL", "YTL", "TRY", "TUR"],
        correctIndex: 2,
      ),
    ],
    'Yemek Kültürü': [
      Question(
        question: "Gaziantep mutfağıyla özdeşleşen coğrafi işaretli tatlı hangisidir?",
        options: ["Künefe", "Baklava", "Kazandibi", "Revani"],
        correctIndex: 1,
      ),
      Question(
        question: "İtalyan mutfağının klasik tatlısı Tiramisu'nun ana aroması nedir?",
        options: ["Çilek", "Kahve", "Limon", "Tarçın"],
        correctIndex: 1,
      ),
      Question(
        question: "Karadeniz mutfağında mısır unu ve tereyağıyla yapılan yöresel yemek hangisidir?",
        options: ["Kuymak", "Mantı", "Keşkek", "Tantuni"],
        correctIndex: 0,
      ),
      Question(
        question: "Humus yapımında temel baklagil olarak hangisi kullanılır?",
        options: ["Mercimek", "Fasulye", "Nohut", "Bezelye"],
        correctIndex: 2,
      ),
      Question(
        question: "Suşi sarımında kullanılan kurutulmuş deniz yosununa ne ad verilir?",
        options: ["Wasabi", "Nori", "Tofu", "Miso"],
        correctIndex: 1,
      ),
    ],
    'Coğrafya': [
      Question(
        question: "Dünyanın yüzölçümü bakımından en büyük okyanusu hangisidir?",
        options: ["Atlas", "Hint", "Büyük Okyanus", "Arktik"],
        correctIndex: 2,
      ),
      Question(
        question: "Türkiye'nin en büyük gölü hangisidir?",
        options: ["Tuz Gölü", "Beyşehir Gölü", "Van Gölü", "Eğirdir Gölü"],
        correctIndex: 2,
      ),
      Question(
        question: "Avustralya'nın başkenti neresidir?",
        options: ["Sidney", "Melbourne", "Kanberra", "Perth"],
        correctIndex: 2,
      ),
      Question(
        question: "Dünyanın en derin noktası olan Mariana Çukuru hangi okyanustadır?",
        options: ["Atlas Okyanusu", "Hint Okyanusu", "Pasifik Okyanusu", "Güney Okyanusu"],
        correctIndex: 2,
      ),
      Question(
        question: "İki kıtayı birbirinden ayıran İstanbul Boğazı hangi iki denizi bağlar?",
        options: ["Ege ve Akdeniz", "Karadeniz ve Marmara", "Marmara ve Ege", "Karadeniz ve Akdeniz"],
        correctIndex: 1,
      ),
    ],
    'Futbol': [
      Question(
        question: "FIFA Dünya Kupası'nı tarihte en çok kazanan ülke hangisidir?",
        options: ["Almanya", "İtalya", "Arjantin", "Brezilya"],
        correctIndex: 3,
      ),
      Question(
        question: "Bir futbol maçında devre arası normal şartlarda kaç dakikadır?",
        options: ["10", "15", "20", "25"],
        correctIndex: 1,
      ),
      Question(
        question: "UEFA Şampiyonlar Ligi'ni en fazla kazanan kulüp hangisidir?",
        options: ["Milan", "Bayern Münih", "Real Madrid", "Liverpool"],
        correctIndex: 2,
      ),
      Question(
        question: "Türkiye A Milli Futbol Takımı'nın 2002 Dünya Kupası derecesi nedir?",
        options: ["İkincilik", "Üçüncülük", "Dördüncülük", "Çeyrek Final"],
        correctIndex: 1,
      ),
      Question(
        question: "Penaltı vuruşu kale çizgisinden kaç metre uzaklıktan kullanılır?",
        options: ["9", "10", "11", "12"],
        correctIndex: 2,
      ),
    ],
    'Dini': [
      Question(
        question: "İslam'ın beş şartından biri olan zekat yılın hangi oranında verilir (altın/nakit)?",
        options: ["1/10", "1/20", "1/40", "1/100"],
        correctIndex: 2,
      ),
      Question(
        question: "Kur'an-ı Kerim kaç cüzden oluşur?",
        options: ["20", "24", "30", "40"],
        correctIndex: 2,
      ),
      Question(
        question: "Ramazan ayının içinde bulunan bin aydan hayırlı gece hangisidir?",
        options: ["Miraç", "Berat", "Regaip", "Kadir Gecesi"],
        correctIndex: 3,
      ),
      Question(
        question: "Hac ibadeti sırasında Kabe çevresinde 7 kez dönmeye ne denir?",
        options: ["Sa'y", "Tavaf", "Vakfe", "İhram"],
        correctIndex: 1,
      ),
      Question(
        question: "Kur'an-ı Kerim'de ilk indirilen sure hangisidir?",
        options: ["Fatiha", "Alak", "İhlas", "Bakara"],
        correctIndex: 1,
      ),
    ],
    'Bilim': [
      Question(
        question: "Periyodik tabloda atom numarası 1 olan element hangisidir?",
        options: ["Helyum", "Lityum", "Hidrojen", "Karbon"],
        correctIndex: 2,
      ),
      Question(
        question: "İnsan hücresinde genetik bilgiyi taşıyan molekül hangisidir?",
        options: ["ATP", "DNA", "İnsülin", "Kolesterol"],
        correctIndex: 1,
      ),
      Question(
        question: "Işığın boşluktaki hızı yaklaşık saniyede kaç kilometredir?",
        options: ["30.000", "150.000", "300.000", "500.000"],
        correctIndex: 2,
      ),
      Question(
        question: "Penisilini keşfederek tıp tarihinde çığır açan bilim insanı kimdir?",
        options: ["Louis Pasteur", "Alexander Fleming", "Marie Curie", "Gregor Mendel"],
        correctIndex: 1,
      ),
      Question(
        question: "Dünya atmosferinde hacimce en fazla bulunan gaz hangisidir?",
        options: ["Oksijen", "Karbondioksit", "Azot", "Argon"],
        correctIndex: 2,
      ),
    ],
    'Sinema ve Dizi': [
      Question(
        question: "Oscar (Akademi) Ödülleri hangi ülkede verilmektedir?",
        options: ["İngiltere", "Fransa", "ABD", "Kanada"],
        correctIndex: 2,
      ),
      Question(
        question: "Yüzüklerin Efendisi üçlemesinin yönetmeni kimdir?",
        options: ["Steven Spielberg", "Peter Jackson", "Christopher Nolan", "Ridley Scott"],
        correctIndex: 1,
      ),
      Question(
        question: "Cannes Film Festivali'nde Altın Palmiye alan ilk Türk filmi hangisidir?",
        options: ["Uzak", "Yol", "Kış Uykusu", "Sürü"],
        correctIndex: 1,
      ),
      Question(
        question: "Hababam Sınıfı eserinin yazarı kimdir?",
        options: ["Aziz Nesin", "Rıfat Ilgaz", "Orhan Kemal", "Yaşar Kemal"],
        correctIndex: 1,
      ),
      Question(
        question: "Baba (The Godfather) filminin ünlü yönetmeni kimdir?",
        options: ["Martin Scorsese", "Francis Ford Coppola", "Quentin Tarantino", "Alfred Hitchcock"],
        correctIndex: 1,
      ),
    ],
    'Tarih': [
      Question(
        question: "Anadolu'nun kapılarını Türklere açan Malazgirt Savaşı hangi yılda yapılmıştır?",
        options: ["1040", "1071", "1176", "1243"],
        correctIndex: 1,
      ),
      Question(
        question: "Yazıyı tarihte ilk kez hangi uygarlık icat etmiştir?",
        options: ["Mısırlılar", "Sümerler", "Hititler", "Fenikeliler"],
        correctIndex: 1,
      ),
      Question(
        question: "Osmanlı Devleti'nin kurucusu Osman Bey devleti hangi yılda kurmuştur?",
        options: ["1281", "1299", "1326", "1363"],
        correctIndex: 1,
      ),
      Question(
        question: "Cumhuriyet hangi tarihte ilan edilmiştir?",
        options: ["23 Nisan 1920", "30 Ağustos 1922", "29 Ekim 1923", "10 Kasım 1938"],
        correctIndex: 2,
      ),
      Question(
        question: "Dünya tarihinin bilinen ilk yazılı barış antlaşması hangisidir?",
        options: ["Kadeş", "Westphalia", "Utrecht", "Lozan"],
        correctIndex: 0,
      ),
    ],
    'Magazin': [
      Question(
        question: "Eurovision Şarkı Yarışması'nı Türkiye'ye kazandıran sanatçı kimdir?",
        options: ["Şebnem Paker", "Sertab Erener", "Hadise", "Kenan Doğulu"],
        correctIndex: 1,
      ),
      Question(
        question: "Altın Kelebek Ödülleri her yıl hangi alanda başarıları ödüllendirir?",
        options: ["Mimarlık", "Televizyon ve Müzik", "Ekonomi", "Tarım"],
        correctIndex: 1,
      ),
      Question(
        question: "'Megastar' lakabıyla tanınan Türk pop müzik sanatçısı kimdir?",
        options: ["Mustafa Sandal", "Tarkan", "Serdar Ortaç", "Teoman"],
        correctIndex: 1,
      ),
      Question(
        question: "Met Gala her yıl hangi şehirdeki müzede düzenlenir?",
        options: ["Londra", "Paris", "New York", "Milano"],
        correctIndex: 2,
      ),
      Question(
        question: "Dünyaca ünlü film ve dizi veri tabanı sitesi hangisidir?",
        options: ["Spotify", "IMDb", "Behance", "GitHub"],
        correctIndex: 1,
      ),
    ],
    'Müzik': [
      Question(
        question: "Bir müzik dizeğinde kaç paralel çizgi bulunur?",
        options: ["4", "5", "6", "7"],
        correctIndex: 1,
      ),
      Question(
        question: "Klasik bir akustik gitarda standart olarak kaç tel vardır?",
        options: ["4", "5", "6", "8"],
        correctIndex: 2,
      ),
      Question(
        question: "Do majör gamında kaç adet diyez veya bemol işareti vardır?",
        options: ["0", "1", "2", "3"],
        correctIndex: 0,
      ),
      Question(
        question: "Dokuzuncu Senfoni'yi sağırlık döneminde tamamlayan ünlü besteci kimdir?",
        options: ["Mozart", "Bach", "Beethoven", "Chopin"],
        correctIndex: 2,
      ),
      Question(
        question: "Türk halk müziğinin vazgeçilmez telli tezeneli çalgısı hangisidir?",
        options: ["Piyano", "Bağlama", "Çello", "Arp"],
        correctIndex: 1,
      ),
    ],
  },
  'en': {
    'Genel Kültür': [
      Question(
        question: "How many squares are there on a standard chessboard?",
        options: ["48", "56", "64", "72"],
        correctIndex: 2,
      ),
      Question(
        question: "How many interlocking rings appear on the Olympic flag?",
        options: ["4", "5", "6", "7"],
        correctIndex: 1,
      ),
      Question(
        question: "Which calendar month has either 28 or 29 days?",
        options: ["January", "February", "April", "November"],
        correctIndex: 1,
      ),
      Question(
        question: "Which metal is liquid at standard room temperature?",
        options: ["Lead", "Mercury", "Zinc", "Aluminum"],
        correctIndex: 1,
      ),
      Question(
        question: "In which city is the Eiffel Tower located?",
        options: ["Lyon", "Marseille", "Paris", "Nice"],
        correctIndex: 2,
      ),
    ],
    'Yemek Kültürü': [
      Question(
        question: "Which legume is the primary ingredient in classic hummus?",
        options: ["Lentils", "Black beans", "Chickpeas", "Green peas"],
        correctIndex: 2,
      ),
      Question(
        question: "What is the signature flavor of traditional Italian Tiramisu?",
        options: ["Strawberry", "Coffee", "Lemon", "Mint"],
        correctIndex: 1,
      ),
      Question(
        question: "What is the dried seaweed sheet used to wrap sushi called?",
        options: ["Wasabi", "Nori", "Tofu", "Miso"],
        correctIndex: 1,
      ),
      Question(
        question: "Guacamole is primarily made from which fruit?",
        options: ["Mango", "Avocado", "Tomato", "Papaya"],
        correctIndex: 1,
      ),
      Question(
        question: "Which country is traditionally famous for croissants and baguettes?",
        options: ["Spain", "France", "Germany", "Portugal"],
        correctIndex: 1,
      ),
    ],
    'Coğrafya': [
      Question(
        question: "What is the capital city of Australia?",
        options: ["Sydney", "Melbourne", "Canberra", "Perth"],
        correctIndex: 2,
      ),
      Question(
        question: "Which is the largest ocean on Earth by surface area?",
        options: ["Atlantic", "Indian", "Pacific", "Arctic"],
        correctIndex: 2,
      ),
      Question(
        question: "Where is the Mariana Trench, the deepest oceanic trench, located?",
        options: ["Atlantic Ocean", "Indian Ocean", "Pacific Ocean", "Southern Ocean"],
        correctIndex: 2,
      ),
      Question(
        question: "Which strait separates Europe from Asia in Istanbul?",
        options: ["Gibraltar", "Bosphorus", "Bering", "Malacca"],
        correctIndex: 1,
      ),
      Question(
        question: "Which desert is the largest hot desert in the world?",
        options: ["Gobi", "Kalahari", "Sahara", "Mojave"],
        correctIndex: 2,
      ),
    ],
    'Futbol': [
      Question(
        question: "Which country has won the most FIFA World Cup titles?",
        options: ["Germany", "Italy", "Argentina", "Brazil"],
        correctIndex: 3,
      ),
      Question(
        question: "How long is the standard halftime break in a football match?",
        options: ["10 minutes", "15 minutes", "20 minutes", "25 minutes"],
        correctIndex: 1,
      ),
      Question(
        question: "Which club has won the UEFA Champions League the most times?",
        options: ["AC Milan", "Bayern Munich", "Real Madrid", "Liverpool"],
        correctIndex: 2,
      ),
      Question(
        question: "How many players are on the pitch per team at kickoff in football?",
        options: ["9", "10", "11", "12"],
        correctIndex: 2,
      ),
      Question(
        question: "How far is the penalty spot from the goal line in meters?",
        options: ["9", "10", "11", "12"],
        correctIndex: 2,
      ),
    ],
    'Dini': [
      Question(
        question: "How many chapters (Juz) is the Quran divided into for recitation?",
        options: ["20", "24", "30", "40"],
        correctIndex: 2,
      ),
      Question(
        question: "Which night in Ramadan is described as better than a thousand months?",
        options: ["Miraj", "Laylat al-Qadr", "Ashura", "Mawlid"],
        correctIndex: 1,
      ),
      Question(
        question: "What is the act of circling the Kaaba seven times during Hajj called?",
        options: ["Sa'y", "Tawaf", "Wuquf", "Ihram"],
        correctIndex: 1,
      ),
      Question(
        question: "Which city is home to the Masjid al-Haram and the Kaaba?",
        options: ["Medina", "Mecca", "Jerusalem", "Cairo"],
        correctIndex: 1,
      ),
      Question(
        question: "Which charity rate on qualifying savings is standard for Zakat?",
        options: ["1%", "2.5%", "5%", "10%"],
        correctIndex: 1,
      ),
    ],
    'Bilim': [
      Question(
        question: "Which element has atomic number 1 on the periodic table?",
        options: ["Helium", "Lithium", "Hydrogen", "Carbon"],
        correctIndex: 2,
      ),
      Question(
        question: "Which molecule carries genetic instructions in most living organisms?",
        options: ["ATP", "DNA", "Insulin", "Glucose"],
        correctIndex: 1,
      ),
      Question(
        question: "Who discovered penicillin in 1928?",
        options: ["Louis Pasteur", "Alexander Fleming", "Marie Curie", "Gregor Mendel"],
        correctIndex: 1,
      ),
      Question(
        question: "Which gas makes up the largest percentage of Earth's atmosphere?",
        options: ["Oxygen", "Carbon dioxide", "Nitrogen", "Argon"],
        correctIndex: 2,
      ),
      Question(
        question: "What is the speed of light in vacuum (approx. km per second)?",
        options: ["30,000", "150,000", "300,000", "500,000"],
        correctIndex: 2,
      ),
    ],
    'Sinema ve Dizi': [
      Question(
        question: "Who directed The Lord of the Rings film trilogy?",
        options: ["Steven Spielberg", "Peter Jackson", "Christopher Nolan", "Ridley Scott"],
        correctIndex: 1,
      ),
      Question(
        question: "Who directed the classic 1972 crime film The Godfather?",
        options: ["Martin Scorsese", "Francis Ford Coppola", "Quentin Tarantino", "Alfred Hitchcock"],
        correctIndex: 1,
      ),
      Question(
        question: "Which annual awards ceremony presents the golden Oscar statuette?",
        options: ["BAFTA", "Academy Awards", "Golden Globes", "Cannes"],
        correctIndex: 1,
      ),
      Question(
        question: "In which city does the Cannes Film Festival take place?",
        options: ["Venice", "Berlin", "Cannes", "Locarno"],
        correctIndex: 2,
      ),
      Question(
        question: "Which actor portrayed Tony Stark / Iron Man in the Marvel Cinematic Universe?",
        options: ["Chris Evans", "Robert Downey Jr.", "Mark Ruffalo", "Chris Hemsworth"],
        correctIndex: 1,
      ),
    ],
    'Tarih': [
      Question(
        question: "Which ancient civilization is credited with inventing cuneiform writing?",
        options: ["Egyptians", "Sumerians", "Phoenicians", "Greeks"],
        correctIndex: 1,
      ),
      Question(
        question: "In which year did the Apollo 11 Moon landing take place?",
        options: ["1965", "1967", "1969", "1971"],
        correctIndex: 2,
      ),
      Question(
        question: "In what year was Constantinople conquered by Mehmed II?",
        options: ["1299", "1453", "1492", "1517"],
        correctIndex: 1,
      ),
      Question(
        question: "Which ancient peace treaty is among the earliest surviving written treaties?",
        options: ["Treaty of Kadesh", "Treaty of Versailles", "Magna Carta", "Peace of Westphalia"],
        correctIndex: 0,
      ),
      Question(
        question: "Who sailed from Europe to the Americas in 1492?",
        options: ["Vasco da Gama", "Christopher Columbus", "Ferdinand Magellan", "James Cook"],
        correctIndex: 1,
      ),
    ],
    'Magazin': [
      Question(
        question: "In which city's Metropolitan Museum of Art is the annual Met Gala hosted?",
        options: ["London", "Paris", "New York", "Milan"],
        correctIndex: 2,
      ),
      Question(
        question: "Which popular online database catalogs cast, crew, and ratings for films and series?",
        options: ["Spotify", "IMDb", "Behance", "GitHub"],
        correctIndex: 1,
      ),
      Question(
        question: "Which annual European music contest began in Lugano in 1956?",
        options: ["Grammy", "Eurovision", "Sanremo", "BRIT Awards"],
        correctIndex: 1,
      ),
      Question(
        question: "Which prestigious music awards ceremony uses a gramophone trophy?",
        options: ["EMAs", "Grammy Awards", "Billboard", "Mercury Prize"],
        correctIndex: 1,
      ),
      Question(
        question: "Which fashion capital hosts Paris Fashion Week?",
        options: ["Rome", "Paris", "Madrid", "Vienna"],
        correctIndex: 1,
      ),
    ],
    'Müzik': [
      Question(
        question: "How many parallel lines make up a standard musical staff?",
        options: ["4", "5", "6", "7"],
        correctIndex: 1,
      ),
      Question(
        question: "How many strings does a standard acoustic guitar have?",
        options: ["4", "5", "6", "8"],
        correctIndex: 2,
      ),
      Question(
        question: "How many sharps or flats are in the C major scale?",
        options: ["0", "1", "2", "3"],
        correctIndex: 0,
      ),
      Question(
        question: "Which composer finished his Ninth Symphony while profoundly deaf?",
        options: ["Mozart", "Bach", "Beethoven", "Chopin"],
        correctIndex: 2,
      ),
      Question(
        question: "Which woodwind instrument uses a single reed and is iconic in jazz?",
        options: ["Flute", "Oboe", "Saxophone", "Violin"],
        correctIndex: 2,
      ),
    ],
  },
};
