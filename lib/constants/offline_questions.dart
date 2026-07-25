import '../models/question.dart';

class OfflineQuestions {
  static final List<Question> fallbackQuestions = [
    // Genel Kültür
    Question(
      question: "Türkiye Cumhuriyeti'nin kurucusu ve ilk Cumhurbaşkanı kimdir?",
      options: [
        "Mustafa Kemal Atatürk",
        "İsmet İnönü",
        "Celal Bayar",
        "Adnan Menderes"
      ],
      correctIndex: 0,
    ),
    Question(
      question: "Dünya'nın uydusu aşağıdakilerden hangisidir?",
      options: ["Güneş", "Mars", "Ay", "Jüpiter"],
      correctIndex: 2,
    ),
    Question(
      question: "Suyun kimyasal formülü nedir?",
      options: ["H2O", "CO2", "O2", "NaCl"],
      correctIndex: 0,
    ),
    // Tarih
    Question(
      question: "İstanbul hangi yıl fethedilmiştir?",
      options: ["1071", "1299", "1453", "1923"],
      correctIndex: 2,
    ),
    Question(
      question: "Cumhuriyet hangi yıl ilan edilmiştir?",
      options: ["1919", "1920", "1923", "1938"],
      correctIndex: 2,
    ),
    // Coğrafya
    Question(
      question: "Türkiye'nin başkenti neresidir?",
      options: ["İstanbul", "Ankara", "İzmir", "Bursa"],
      correctIndex: 1,
    ),
    Question(
      question: "Yüzölçümü en büyük olan kıta hangisidir?",
      options: ["Afrika", "Avrupa", "Asya", "Amerika"],
      correctIndex: 2,
    ),
    Question(
      question: "Dünya'nın en derin noktası olan Mariana Çukuru hangi okyanustadır?",
      options: ["Hint Okyanusu", "Atlas Okyanusu", "Büyük Okyanus (Pasifik)", "Kuzey Buz Denizi"],
      correctIndex: 2,
    ),
    // Bilim
    Question(
      question: "Yerçekimi kanununu bulan ünlü bilim insanı kimdir?",
      options: ["Albert Einstein", "Isaac Newton", "Galileo Galilei", "Nikola Tesla"],
      correctIndex: 1,
    ),
    Question(
      question: "Güneş Sistemi'ndeki en büyük gezegen hangisidir?",
      options: ["Dünya", "Satürn", "Neptün", "Jüpiter"],
      correctIndex: 3,
    ),
    // Yemek Kültürü
    Question(
      question: "Mantı yemeği hangi ilimizle özdeşleşmiştir?",
      options: ["Kayseri", "Adana", "Gaziantep", "Trabzon"],
      correctIndex: 0,
    ),
    Question(
      question: "Geleneksel Türk tatlısı baklavanın anavatanı kabul edilen şehrimiz hangisidir?",
      options: ["Şanlıurfa", "Gaziantep", "Kahramanmaraş", "Hatay"],
      correctIndex: 1,
    ),
    // Futbol
    Question(
      question: "Futbolda bir takımın sahada kaç oyuncusu bulunur?",
      options: ["9", "10", "11", "12"],
      correctIndex: 2,
    ),
    Question(
      question: "2022 FIFA Dünya Kupası'nı hangi ülke kazanmıştır?",
      options: ["Fransa", "Brezilya", "Hırvatistan", "Arjantin"],
      correctIndex: 3,
    ),
    // Dini
    Question(
      question: "İslam dininin kutsal kitabı hangisidir?",
      options: ["İncil", "Tevrat", "Kur'an-ı Kerim", "Zebur"],
      correctIndex: 2,
    ),
    // Müzik
    Question(
      question: "İstiklal Marşı'mızın bestecisi kimdir?",
      options: ["Mehmet Akif Ersoy", "Osman Zeki Üngör", "Cemal Reşit Rey", "Adnan Saygun"],
      correctIndex: 1,
    ),
  ];

  static List<Question> getFallbackQuestionsForCategory(String category, {int count = 5}) {
    // Kategoriye göre filtrele
    List<Question> filtered = fallbackQuestions.where((q) {
      if (category == 'Genel Kültür') return true;
      if (category == 'Tarih' && (q.question.contains('yıl') || q.question.contains('fethedilmiştir'))) return true;
      if (category == 'Coğrafya' && (q.question.contains('başkent') || q.question.contains('kıta') || q.question.contains('Okyanus'))) return true;
      if (category == 'Bilim' && (q.question.contains('bilim') || q.question.contains('Yerçekimi') || q.question.contains('gezegen'))) return true;
      if (category == 'Yemek Kültürü' && (q.question.contains('tatlısı') || q.question.contains('Mantı') || q.question.contains('baklava'))) return true;
      if (category == 'Futbol' && (q.question.contains('Futbol') || q.question.contains('Kupası'))) return true;
      if (category == 'Dini' && q.question.contains('İslam')) return true;
      if (category == 'Müzik' && (q.question.contains('Marşı') || q.question.contains('bestecisi'))) return true;
      return false;
    }).toList();

    // Eğer filtreleme yetersizse veya boşsa genel havuzdan tamamla
    if (filtered.length < count) {
      filtered = List.from(filtered);
      for (var q in fallbackQuestions) {
        if (!filtered.contains(q)) {
          filtered.add(q);
        }
        if (filtered.length >= count) break;
      }
    }

    filtered.shuffle();
    return filtered.take(count).toList();
  }
}
