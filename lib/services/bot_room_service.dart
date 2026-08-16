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
    // 🎭 Esprili & Mizahi Nickler (TR)
    {'name': 'TestBükücü', 'lang': 'tr'},
    {'name': 'ProfDrCevap', 'lang': 'tr'},
    {'name': 'SallamasyonMaster', 'lang': 'tr'},
    {'name': 'BeyinYakan', 'lang': 'tr'},
    {'name': 'Bilirkişi', 'lang': 'tr'},
    {'name': 'GoogleDeğilim', 'lang': 'tr'},
    {'name': 'SonDakikaGolü', 'lang': 'tr'},
    {'name': 'KahveDelisi', 'lang': 'tr'},
    {'name': 'UykusuzKütüphane', 'lang': 'tr'},
    {'name': 'AtomKarınca', 'lang': 'tr'},
    {'name': 'ÇayİçenFilozof', 'lang': 'tr'},
    {'name': 'NöronReis', 'lang': 'tr'},
    {'name': 'KafaAçan', 'lang': 'tr'},
    {'name': 'EinsteinınTorunu', 'lang': 'tr'},
    {'name': 'BiBilenVar', 'lang': 'tr'},
    {'name': 'KlavyeninEfendisi', 'lang': 'tr'},
    {'name': 'TekAtan', 'lang': 'tr'},
    {'name': 'MatrixtekiAdam', 'lang': 'tr'},
    {'name': 'SoruCanavarı', 'lang': 'tr'},
    {'name': 'CevapAnahtarı', 'lang': 'tr'},
    {'name': 'KafamdaKırkTilki', 'lang': 'tr'},
    {'name': 'AkılKüpü06', 'lang': 'tr'},
    {'name': 'SoruUstası', 'lang': 'tr'},
    {'name': 'BiSorupÇıkıcam', 'lang': 'tr'},
    {'name': 'TaktikYokBamBam', 'lang': 'tr'},
    {'name': 'GözüKapalıÇözen', 'lang': 'tr'},
    {'name': 'HızlıVeÖfkeli', 'lang': 'tr'},
    {'name': 'GönüllerinBirincisi', 'lang': 'tr'},

    // 👤 Doğal & Gerçekçi Kullanıcı Adları (TR)
    {'name': 'baris_dmr', 'lang': 'tr'},
    {'name': 'serkan.oz', 'lang': 'tr'},
    {'name': 'irem_kaya98', 'lang': 'tr'},
    {'name': 'volkan_yilmaz', 'lang': 'tr'},
    {'name': 'tugce_ak', 'lang': 'tr'},
    {'name': 'onurcan', 'lang': 'tr'},
    {'name': 'hazal_s', 'lang': 'tr'},
    {'name': 'berke_k', 'lang': 'tr'},
    {'name': 'merveylmz', 'lang': 'tr'},
    {'name': 'batuhan_35', 'lang': 'tr'},
    {'name': 'gamze.t', 'lang': 'tr'},
    {'name': 'arda_bjk', 'lang': 'tr'},
    {'name': 'melike_arslan', 'lang': 'tr'},
    {'name': 'yigit_efe', 'lang': 'tr'},
    {'name': 'cansu_polat', 'lang': 'tr'},
    {'name': 'koray_ay', 'lang': 'tr'},
    {'name': 'ozge_demir', 'lang': 'tr'},
    {'name': 'tolga_1907', 'lang': 'tr'},
    {'name': 'asli_nur', 'lang': 'tr'},
    {'name': 'fatih_tr', 'lang': 'tr'},
    {'name': 'gorkem_gs', 'lang': 'tr'},
    {'name': 'sinem_k', 'lang': 'tr'},
    {'name': 'emre_92', 'lang': 'tr'},
    {'name': 'pinar_aydin', 'lang': 'tr'},
    {'name': 'cemre_su', 'lang': 'tr'},
    {'name': 'burakhan', 'lang': 'tr'},
    {'name': 'sedef_oz', 'lang': 'tr'},
    {'name': 'kaan_07', 'lang': 'tr'},
    {'name': 'alperen_ts', 'lang': 'tr'},
    {'name': 'deniz.arslan', 'lang': 'tr'},
    {'name': 'alican_95', 'lang': 'tr'},
    {'name': 'caglar_fb', 'lang': 'tr'},

    // 🎮 Mizahi & Havalı Global / Oyun Nickleri (EN)
    {'name': 'BrainySmurf', 'lang': 'en'},
    {'name': 'QuizLord', 'lang': 'en'},
    {'name': 'CoffeeAndCode', 'lang': 'en'},
    {'name': 'SilentNinja', 'lang': 'en'},
    {'name': 'MindOverMatter', 'lang': 'en'},
    {'name': 'LuckyStrike', 'lang': 'en'},
    {'name': 'NoGoogleHere', 'lang': 'en'},
    {'name': 'NightOwl99', 'lang': 'en'},
    {'name': 'QuizWhisperer', 'lang': 'en'},
    {'name': 'SmartPanda', 'lang': 'en'},
    {'name': 'TriviaTitan', 'lang': 'en'},
    {'name': 'RandomGuesser', 'lang': 'en'},
    {'name': 'PixelMaster', 'lang': 'en'},
    {'name': 'SpeedyGonzalez', 'lang': 'en'},
    {'name': 'BigBrainEnergy', 'lang': 'en'},
    {'name': 'LateNightScholar', 'lang': 'en'},
    {'name': 'ZenMaster_', 'lang': 'en'},
    {'name': 'CaptainCurious', 'lang': 'en'},
    {'name': 'ThinkingCap', 'lang': 'en'},
    {'name': 'FactChecker', 'lang': 'en'},
    {'name': 'CtrlAltDefeat', 'lang': 'en'},
    {'name': 'TheQuizWizard', 'lang': 'en'},
    {'name': 'QuantumThinker', 'lang': 'en'},

    // 🇬🇧 / 🇺🇸 Gerçekçi İngilizce İsimler
    {'name': 'jordan_b', 'lang': 'en'},
    {'name': 'sarah.jenkins', 'lang': 'en'},
    {'name': 'oliver_twist99', 'lang': 'en'},
    {'name': 'emily_rose', 'lang': 'en'},
    {'name': 'marcus_v', 'lang': 'en'},
    {'name': 'charlotte.w', 'lang': 'en'},
    {'name': 'liam_miller', 'lang': 'en'},
    {'name': 'hannah_baker', 'lang': 'en'},
    {'name': 'noah_carter', 'lang': 'en'},
    {'name': 'mason_lee', 'lang': 'en'},
    {'name': 'grace_hopper', 'lang': 'en'},
    {'name': 'ethan_hunt', 'lang': 'en'},

    // 🇩🇪 Almanya
    {'name': 'lukas.weber', 'lang': 'de'},
    {'name': 'max_muster', 'lang': 'de'},
    {'name': 'hannah_schmidt', 'lang': 'de'},
    {'name': 'felix_bauer', 'lang': 'de'},
    {'name': 'leon_berlin', 'lang': 'de'},
    {'name': 'mia_wagner', 'lang': 'de'},
    {'name': 'jonas_keller', 'lang': 'de'},

    // 🇪🇸 İspanya / Latin Amerika
    {'name': 'mateo_valencia', 'lang': 'es'},
    {'name': 'lucia_rodriguez', 'lang': 'es'},
    {'name': 'carlos_santana', 'lang': 'es'},
    {'name': 'elena_madrid', 'lang': 'es'},
    {'name': 'diego_armando', 'lang': 'es'},
    {'name': 'valentina_sol', 'lang': 'es'},
    {'name': 'javier_bcn', 'lang': 'es'},

    // 🇫🇷 Fransa
    {'name': 'antoine_paris', 'lang': 'fr'},
    {'name': 'chloe_dupont', 'lang': 'fr'},
    {'name': 'julien_moreau', 'lang': 'fr'},
    {'name': 'camille_lyon', 'lang': 'fr'},
    {'name': 'lucas_dubois', 'lang': 'fr'},
    {'name': 'amelie_poulain', 'lang': 'fr'},

    // 🇮🇹 İtalya
    {'name': 'marco_roma', 'lang': 'it'},
    {'name': 'giulia_rossi', 'lang': 'it'},
    {'name': 'matteo_milan', 'lang': 'it'},
    {'name': 'chiara_ferrari', 'lang': 'it'},
    {'name': 'leonardo_da', 'lang': 'it'},

    // 🇯🇵 Japonya / Asya
    {'name': 'kenji_sato', 'lang': 'ja'},
    {'name': 'yuki_t', 'lang': 'ja'},
    {'name': 'haruto_tokyo', 'lang': 'ja'},
    {'name': 'sakura_m', 'lang': 'ja'},

    // 🇷🇺 Rusya
    {'name': 'dmitry_v', 'lang': 'ru'},
    {'name': 'anastasia_k', 'lang': 'ru'},
    {'name': 'ivan_spb', 'lang': 'ru'},
    {'name': 'elena_volkova', 'lang': 'ru'},
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

  /// Rastgele Gerçekçi Bot Oyuncusu Üret
  static DuelPlayer generateRandomBotPlayer({String? preferredLang}) {
    final profile = _botProfiles[_random.nextInt(_botProfiles.length)];
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
