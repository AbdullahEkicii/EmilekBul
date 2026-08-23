import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/duel_room_model.dart';
import '../constants/app_categories.dart';
import 'duel_service.dart';

class BotRoomService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'duel_rooms';
  static final Random _random = Random();

  /// Farklı ülkelerden, kültürlerden, oyun nicklerinden ve mizahi lakaplardan oluşan zengin havuz
  static const List<Map<String, String>> _botProfiles = [
    // 👤 Doğal & Gerçekçi İsimler (TR)
    {'name': 'Emre', 'lang': 'tr'},
    {'name': 'Merve', 'lang': 'tr'},
    {'name': 'Burak', 'lang': 'tr'},
    {'name': 'Selin', 'lang': 'tr'},
    {'name': 'Eren', 'lang': 'tr'},
    {'name': 'Defne', 'lang': 'tr'},
    {'name': 'Kaan', 'lang': 'tr'},
    {'name': 'Melis', 'lang': 'tr'},
    {'name': 'Alper', 'lang': 'tr'},
    {'name': 'Zeynep', 'lang': 'tr'},
    {'name': 'Buse', 'lang': 'tr'},
    {'name': 'Kerem', 'lang': 'tr'},
    {'name': 'Berk', 'lang': 'tr'},
    {'name': 'Ada', 'lang': 'tr'},
    {'name': 'Yusuf', 'lang': 'tr'},
    {'name': 'Cansu', 'lang': 'tr'},
    {'name': 'Deniz', 'lang': 'tr'},
    {'name': 'Barış', 'lang': 'tr'},
    {'name': 'Hazal', 'lang': 'tr'},
    {'name': 'Onur', 'lang': 'tr'},
    {'name': 'Elif', 'lang': 'tr'},
    {'name': 'Tolga', 'lang': 'tr'},
    {'name': 'Caner', 'lang': 'tr'},
    {'name': 'Gamze', 'lang': 'tr'},
    {'name': 'Mert', 'lang': 'tr'},
    {'name': 'Tuğçe', 'lang': 'tr'},
    {'name': 'Pelin', 'lang': 'tr'},
    {'name': 'Arda', 'lang': 'tr'},
    {'name': 'Serkan', 'lang': 'tr'},
    {'name': 'İrem', 'lang': 'tr'},
    {'name': 'Görkem', 'lang': 'tr'},
    {'name': 'Sinem', 'lang': 'tr'},
    {'name': 'Volkan', 'lang': 'tr'},
    {'name': 'Cemre', 'lang': 'tr'},

    // 🎭 Eğlenceli & Akılda Kalıcı Takma Adlar (TR)
    {'name': 'TestBükücü', 'lang': 'tr'},
    {'name': 'ProfDrCevap', 'lang': 'tr'},
    {'name': 'SallamasyonMaster', 'lang': 'tr'},
    {'name': 'BeyinYakan', 'lang': 'tr'},
    {'name': 'Bilirkişi', 'lang': 'tr'},
    {'name': 'GoogleDeğilim', 'lang': 'tr'},
    {'name': 'KahveDelisi', 'lang': 'tr'},
    {'name': 'AtomKarınca', 'lang': 'tr'},
    {'name': 'NöronReis', 'lang': 'tr'},
    {'name': 'KafaAçan', 'lang': 'tr'},
    {'name': 'BiBilenVar', 'lang': 'tr'},
    {'name': 'TekAtan', 'lang': 'tr'},
    {'name': 'SoruCanavarı', 'lang': 'tr'},
    {'name': 'CevapAnahtarı', 'lang': 'tr'},
    {'name': 'AkılKüpü', 'lang': 'tr'},
    {'name': 'SoruUstası', 'lang': 'tr'},
    {'name': 'BiSorupÇıkıcam', 'lang': 'tr'},
    {'name': 'BilgeBaykuş', 'lang': 'tr'},
    {'name': 'GeceKuşu', 'lang': 'tr'},
    {'name': 'PikselUsta', 'lang': 'tr'},

    // 🎮 Küresel / Gaming Nickleri (EN)
    {'name': 'QuizMaster', 'lang': 'en'},
    {'name': 'BrainStorm', 'lang': 'en'},
    {'name': 'NeonRider', 'lang': 'en'},
    {'name': 'SilentNinja', 'lang': 'en'},
    {'name': 'MindGamer', 'lang': 'en'},
    {'name': 'LuckyStrike', 'lang': 'en'},
    {'name': 'NightOwl', 'lang': 'en'},
    {'name': 'TriviaTitan', 'lang': 'en'},
    {'name': 'PixelHero', 'lang': 'en'},
    {'name': 'SpeedyThinker', 'lang': 'en'},
    {'name': 'BigBrain', 'lang': 'en'},
    {'name': 'StarGazer', 'lang': 'en'},
    {'name': 'CaptainTrivia', 'lang': 'en'},
    {'name': 'FactHunter', 'lang': 'en'},
    {'name': 'QuantumMind', 'lang': 'en'},

    // 🇬🇧 / 🇺🇸 Gerçekçi Global İsimler
    {'name': 'Alex', 'lang': 'en'},
    {'name': 'Jordan', 'lang': 'en'},
    {'name': 'Sarah', 'lang': 'en'},
    {'name': 'Oliver', 'lang': 'en'},
    {'name': 'Emily', 'lang': 'en'},
    {'name': 'Marcus', 'lang': 'en'},
    {'name': 'Charlotte', 'lang': 'en'},
    {'name': 'Liam', 'lang': 'en'},
    {'name': 'Hannah', 'lang': 'en'},
    {'name': 'Noah', 'lang': 'en'},
    {'name': 'Mason', 'lang': 'en'},
    {'name': 'Lucas', 'lang': 'en'},
    {'name': 'Chloe', 'lang': 'en'},
    {'name': 'Sophie', 'lang': 'en'},
    {'name': 'Leo', 'lang': 'en'},
    {'name': 'Ethan', 'lang': 'en'},
    {'name': 'Mia', 'lang': 'en'},
    {'name': 'James', 'lang': 'en'},
    {'name': 'Maya', 'lang': 'en'},
    {'name': 'Aria', 'lang': 'en'},

    // 🇩🇪 Almanya
    {'name': 'Lukas', 'lang': 'de'},
    {'name': 'Felix', 'lang': 'de'},
    {'name': 'Leon', 'lang': 'de'},
    {'name': 'Mia', 'lang': 'de'},
    {'name': 'Jonas', 'lang': 'de'},
    {'name': 'Maximilian', 'lang': 'de'},
    {'name': 'Hannah', 'lang': 'de'},
    {'name': 'Elias', 'lang': 'de'},

    // 🇪🇸 İspanya / Latin Amerika
    {'name': 'Mateo', 'lang': 'es'},
    {'name': 'Lucia', 'lang': 'es'},
    {'name': 'Carlos', 'lang': 'es'},
    {'name': 'Elena', 'lang': 'es'},
    {'name': 'Diego', 'lang': 'es'},
    {'name': 'Valentina', 'lang': 'es'},
    {'name': 'Javier', 'lang': 'es'},
    {'name': 'Sofia', 'lang': 'es'},

    // 🇫🇷 Fransa
    {'name': 'Antoine', 'lang': 'fr'},
    {'name': 'Chloe', 'lang': 'fr'},
    {'name': 'Julien', 'lang': 'fr'},
    {'name': 'Camille', 'lang': 'fr'},
    {'name': 'Gabriel', 'lang': 'fr'},
    {'name': 'Manon', 'lang': 'fr'},
    {'name': 'Louis', 'lang': 'fr'},
    {'name': 'Lea', 'lang': 'fr'},

    // 🇮🇹 İtalya
    {'name': 'Marco', 'lang': 'it'},
    {'name': 'Giulia', 'lang': 'it'},
    {'name': 'Matteo', 'lang': 'it'},
    {'name': 'Chiara', 'lang': 'it'},
    {'name': 'Leonardo', 'lang': 'it'},
    {'name': 'Francesca', 'lang': 'it'},
    {'name': 'Alessandro', 'lang': 'it'},

    // 🇵🇹 Portekiz / Brezilya
    {'name': 'Gabriel', 'lang': 'pt'},
    {'name': 'Beatriz', 'lang': 'pt'},
    {'name': 'Lucas', 'lang': 'pt'},
    {'name': 'Mariana', 'lang': 'pt'},
    {'name': 'Matheus', 'lang': 'pt'},
    {'name': 'Larissa', 'lang': 'pt'},
    {'name': 'Rafael', 'lang': 'pt'},

    // 🇳🇱 Hollanda
    {'name': 'Daan', 'lang': 'nl'},
    {'name': 'Emma', 'lang': 'nl'},
    {'name': 'Sem', 'lang': 'nl'},
    {'name': 'Sophie', 'lang': 'nl'},
    {'name': 'Milan', 'lang': 'nl'},
    {'name': 'Tess', 'lang': 'nl'},

    // 🇷🇺 Rusya
    {'name': 'Dmitry', 'lang': 'ru'},
    {'name': 'Anastasia', 'lang': 'ru'},
    {'name': 'Ivan', 'lang': 'ru'},
    {'name': 'Elena', 'lang': 'ru'},
    {'name': 'Mikhail', 'lang': 'ru'},
    {'name': 'Daria', 'lang': 'ru'},
    {'name': 'Alexander', 'lang': 'ru'},

    // 🇵🇱 Polonya
    {'name': 'Jan', 'lang': 'pl'},
    {'name': 'Zuzanna', 'lang': 'pl'},
    {'name': 'Antoni', 'lang': 'pl'},
    {'name': 'Julia', 'lang': 'pl'},
    {'name': 'Jakub', 'lang': 'pl'},
    {'name': 'Maja', 'lang': 'pl'},

    // 🇺🇦 Ukrayna
    {'name': 'Taras', 'lang': 'uk'},
    {'name': 'Oksana', 'lang': 'uk'},
    {'name': 'Andriy', 'lang': 'uk'},
    {'name': 'Yulia', 'lang': 'uk'},
    {'name': 'Bohdan', 'lang': 'uk'},
    {'name': 'Iryna', 'lang': 'uk'},

    // 🇷🇴 Romanya
    {'name': 'Andrei', 'lang': 'ro'},
    {'name': 'Maria', 'lang': 'ro'},
    {'name': 'Alexandru', 'lang': 'ro'},
    {'name': 'Stefan', 'lang': 'ro'},
    {'name': 'Ioana', 'lang': 'ro'},

    // 🇭🇺 Macaristan
    {'name': 'Bence', 'lang': 'hu'},
    {'name': 'Hanna', 'lang': 'hu'},
    {'name': 'Mate', 'lang': 'hu'},
    {'name': 'Anna', 'lang': 'hu'},
    {'name': 'Levente', 'lang': 'hu'},

    // 🇨🇿 Çek Cumhuriyeti
    {'name': 'Jakub', 'lang': 'cs'},
    {'name': 'Eliska', 'lang': 'cs'},
    {'name': 'Jan', 'lang': 'cs'},
    {'name': 'Tereza', 'lang': 'cs'},
    {'name': 'Tomas', 'lang': 'cs'},

    // 🇸🇪 İsveç
    {'name': 'William', 'lang': 'sv'},
    {'name': 'Alice', 'lang': 'sv'},
    {'name': 'Liam', 'lang': 'sv'},
    {'name': 'Elsa', 'lang': 'sv'},
    {'name': 'Noah', 'lang': 'sv'},

    // 🇩🇰 Danimarka
    {'name': 'William', 'lang': 'da'},
    {'name': 'Emma', 'lang': 'da'},
    {'name': 'Noah', 'lang': 'da'},
    {'name': 'Ida', 'lang': 'da'},
    {'name': 'Oliver', 'lang': 'da'},

    // 🇫🇮 Finlandiya
    {'name': 'Leo', 'lang': 'fi'},
    {'name': 'Aino', 'lang': 'fi'},
    {'name': 'Eino', 'lang': 'fi'},
    {'name': 'Olivia', 'lang': 'fi'},
    {'name': 'Oliver', 'lang': 'fi'},

    // 🇬🇷 Yunanistan
    {'name': 'Nikos', 'lang': 'el'},
    {'name': 'Maria', 'lang': 'el'},
    {'name': 'Giorgos', 'lang': 'el'},
    {'name': 'Eleni', 'lang': 'el'},
    {'name': 'Dimitris', 'lang': 'el'},

    // 🇮🇩 Endonezya
    {'name': 'Budi', 'lang': 'id'},
    {'name': 'Siti', 'lang': 'id'},
    {'name': 'Reza', 'lang': 'id'},
    {'name': 'Dewi', 'lang': 'id'},
    {'name': 'Dimas', 'lang': 'id'},

    // 🇻🇳 Vietnam
    {'name': 'Nam', 'lang': 'vi'},
    {'name': 'Linh', 'lang': 'vi'},
    {'name': 'Minh', 'lang': 'vi'},
    {'name': 'Trang', 'lang': 'vi'},
    {'name': 'Duc', 'lang': 'vi'},

    // 🇹🇭 Tayland
    {'name': 'Somchai', 'lang': 'th'},
    {'name': 'May', 'lang': 'th'},
    {'name': 'Kittisak', 'lang': 'th'},
    {'name': 'Fah', 'lang': 'th'},
    {'name': 'Ploi', 'lang': 'th'},

    // 🇮🇳 Hindistan
    {'name': 'Aarav', 'lang': 'hi'},
    {'name': 'Ananya', 'lang': 'hi'},
    {'name': 'Vihaan', 'lang': 'hi'},
    {'name': 'Diya', 'lang': 'hi'},
    {'name': 'Kabir', 'lang': 'hi'},

    // 🇸🇦 Arapça
    {'name': 'Omar', 'lang': 'ar'},
    {'name': 'Layla', 'lang': 'ar'},
    {'name': 'Karim', 'lang': 'ar'},
    {'name': 'Noor', 'lang': 'ar'},
    {'name': 'Zaid', 'lang': 'ar'},

    // 🇯🇵 Japonya
    {'name': 'Ren', 'lang': 'ja'},
    {'name': 'Yui', 'lang': 'ja'},
    {'name': 'Haruto', 'lang': 'ja'},
    {'name': 'Hina', 'lang': 'ja'},
    {'name': 'Minato', 'lang': 'ja'},

    // 🇰🇷 Kore
    {'name': 'Minjun', 'lang': 'ko'},
    {'name': 'Seoyeon', 'lang': 'ko'},
    {'name': 'Dohoon', 'lang': 'ko'},
    {'name': 'Jiwoo', 'lang': 'ko'},
    {'name': 'Hajun', 'lang': 'ko'},

    // 🇨🇳 Çin
    {'name': 'Wei', 'lang': 'zh'},
    {'name': 'Jing', 'lang': 'zh'},
    {'name': 'Hao', 'lang': 'zh'},
    {'name': 'Fang', 'lang': 'zh'},
    {'name': 'Lei', 'lang': 'zh'},
  ];

  static const List<String> _titles = [
    'yok',
    'Bilgi Avcısı',
    'Usta Yarışmacı',
    'Zeka Küpü',
    'Efsane',
    'Düellocu',
    'Şampiyon',
    'Hızlı Düşünür',
    'Quiz Ustası',
    'Yenilmez',
    'Bilgin',
    'Büyük Usta',
  ];

  static const List<int> _bets = [10, 25, 50, 100];
  static const List<int> _questionCounts = [5, 6, 7];
  static const List<String> _difficulties = ['Kolay', 'Orta', 'Zor'];

  /// Verilen UID'nin bir bota ait olup olmadığını kontrol eder
  static bool isBot(String? uid) {
    if (uid == null) return false;
    return uid.startsWith('bot_');
  }

  /// Rastgele Gerçekçi Bot Oyuncusu Üret (İstenen dile özel)
  static DuelPlayer generateRandomBotPlayer({String? preferredLang}) {
    List<Map<String, String>> pool = _botProfiles;
    if (preferredLang != null) {
      final langMatches = _botProfiles
          .where((p) => p['lang']?.toLowerCase() == preferredLang.toLowerCase())
          .toList();
      if (langMatches.isNotEmpty) {
        pool = langMatches;
      }
    }

    final profile = pool[_random.nextInt(pool.length)];
    final botId = 'bot_${_random.nextInt(900000) + 100000}';
    final avatarNum = _random.nextInt(20) + 1;
    final frame = _random.nextInt(6).toString(); // 0 ile 5
    final title = _titles[_random.nextInt(_titles.length)];
    final tokens = (_random.nextInt(40) + 10) * 100; // 1000 - 5000 Token

    return DuelPlayer(
      uid: botId,
      username: profile['name'] ?? 'Player',
      avatarIndex: avatarNum.toString(),
      equippedFrame: frame,
      equippedTitle: title,
      tokens: tokens,
      language: preferredLang ?? profile['lang'] ?? 'tr',
      isReady: true,
    );
  }

  /// Verilen dile uygun rastgele bot ismi döner
  static String getRandomBotName(String? lang) {
    List<Map<String, String>> pool = _botProfiles;
    if (lang != null) {
      final langMatches = _botProfiles
          .where((p) => p['lang']?.toLowerCase() == lang.toLowerCase())
          .toList();
      if (langMatches.isNotEmpty) {
        pool = langMatches;
      }
    }
    return pool[_random.nextInt(pool.length)]['name'] ?? 'Player';
  }

  /// Açık Bekleyen Bot Odalarını Kontrol Et ve Gerekirse Yeni Bot Odası Oluştur
  static Future<void> ensureMinimumBotRooms() async {
    try {
      final now = DateTime.now();

      // 1. Bekleyen odaları getir
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('status', isEqualTo: 'waiting')
          .get();

      int waitingCount = 0;
      final List<String> staleDocIds = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final guest = data['guest'];
        final createdAtRaw = data['createdAt'];

        DateTime? createdAt;
        if (createdAtRaw is Timestamp) {
          createdAt = createdAtRaw.toDate();
        }

        // 4 dakikadan eski bot odalarını temizle
        if (data['hostUid']?.toString().startsWith('bot_') == true &&
            guest == null &&
            createdAt != null &&
            now.difference(createdAt).inMinutes >= 4) {
          staleDocIds.add(doc.id);
        } else if (guest == null) {
          waitingCount++;
        }
      }

      // Bayat bot odalarını kapat
      for (final docId in staleDocIds) {
        await _firestore.collection(_collectionName).doc(docId).update({
          'status': 'closed',
          'lastActivity': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }

      // Eğer açık oda sayısı 3'ten azsa yeni bot odası aç
      if (waitingCount < 3) {
        await createBotRoom();
      }
    } catch (e) {
      debugPrint('ensureMinimumBotRooms error: $e');
    }
  }

  /// Yeni Bir Bot Odası Oluştur ve Firestore'a Kaydet
  static Future<String> createBotRoom({String? category}) async {
    final botPlayer = generateRandomBotPlayer();
    
    // Rastgele popüler kategori seç
    final allCats = [...AppCategories.categories, ...AppCategories.bonusPoolCategories];
    final selectedCat = category ?? allCats[_random.nextInt(allCats.length)].name;
    final selectedDiff = _difficulties[_random.nextInt(_difficulties.length)];
    final selectedCount = _questionCounts[_random.nextInt(_questionCounts.length)];
    final selectedBet = _bets[_random.nextInt(_bets.length)];

    final config = DuelConfig(
      category: selectedCat,
      difficulty: selectedDiff,
      questionCount: selectedCount,
      betTokens: selectedBet,
    );

    final roomCode = DuelService.generateRoomCode();
    final room = DuelRoom(
      roomCode: roomCode,
      hostUid: botPlayer.uid,
      host: botPlayer,
      guest: null,
      status: 'waiting',
      config: config,
      questions: const [],
      prizeTokens: DuelRoom.calculatePrize(selectedBet),
      createdAt: DateTime.now(),
    );

    await _firestore.collection(_collectionName).doc(roomCode).set(room.toMap());
    debugPrint('🤖 Yeni Bot Odası Açıldı: $roomCode [${botPlayer.username} - $selectedCat ($selectedDiff)]');
    return roomCode;
  }
}
