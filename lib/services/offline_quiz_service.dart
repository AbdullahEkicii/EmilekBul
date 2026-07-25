import '../models/question.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineQuizService {
  static final Map<String, List<Question>> _offlineQuestions = {
    'tr': [
      // Test 1 (Genel Kültür, Coğrafya)
      Question(question: "Dünyanın en yüksek dağı hangisidir?", options: ["K2", "Everest", "Kilimanjaro", "Elbruz"], correctIndex: 1),
      Question(question: "Türkiye'nin başkenti neresidir?", options: ["İstanbul", "Ankara", "İzmir", "Bursa"], correctIndex: 1),
      Question(question: "Güneş sistemindeki en büyük gezegen hangisidir?", options: ["Satürn", "Uranüs", "Neptün", "Jüpiter"], correctIndex: 3),
      Question(question: "Hangi element 'O' simgesiyle gösterilir?", options: ["Altın", "Oksijen", "Osmiyum", "Karbon"], correctIndex: 1),
      Question(question: "Suyun kimyasal formülü nedir?", options: ["CO2", "H2O", "O2", "NaCl"], correctIndex: 1),
      // Test 2 (Tarih, Sanat, Bilim)
      Question(question: "İstanbul hangi yıl fethedilmiştir?", options: ["1071", "1299", "1453", "1923"], correctIndex: 2),
      Question(question: "Mona Lisa tablosu nerede sergilenmektedir?", options: ["Louvre", "British Museum", "Prado", "Ermitaj"], correctIndex: 0),
      Question(question: "Yerçekimi kanununu bulan ünlü bilim insanı kimdir?", options: ["Albert Einstein", "Isaac Newton", "Galileo Galilei", "Nikola Tesla"], correctIndex: 1),
      Question(question: "Hangi gezegen 'Kızıl Gezegen' olarak bilinir?", options: ["Venüs", "Mars", "Jüpiter", "Satürn"], correctIndex: 1),
      Question(question: "Amerika kıtasını kim keşfetmiştir?", options: ["Vasco da Gama", "Kristof Kolomb", "Macellan", "Amerigo Vespucci"], correctIndex: 1),
      // Test 3 (Spor, Edebiyat, Genel)
      Question(question: "Futbolda bir takımın sahada kaç oyuncusu bulunur?", options: ["9", "10", "11", "12"], correctIndex: 2),
      Question(question: "İstiklal Marşı'mızın bestecisi kimdir?", options: ["Mehmet Akif Ersoy", "Osman Zeki Üngör", "Cemal Reşit Rey", "Adnan Saygun"], correctIndex: 1),
      Question(question: "Işık yılı neyin ölçü birimidir?", options: ["Zaman", "Mesafe", "Hız", "Ağırlık"], correctIndex: 1),
      Question(question: "İnsan vücudundaki en büyük organ hangisidir?", options: ["Kalp", "Beyin", "Karaciğer", "Deri"], correctIndex: 3),
      Question(question: "Dünyanın en uzun nehri hangisidir?", options: ["Amazon", "Nil", "Yangtze", "Mississippi"], correctIndex: 1),
    ],
    'en': [
      // Test 1
      Question(question: "What is the highest mountain in the world?", options: ["K2", "Everest", "Kilimanjaro", "Elbrus"], correctIndex: 1),
      Question(question: "What is the capital of France?", options: ["London", "Berlin", "Paris", "Rome"], correctIndex: 2),
      Question(question: "What is the largest planet in the solar system?", options: ["Saturn", "Uranus", "Neptune", "Jupiter"], correctIndex: 3),
      Question(question: "Which element is represented by the symbol 'O'?", options: ["Gold", "Oxygen", "Osmium", "Carbon"], correctIndex: 1),
      Question(question: "What is the chemical formula for water?", options: ["CO2", "H2O", "O2", "NaCl"], correctIndex: 1),
      // Test 2
      Question(question: "In what year did the Titanic sink?", options: ["1910", "1912", "1914", "1920"], correctIndex: 1),
      Question(question: "Where is the Mona Lisa painting exhibited?", options: ["Louvre", "British Museum", "Prado", "Hermitage"], correctIndex: 0),
      Question(question: "Who discovered the law of gravity?", options: ["Albert Einstein", "Isaac Newton", "Galileo Galilei", "Nikola Tesla"], correctIndex: 1),
      Question(question: "Which planet is known as the 'Red Planet'?", options: ["Venus", "Mars", "Jupiter", "Saturn"], correctIndex: 1),
      Question(question: "Who discovered the Americas?", options: ["Vasco da Gama", "Christopher Columbus", "Magellan", "Amerigo Vespucci"], correctIndex: 1),
      // Test 3
      Question(question: "How many players are on a soccer team on the field?", options: ["9", "10", "11", "12"], correctIndex: 2),
      Question(question: "Who wrote 'Romeo and Juliet'?", options: ["Charles Dickens", "William Shakespeare", "Jane Austen", "Mark Twain"], correctIndex: 1),
      Question(question: "What is a light-year a unit of?", options: ["Time", "Distance", "Speed", "Weight"], correctIndex: 1),
      Question(question: "What is the largest organ in the human body?", options: ["Heart", "Brain", "Liver", "Skin"], correctIndex: 3),
      Question(question: "What is the longest river in the world?", options: ["Amazon", "Nile", "Yangtze", "Mississippi"], correctIndex: 1),
    ],
    'fr': [
      // Test 1
      Question(question: "Quelle est la plus haute montagne du monde ?", options: ["K2", "Everest", "Kilimandjaro", "Elbrouz"], correctIndex: 1),
      Question(question: "Quelle est la capitale de l'Espagne ?", options: ["Barcelone", "Séville", "Madrid", "Valence"], correctIndex: 2),
      Question(question: "Quelle est la plus grande planète du système solaire ?", options: ["Saturne", "Uranus", "Neptune", "Jupiter"], correctIndex: 3),
      Question(question: "Quel élément est représenté par le symbole 'O' ?", options: ["Or", "Oxygène", "Osmium", "Carbone"], correctIndex: 1),
      Question(question: "Quelle est la formule chimique de l'eau ?", options: ["CO2", "H2O", "O2", "NaCl"], correctIndex: 1),
      // Test 2
      Question(question: "En quelle année le Titanic a-t-il coulé ?", options: ["1910", "1912", "1914", "1920"], correctIndex: 1),
      Question(question: "Où est exposée La Joconde ?", options: ["Louvre", "British Museum", "Prado", "Ermitage"], correctIndex: 0),
      Question(question: "Qui a découvert la loi de la gravité ?", options: ["Albert Einstein", "Isaac Newton", "Galileo Galilei", "Nikola Tesla"], correctIndex: 1),
      Question(question: "Quelle planète est connue sous le nom de 'Planète rouge' ?", options: ["Vénus", "Mars", "Jupiter", "Saturne"], correctIndex: 1),
      Question(question: "Qui a découvert les Amériques ?", options: ["Vasco de Gama", "Christophe Colomb", "Magellan", "Amerigo Vespucci"], correctIndex: 1),
      // Test 3
      Question(question: "Combien de joueurs composent une équipe de football sur le terrain ?", options: ["9", "10", "11", "12"], correctIndex: 2),
      Question(question: "Qui a écrit 'Les Misérables' ?", options: ["Molière", "Victor Hugo", "Baudelaire", "Voltaire"], correctIndex: 1),
      Question(question: "De quoi l'année-lumière est-elle l'unité de mesure ?", options: ["Temps", "Distance", "Vitesse", "Poids"], correctIndex: 1),
      Question(question: "Quel est le plus grand organe du corps humain ?", options: ["Cœur", "Cerveau", "Foie", "Peau"], correctIndex: 3),
      Question(question: "Quel est le plus long fleuve du monde ?", options: ["Amazone", "Nil", "Yangtsé", "Mississippi"], correctIndex: 1),
    ],
    'es': [
      // Test 1
      Question(question: "¿Cuál es la montaña más alta del mundo?", options: ["K2", "Everest", "Kilimanjaro", "Elbrús"], correctIndex: 1),
      Question(question: "¿Cuál es la capital de Italia?", options: ["Venecia", "Milán", "Roma", "Florencia"], correctIndex: 2),
      Question(question: "¿Cuál es el planeta más grande del sistema solar?", options: ["Saturno", "Urano", "Neptuno", "Júpiter"], correctIndex: 3),
      Question(question: "¿Qué elemento está representado por el símbolo 'O'?", options: ["Oro", "Oxígeno", "Osmio", "Carbono"], correctIndex: 1),
      Question(question: "¿Cuál es la fórmula química del agua?", options: ["CO2", "H2O", "O2", "NaCl"], correctIndex: 1),
      // Test 2
      Question(question: "¿En qué año se hundió el Titanic?", options: ["1910", "1912", "1914", "1920"], correctIndex: 1),
      Question(question: "¿Dónde se exhibe la Mona Lisa?", options: ["Louvre", "British Museum", "Prado", "Ermitage"], correctIndex: 0),
      Question(question: "¿Quién descubrió la ley de la gravedad?", options: ["Albert Einstein", "Isaac Newton", "Galileo Galilei", "Nikola Tesla"], correctIndex: 1),
      Question(question: "¿Qué planeta se conoce como el 'Planeta Rojo'?", options: ["Venus", "Marte", "Júpiter", "Saturno"], correctIndex: 1),
      Question(question: "¿Quién descubrió las Américas?", options: ["Vasco da Gama", "Cristóbal Colón", "Magallanes", "Américo Vespucio"], correctIndex: 1),
      // Test 3
      Question(question: "¿Cuántos jugadores tiene un equipo de fútbol en el campo?", options: ["9", "10", "11", "12"], correctIndex: 2),
      Question(question: "¿Quién escribió 'Don Quijote de la Mancha'?", options: ["García Márquez", "Miguel de Cervantes", "Borges", "Neruda"], correctIndex: 1),
      Question(question: "¿De qué es unidad de medida el año luz?", options: ["Tiempo", "Distancia", "Velocidad", "Peso"], correctIndex: 1),
      Question(question: "¿Cuál es el órgano más grande del cuerpo humano?", options: ["Corazón", "Cerebro", "Hígado", "Piel"], correctIndex: 3),
      Question(question: "¿Cuál es el río más largo del mundo?", options: ["Amazonas", "Nilo", "Yangtsé", "Misisipi"], correctIndex: 1),
    ],
    'ru': [
      // Test 1
      Question(question: "Какая самая высокая гора в мире?", options: ["К2", "Эверест", "Килиманджаро", "Эльбрус"], correctIndex: 1),
      Question(question: "Какой город является столицей Испании?", options: ["Барселона", "Севилья", "Мадрид", "Валенсия"], correctIndex: 2),
      Question(question: "Какая самая большая планета в солнечной системе?", options: ["Сатурн", "Уран", "Нептун", "Юпитер"], correctIndex: 3),
      Question(question: "Какой химический элемент обозначается символом 'O'?", options: ["Золото", "Кислород", "Осмий", "Углерод"], correctIndex: 1),
      Question(question: "Какова химическая формула воды?", options: ["CO2", "H2O", "O2", "NaCl"], correctIndex: 1),
      // Test 2
      Question(question: "В каком году затонул Титаник?", options: ["1910", "1912", "1914", "1920"], correctIndex: 1),
      Question(question: "Где находится картина 'Мона Лиза'?", options: ["Лувр", "Британский музей", "Прадо", "Эрмитаж"], correctIndex: 0),
      Question(question: "Кто открыл закон всемирного тяготения?", options: ["Альберт Эйнштейн", "Исаак Ньютон", "Галилео Галилей", "Никола Тесла"], correctIndex: 1),
      Question(question: "Какую планету называют 'Красной планетой'?", options: ["Венера", "Марс", "Юпитер", "Сатурн"], correctIndex: 1),
      Question(question: "Кто открыл Америку?", options: ["Васко да Гама", "Христофор Колумб", "Магеллан", "Америго Веспуччи"], correctIndex: 1),
      // Test 3
      Question(question: "Сколько игроков в футбольной команде на поле?", options: ["9", "10", "11", "12"], correctIndex: 2),
      Question(question: "Кто написал 'Война и мир'?", options: ["Достоевский", "Лев Толстой", "Чехов", "Пушкин"], correctIndex: 1),
      Question(question: "Единицей измерения чего является световой год?", options: ["Время", "Расстояние", "Скорость", "Вес"], correctIndex: 1),
      Question(question: "Какой самый большой орган в организме человека?", options: ["Сердце", "Мозг", "Печень", "Кожа"], correctIndex: 3),
      Question(question: "Какая река самая длинная в мире?", options: ["Амазонка", "Нил", "Янцзы", "Миссисипи"], correctIndex: 1),
    ],
    'ar': [
      // Test 1
      Question(question: "ما هو أعلى جبل في العالم؟", options: ["كي 2", "إيفرست", "كليمنجارو", "إلبروس"], correctIndex: 1),
      Question(question: "ما هي عاصمة تركيا؟", options: ["إسطنبول", "أنقرة", "إزمير", "بورصة"], correctIndex: 1),
      Question(question: "ما هو أكبر كوكب في النظام الشمسي؟", options: ["زحل", "أورانوس", "نبتون", "المشتري"], correctIndex: 3),
      Question(question: "ما هو العنصر الذي يمثله الرمز 'O'؟", options: ["الذهب", "الأكسجين", "الأوزميوم", "الكربون"], correctIndex: 1),
      Question(question: "ما هي الصيغة الكيميائية للماء؟", options: ["CO2", "H2O", "O2", "NaCl"], correctIndex: 1),
      // Test 2
      Question(question: "في أي عام غرفت سفينة تيتانيك؟", options: ["1910", "1912", "1914", "1920"], correctIndex: 1),
      Question(question: "أين تعرض لوحة الموناليزا؟", options: ["متحف اللوفر", "المتحف البريطاني", "متحف برادو", "الإرميتاج"], correctIndex: 0),
      Question(question: "من اكتشف قانون الجاذبية؟", options: ["ألبرت أينشتاين", "إسحاق نيوتن", "جاليليو جاليلي", "نيكولا تسلا"], correctIndex: 1),
      Question(question: "أي كوكب يُعرف باسم 'الكوكب الأحمر'؟", options: ["الزهرة", "المريخ", "المشتري", "زحل"], correctIndex: 1),
      Question(question: "من اكتشف الأمريكتين؟", options: ["فاسكو دا غاما", "كريستوفر كولومبوس", "ماجلان", "أمريكو فسبوتشي"], correctIndex: 1),
      // Test 3
      Question(question: "كم عدد اللاعبين في فريق كرة القدم على أرض الملعب؟", options: ["9", "10", "11", "12"], correctIndex: 2),
      Question(question: "من هو ملحن النشيد الوطني التركي؟", options: ["محمد عاكف أرصوي", "عثمان زكي أونغور", "جمال رشيد ري", "عدنان سايغون"], correctIndex: 1),
      Question(question: "ما الذي تقيسه السنة الضوئية؟", options: ["الوقت", "المسافة", "السرعة", "الوزن"], correctIndex: 1),
      Question(question: "ما هو أكبر عضو في جسم الإنسان؟", options: ["القلب", "الدماغ", "الكبد", "الجلد"], correctIndex: 3),
      Question(question: "ما هو أطول نهر في العالم؟", options: ["الأمازون", "النيل", "يانغتسي", "الميسيسيبي"], correctIndex: 1),
    ],
  };

  /// Get a specific subset of questions based on how many tests the user has taken
  static Future<List<Question>> getQuestions({required String languageCode, int count = 5}) async {
    final lang = languageCode.split('_').first.toLowerCase();
    
    // We only have tr, en, fr, es, ru, ar. Fallback to en.
    final availableLangs = ['tr', 'en', 'fr', 'es', 'ru', 'ar'];
    final selectedLang = availableLangs.contains(lang) ? lang : 'en';
    
    final baseQuestions = _offlineQuestions[selectedLang]!;
    
    // Find out which test this is (0, 1, or 2)
    final prefs = await SharedPreferences.getInstance();
    int offlineTaken = prefs.getInt('offline_tests_taken') ?? 0;
    
    // Safety check, in case it's higher than 2, wrap around
    int testIndex = offlineTaken % 3;
    
    int startIndex = testIndex * count;
    if (startIndex + count > baseQuestions.length) {
       startIndex = 0; // Fallback if count is weird
    }
    
    return baseQuestions.sublist(startIndex, startIndex + count);
  }
}
