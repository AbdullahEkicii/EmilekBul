import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/duel_room_model.dart';
import '../models/question.dart';
import '../models/category_model.dart';
import '../constants/app_categories.dart';
import '../constants/app_constants.dart';
import '../services/duel_service.dart';
import '../services/user_service.dart';
import '../services/token_service.dart';
import '../services/question_pool_service.dart';
import '../services/bot_room_service.dart';
import '../services/friend_service.dart';
import '../services/analytics_service.dart';
import '../models/friend_model.dart';
import '../utils/app_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/token_widget.dart';
import '../widgets/my_native_ad.dart';
import 'live_duel_quiz_screen.dart';
import 'loading_screen.dart';

class DuelRoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const DuelRoomScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<DuelRoomScreen> createState() => _DuelRoomScreenState();
}

class _DuelRoomScreenState extends State<DuelRoomScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late StreamSubscription<DuelRoom?> _roomSubscription;
  Timer? _heartbeatTimer;
  Timer? _botChatTimer;
  Timer? _botNudgeTimer;
  Timer? _botApplicantTimer;
  StreamSubscription<List<DuelChatMessage>>? _botChatReactionSub;
  final Set<String> _botHandledMessageIds = {};
  bool _botAutomationTriggered = false;
  bool _guestBotFlowTriggered = false;
  bool _botStartTriggered = false;
  DuelRoom? _currentRoom;
  bool _isStarting = false;
  bool _hasNavigatedToQuiz = false;
  int _userTokens = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _chatTextController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadLocalTokens();
    _listenToRoom();

    // 15 saniyede bir odaya canlılık sinyali gönder
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      DuelService.pingRoom(widget.roomCode);
    });

    // Eğer kullanıcı oda sahibiyse ve oda boş kalırsa 10 sn sonra botlar katılma isteği atsın
    if (widget.isHost) {
      _startBotApplicantTimer();
    }
  }

  void _startBotApplicantTimer() {
    _botApplicantTimer?.cancel();
    _botApplicantTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || !widget.isHost || _hasNavigatedToQuiz || _isStarting) {
        return;
      }
      final room = _currentRoom;
      if (room == null ||
          room.guest != null ||
          room.pendingGuest != null ||
          room.status != 'waiting') {
        return;
      }

      // Özel yüksek bahisli odalara (100 Token üstü) botlar KESİNLİKLE katılmaz
      if (DuelRoom.isSpecialHighBet(room.config.betTokens)) {
        return;
      }

      // Kullanıcının boş odasına her 10 sn'de bir gerçekçi bot katılma isteği atsın
      final bot = BotRoomService.generateRandomBotPlayer(
        preferredLang: context.locale.languageCode,
      );
      await DuelService.requestJoinRoom(
        roomCode: widget.roomCode,
        guestPlayer: bot,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _botChatTimer?.cancel();
    _botNudgeTimer?.cancel();
    _botApplicantTimer?.cancel();
    _botChatReactionSub?.cancel();
    _roomSubscription.cancel();
    _pulseController.dispose();
    _chatTextController.dispose();
    _chatScrollController.dispose();

    // Eğer quiz'e geçmeden oda kapandıysa veya sayfadan çıkıldıysa odadan güvenle ayrıl
    if (!_hasNavigatedToQuiz && _currentRoom != null) {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      DuelService.leaveRoom(widget.roomCode, isHost: widget.isHost, uid: myUid);
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      if (!_hasNavigatedToQuiz && _currentRoom != null) {
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        DuelService.leaveRoom(widget.roomCode,
            isHost: widget.isHost, uid: myUid);
      }
    }
  }

  Future<void> _loadLocalTokens() async {
    final tokens = await TokenService.getTokenAmount();
    if (mounted) {
      setState(() => _userTokens = tokens);
    }
  }

  bool _isShowingJoinRequestDialog = false;
  String? _lastShownPendingGuestUid;
  bool _isProcessingJoinRequest = false;

  void _listenToRoom() {
    _roomSubscription = DuelService.streamRoom(widget.roomCode).listen((room) {
      if (!mounted) return;

      if (room == null || room.status == 'closed') {
        _showRoomClosedDialog();
        return;
      }

      final myUid = FirebaseAuth.instance.currentUser?.uid;

      // Eğer misafir olarak odadayken oda sahibi bizi odadan çıkardıysa (kick)
      if (!widget.isHost &&
          myUid != null &&
          _currentRoom?.guest?.uid == myUid &&
          (room.guest == null || room.guest?.uid != myUid)) {
        _showToast('duel.kicked_from_room'.tr(), isError: true);
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      setState(() {
        _currentRoom = room;
      });

      // Oyun başladıysa quiz ekranına yönlendir
      if ((room.status == 'in_game' || room.status == 'playing') &&
          !_hasNavigatedToQuiz) {
        _navigateToLiveQuiz(room);
        return;
      }

      // İstek durumu pending değilse veya pendingGuest boşsa son gösterilen UID'yi sıfırla
      if (room.pendingGuest == null || room.joinRequestStatus != 'pending') {
        _lastShownPendingGuestUid = null;
      }

      // Oda sahibi için gelen katılma isteğini göster (Tek seferlik ve yarış durumunu engelleyerek)
      if (widget.isHost &&
          room.pendingGuest != null &&
          room.joinRequestStatus == 'pending' &&
          !_isProcessingJoinRequest &&
          _lastShownPendingGuestUid != room.pendingGuest!.uid) {
        _showJoinRequestDialog(room.pendingGuest!);
      }

      // 1. Durum: Oda sahibi bot, kullanıcı misafir
      final isHostBot =
          room.host.uid.startsWith('bot_') || room.hostUid.startsWith('bot_');
      if (isHostBot &&
          !widget.isHost &&
          (room.status == 'waiting' || room.status == 'open')) {
        _checkAndHandleBotHostAutomation(room);

        // Misafir kullanıcı "Hazırım" verdiğinde bot host 4.5 saniye bekleyip gerçekçi şekilde maçı başlatsın
        if (room.guest?.isReady == true &&
            !_isStarting &&
            !_hasNavigatedToQuiz &&
            !_botStartTriggered) {
          _botStartTriggered = true;
          _botNudgeTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 4500), () async {
            if (!mounted || _hasNavigatedToQuiz || _isStarting) return;
            final msg = DuelChatMessage(
              id: '',
              senderUid: room.host.uid,
              senderName: room.host.username,
              senderAvatar: room.host.avatarIndex,
              text: 'duel.chat.start_game'.tr(),
              type: 'quick',
              phraseKey: 'duel.chat.start_game',
              createdAt: DateTime.now(),
            );
            await DuelService.sendRoomMessage(widget.roomCode, msg);
            await _handleStartGameForBotHost(room);
          });
        }
      }

      // 2. Durum: Kullanıcı oda sahibi, odaya katılan misafir bir bot
      final isGuestBot = room.guest?.uid.startsWith('bot_') == true;
      if (isGuestBot &&
          widget.isHost &&
          !_guestBotFlowTriggered &&
          room.guest != null) {
        _guestBotFlowTriggered = true;
        _botApplicantTimer?.cancel();

        // 3.5 saniye sonra selamlama mesajı gönder
        Future.delayed(const Duration(milliseconds: 3500), () async {
          if (!mounted || _hasNavigatedToQuiz || _currentRoom?.guest == null) {
            return;
          }
          final msg = DuelChatMessage(
            id: '',
            senderUid: room.guest!.uid,
            senderName: room.guest!.username,
            senderAvatar: room.guest!.avatarIndex,
            text: 'duel.chat.hello'.tr(),
            type: 'quick',
            phraseKey: 'duel.chat.hello',
            createdAt: DateTime.now(),
          );
          await DuelService.sendRoomMessage(widget.roomCode, msg);
        });

        // 6.5 saniye sonra "Ben hazırım! ⚡" mesajı gönder
        Future.delayed(const Duration(milliseconds: 6500), () async {
          if (!mounted || _hasNavigatedToQuiz || _currentRoom?.guest == null) {
            return;
          }
          final msg = DuelChatMessage(
            id: '',
            senderUid: room.guest!.uid,
            senderName: room.guest!.username,
            senderAvatar: room.guest!.avatarIndex,
            text: 'duel.chat.ready'.tr(),
            type: 'quick',
            phraseKey: 'duel.chat.ready',
            createdAt: DateTime.now(),
          );
          await DuelService.sendRoomMessage(widget.roomCode, msg);
        });

        // 8.5 saniye sonra bot hazır duruma geçsin
        Future.delayed(const Duration(milliseconds: 8500), () async {
          if (!mounted || _hasNavigatedToQuiz || _currentRoom?.guest == null) {
            return;
          }
          await DuelService.setPlayerReady(widget.roomCode,
              isHost: false, isReady: true);
        });
      }

      // Eğer iki oyuncu da hazırsa ve oda sahibi önceden başlat talimatı vermişse maçı başlat
      if (widget.isHost &&
          !isHostBot &&
          room.guest != null &&
          room.guest!.isReady &&
          room.hostWantsToStart &&
          !_isStarting &&
          !_hasNavigatedToQuiz) {
        _handleStartGame();
      }
    });
  }

  void _checkAndHandleBotHostAutomation(DuelRoom room) {
    if (_botAutomationTriggered) return;
    _botAutomationTriggered = true;
    debugPrint(
        '🤖 Bot Host Lobi Otomasyonu Başlatıldı: ${room.host.username} (${room.roomCode})');

    // 1. Bot Bahis Kontrolü: Kullanıcının parası yetmiyorsa bahsi otomatik düşür
    _loadLocalTokens().then((_) {
      if (_userTokens < room.config.betTokens && _userTokens > 0) {
        int newBet = 10;
        if (_userTokens >= 50) {
          newBet = 50;
        } else if (_userTokens >= 25) {
          newBet = 25;
        } else if (_userTokens >= 10) {
          newBet = 10;
        } else {
          newBet = _userTokens;
        }

        if (newBet != room.config.betTokens) {
          Future.delayed(const Duration(milliseconds: 1200), () async {
            try {
              await DuelService.updateRoomConfig(
                widget.roomCode,
                room.config.copyWith(betTokens: newBet),
              );
            } catch (_) {}
          });
        }
      }
    });

    // 2. Bot Lobi Sohbeti: 2.5 saniye sonra doğal selamlama gönder
    _botChatTimer?.cancel();
    _botChatTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted || _hasNavigatedToQuiz) return;
      final greetings = [
        {'key': 'duel.chat.hello', 'text': 'Merhaba! 👋'},
        {'key': 'duel.chat.good_luck', 'text': 'Bol şans! 🍀'},
      ];
      final greeting = greetings[Random().nextInt(greetings.length)];

      final msg = DuelChatMessage(
        id: '',
        senderUid: room.host.uid,
        senderName: room.host.username,
        senderAvatar: room.host.avatarIndex,
        text: greeting['text']!,
        type: 'quick',
        phraseKey: greeting['key'],
        createdAt: DateTime.now(),
      );
      await DuelService.sendRoomMessage(widget.roomCode, msg);
      debugPrint('🤖 Bot Sohbet Mesajı Gönderdi: ${greeting['text']}');
    });

    // 3. Kullanıcının sohbet mesajlarına ve bahis arttır/azalt isteklerine gerçekçi gecikmeyle tepki ver
    _botChatReactionSub?.cancel();
    _botChatReactionSub =
        DuelService.streamRoomMessages(widget.roomCode).listen((messages) {
      if (!mounted || _hasNavigatedToQuiz) return;
      final botUid = room.host.uid;

      for (final msg in messages) {
        if (msg.senderUid != botUid &&
            !_botHandledMessageIds.contains(msg.id) &&
            msg.id.isNotEmpty) {
          _botHandledMessageIds.add(msg.id);
          debugPrint(
              '🤖 Bot Kullanıcı Mesajını Algıladı: "${msg.text}" (key: ${msg.phraseKey})');
          _handleBotReactionToUserMessage(msg, room);
        }
      }
    });

    // 4. Kullanıcı uzun süre hazır vermezse 25 saniye sonra hatırlatma yap
    _botNudgeTimer?.cancel();
    _botNudgeTimer = Timer(const Duration(seconds: 25), () async {
      if (!mounted || _hasNavigatedToQuiz || _isStarting || _botStartTriggered) {
        return;
      }
      final msg = DuelChatMessage(
        id: '',
        senderUid: room.host.uid,
        senderName: room.host.username,
        senderAvatar: room.host.avatarIndex,
        text: 'duel.chat.ready'.tr(),
        type: 'quick',
        phraseKey: 'duel.chat.ready',
        createdAt: DateTime.now(),
      );
      await DuelService.sendRoomMessage(widget.roomCode, msg);
    });
  }

  void _handleBotReactionToUserMessage(DuelChatMessage userMsg, DuelRoom room) {
    final lowerText = userMsg.text.toLowerCase().trim();
    final pKey = userMsg.phraseKey ?? '';

    // 1. Soru Sayısını Değiştirme / Arttırma / Azaltma İsteği
    final isQuestionIncrease = pKey == 'duel.chat.increase_questions' ||
        lowerText.contains('soru sayısını arttır') ||
        lowerText.contains('soru sayisini arttir') ||
        lowerText.contains('soru arttır') ||
        lowerText.contains('soru artir') ||
        lowerText.contains('soru yukselt') ||
        lowerText.contains('soru yükselt') ||
        lowerText.contains('increase questions') ||
        (lowerText.contains('soru') &&
            (lowerText.contains('art') || lowerText.contains('⬆')));

    final isQuestionDecrease = pKey == 'duel.chat.decrease_questions' ||
        lowerText.contains('soru sayısını azalt') ||
        lowerText.contains('soru sayisini azalt') ||
        lowerText.contains('soru azalt') ||
        lowerText.contains('soru düşür') ||
        lowerText.contains('soru dusur') ||
        lowerText.contains('decrease questions') ||
        (lowerText.contains('soru') &&
            (lowerText.contains('azalt') ||
                lowerText.contains('düş') ||
                lowerText.contains('dus') ||
                lowerText.contains('⬇')));

    if (isQuestionIncrease || isQuestionDecrease) {
      final currentCount =
          _currentRoom?.config.questionCount ?? room.config.questionCount;
      int nextCount = currentCount;

      if (isQuestionIncrease) {
        if (currentCount == 5) {
          nextCount = 6;
        } else if (currentCount == 6) {
          nextCount = 7;
        } else {
          nextCount = 5; // Döner döngü
        }
      } else {
        if (currentCount == 7) {
          nextCount = 6;
        } else if (currentCount == 6) {
          nextCount = 5;
        } else {
          nextCount = 7; // Döner döngü
        }
      }

      // 1.2 saniye sonra oda ayarlarını güncelle
      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!mounted || _hasNavigatedToQuiz) return;
        final currentCfg = _currentRoom?.config ?? room.config;
        await DuelService.updateRoomConfig(
          widget.roomCode,
          currentCfg.copyWith(questionCount: nextCount),
        );
        debugPrint(
            '🤖 Bot Soru Sayısını Değiştirdi: $currentCount -> $nextCount');

        // Onay mesajı gönder
        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (!mounted || _hasNavigatedToQuiz) return;
          final botReply = DuelChatMessage(
            id: '',
            senderUid: room.host.uid,
            senderName: room.host.username,
            senderAvatar: room.host.avatarIndex,
            text: 'duel.chat.ready'.tr(),
            type: 'quick',
            phraseKey: 'duel.chat.ready',
            createdAt: DateTime.now(),
          );
          await DuelService.sendRoomMessage(widget.roomCode, botReply);
        });
      });
      return;
    }

    // 2. Bahisi arttır isteği
    const betTiers = [10, 25, 50, 100];
    final isBetIncrease = pKey == 'duel.chat.increase_bet' ||
        lowerText.contains('bahisi arttır') ||
        lowerText.contains('bahsi arttır') ||
        lowerText.contains('bahis arttır') ||
        lowerText.contains('bahis artir') ||
        lowerText.contains('increase bet') ||
        (lowerText.contains('bahis') &&
            (lowerText.contains('art') || lowerText.contains('⬆')));

    if (isBetIncrease) {
      final currentBet =
          _currentRoom?.config.betTokens ?? room.config.betTokens;
      int nextBet = currentBet;
      for (final b in betTiers) {
        if (b > currentBet) {
          nextBet = b;
          break;
        }
      }
      if (nextBet == currentBet) {
        nextBet = betTiers.first; // Döngü
      }

      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!mounted || _hasNavigatedToQuiz) return;
        final currentCfg = _currentRoom?.config ?? room.config;
        await DuelService.updateRoomConfig(
          widget.roomCode,
          currentCfg.copyWith(betTokens: nextBet),
        );
        debugPrint('🤖 Bot Bahsi Değiştirdi: $currentBet -> $nextBet');

        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (!mounted || _hasNavigatedToQuiz) return;
          final botReply = DuelChatMessage(
            id: '',
            senderUid: room.host.uid,
            senderName: room.host.username,
            senderAvatar: room.host.avatarIndex,
            text: 'duel.chat.ready'.tr(),
            type: 'quick',
            phraseKey: 'duel.chat.ready',
            createdAt: DateTime.now(),
          );
          await DuelService.sendRoomMessage(widget.roomCode, botReply);
        });
      });
      return;
    }

    // 3. Bahisi azalt isteği
    final isBetDecrease = pKey == 'duel.chat.decrease_bet' ||
        lowerText.contains('bahisi azalt') ||
        lowerText.contains('bahsi azalt') ||
        lowerText.contains('bahis azalt') ||
        lowerText.contains('decrease bet') ||
        (lowerText.contains('bahis') &&
            (lowerText.contains('azalt') ||
                lowerText.contains('düş') ||
                lowerText.contains('dus') ||
                lowerText.contains('⬇')));

    if (isBetDecrease) {
      final currentBet =
          _currentRoom?.config.betTokens ?? room.config.betTokens;
      int prevBet = currentBet;
      for (final b in betTiers.reversed) {
        if (b < currentBet) {
          prevBet = b;
          break;
        }
      }
      if (prevBet == currentBet) {
        prevBet = betTiers.last; // Döngü
      }

      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!mounted || _hasNavigatedToQuiz) return;
        final currentCfg = _currentRoom?.config ?? room.config;
        await DuelService.updateRoomConfig(
          widget.roomCode,
          currentCfg.copyWith(betTokens: prevBet),
        );
        debugPrint('🤖 Bot Bahsi Değiştirdi: $currentBet -> $prevBet');

        Future.delayed(const Duration(milliseconds: 1000), () async {
          if (!mounted || _hasNavigatedToQuiz) return;
          final botReply = DuelChatMessage(
            id: '',
            senderUid: room.host.uid,
            senderName: room.host.username,
            senderAvatar: room.host.avatarIndex,
            text: 'duel.chat.ready'.tr(),
            type: 'quick',
            phraseKey: 'duel.chat.ready',
            createdAt: DateTime.now(),
          );
          await DuelService.sendRoomMessage(widget.roomCode, botReply);
        });
      });
      return;
    }

    // 5. Selamlama cevabı (4.5 sn)
    if (userMsg.phraseKey == 'duel.chat.hello' ||
        userMsg.text.contains('Merhaba') ||
        userMsg.text.contains('Selam') ||
        userMsg.text.toLowerCase().contains('hello') ||
        userMsg.text.toLowerCase().contains('hi')) {
      Future.delayed(const Duration(milliseconds: 4500), () async {
        if (!mounted || _hasNavigatedToQuiz) return;
        final botReply = DuelChatMessage(
          id: '',
          senderUid: room.host.uid,
          senderName: room.host.username,
          senderAvatar: room.host.avatarIndex,
          text: 'duel.chat.hello'.tr(),
          type: 'quick',
          phraseKey: 'duel.chat.hello',
          createdAt: DateTime.now(),
        );
        await DuelService.sendRoomMessage(widget.roomCode, botReply);
      });
      return;
    }

    // 4. Hadi başlayalım / Hazırım isteği (4.5 sn)
    if (userMsg.phraseKey == 'duel.chat.start_game' ||
        userMsg.phraseKey == 'duel.chat.ready' ||
        userMsg.text.contains('başlayalım') ||
        userMsg.text.contains('hazırım') ||
        userMsg.text.toLowerCase().contains('start') ||
        userMsg.text.toLowerCase().contains('ready')) {
      Future.delayed(const Duration(milliseconds: 4500), () async {
        if (!mounted ||
            _hasNavigatedToQuiz ||
            _isStarting ||
            _botStartTriggered) {
          return;
        }
        _botStartTriggered = true;
        _botNudgeTimer?.cancel();
        final botReply = DuelChatMessage(
          id: '',
          senderUid: room.host.uid,
          senderName: room.host.username,
          senderAvatar: room.host.avatarIndex,
          text: 'duel.chat.start_game'.tr(),
          type: 'quick',
          phraseKey: 'duel.chat.start_game',
          createdAt: DateTime.now(),
        );
        await DuelService.sendRoomMessage(widget.roomCode, botReply);
        await _handleStartGameForBotHost(_currentRoom ?? room);
      });
      return;
    }

    // 5. Emojilere emoji ile karşılık ver (4.0 sn)
    if (userMsg.type == 'emoji' || userMsg.text.length <= 4) {
      Future.delayed(const Duration(milliseconds: 4000), () async {
        if (!mounted || _hasNavigatedToQuiz) return;
        final botEmojis = ['🔥', '👍', '😎', '👏', '⚡', '🏆', '🚀'];
        final emoji = botEmojis[Random().nextInt(botEmojis.length)];
        final botReply = DuelChatMessage(
          id: '',
          senderUid: room.host.uid,
          senderName: room.host.username,
          senderAvatar: room.host.avatarIndex,
          text: emoji,
          type: 'emoji',
          createdAt: DateTime.now(),
        );
        await DuelService.sendRoomMessage(widget.roomCode, botReply);
      });
      return;
    }

    // 6. Diğer tüm mesajlara genel karşılık (4.5 sn)
    Future.delayed(const Duration(milliseconds: 4500), () async {
      if (!mounted || _hasNavigatedToQuiz) return;
      final generalReplies = [
        {'key': 'duel.chat.good_luck', 'text': 'duel.chat.good_luck'.tr()},
        {'key': 'duel.chat.ready', 'text': 'duel.chat.ready'.tr()},
        {'key': 'duel.chat.well_played', 'text': 'duel.chat.well_played'.tr()},
      ];
      final r = generalReplies[Random().nextInt(generalReplies.length)];
      final botReply = DuelChatMessage(
        id: '',
        senderUid: room.host.uid,
        senderName: room.host.username,
        senderAvatar: room.host.avatarIndex,
        text: r['text']!,
        type: 'quick',
        phraseKey: r['key'],
        createdAt: DateTime.now(),
      );
      await DuelService.sendRoomMessage(widget.roomCode, botReply);
    });
  }

  Future<void> _handleStartGameForBotHost(DuelRoom room) async {
    if (_isStarting || _hasNavigatedToQuiz) return;

    final hasInternet = await AppUtils.hasInternetConnection();
    if (!hasInternet) {
      _showToast('errors.no_internet_ai'.tr(), isError: true);
      return;
    }

    // Anlık token miktarını al ve gerekiyorsa bahsi kullanıcının bakiyesine uyarla
    final currentTokens = await TokenService.getTokenAmount();
    int activeBet = (_currentRoom?.config.betTokens ?? room.config.betTokens);
    if (currentTokens < activeBet) {
      if (currentTokens >= 50) {
        activeBet = 50;
      } else if (currentTokens >= 25) {
        activeBet = 25;
      } else if (currentTokens >= 10) {
        activeBet = 10;
      } else {
        activeBet = currentTokens > 0 ? currentTokens : 0;
      }
      try {
        await DuelService.updateRoomConfig(
          widget.roomCode,
          (_currentRoom?.config ?? room.config).copyWith(betTokens: activeBet),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    final currentLocaleLang = context.locale.languageCode;
    setState(() => _isStarting = true);

    try {
      await DuelService.setRoomStatus(widget.roomCode, 'starting');

      final activeConfig = _currentRoom?.config ?? room.config;
      final guestLang = currentLocaleLang;

      // Bot maçlarında da iki tarafa ortak havuzdan görülmemiş sorular çekilir (Aralıklı tekrar düelloda kapalıdır)
      final questions = await QuestionPoolService.getHybridQuestions(
        category: activeConfig.category,
        difficulty: activeConfig.difficulty,
        languageCode: guestLang,
        count: activeConfig.questionCount,
        includeSpacedRepetition: false,
      );

      if (questions.isEmpty) {
        throw Exception('Failed to generate questions');
      }

      // Misafir jetonunu harca
      if (activeBet > 0) {
        await TokenService.spendTokens(activeBet);
      }

      // Düelloyu başlat
      await DuelService.startDuel(
        roomCode: widget.roomCode,
        questions: questions,
        betTokens: activeBet,
      );
    } catch (e) {
      debugPrint('Error starting bot duel: $e');
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _showJoinRequestDialog(DuelPlayer pendingPlayer) {
    if (_isShowingJoinRequestDialog || _isProcessingJoinRequest) return;
    _isShowingJoinRequestDialog = true;
    _lastShownPendingGuestUid = pendingPlayer.uid;

    final localizedName = AppUtils.localizeUsername(pendingPlayer.username);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F43).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: Color(0xFFFF9F43), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'duel.join_request_title'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Player Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final hasAvatar =
                            UserService.hasAvatar(pendingPlayer.avatarIndex);
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF0F172A),
                          backgroundImage: hasAvatar
                              ? ResizeImage(
                                  AssetImage(UserService.getAvatarPath(
                                      pendingPlayer.avatarIndex)),
                                  width: 96,
                                  height: 96,
                                )
                              : null,
                          child: hasAvatar
                              ? null
                              : const Icon(Icons.person_rounded,
                                  size: 24, color: Colors.white70),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${pendingPlayer.tokens} ${'token.unit'.tr()}',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'duel.join_request_desc'.tr(args: [localizedName]),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 13.5),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            OutlinedButton(
              onPressed: () async {
                _isProcessingJoinRequest = true;
                _isShowingJoinRequestDialog = false;
                Navigator.of(dialogCtx).pop();
                try {
                  await DuelService.rejectJoinRequest(widget.roomCode);
                } finally {
                  _isProcessingJoinRequest = false;
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'duel.reject'.tr(),
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                _isProcessingJoinRequest = true;
                _isShowingJoinRequestDialog = false;
                Navigator.of(dialogCtx).pop();
                try {
                  await DuelService.approveJoinRequest(widget.roomCode);
                } finally {
                  _isProcessingJoinRequest = false;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'duel.accept'.tr(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingJoinRequestDialog = false;
    });
  }

  void _navigateToLiveQuiz(DuelRoom room) {
    if (_hasNavigatedToQuiz) return;
    _hasNavigatedToQuiz = true;
    _heartbeatTimer?.cancel();
    _roomSubscription.cancel();
    _botApplicantTimer?.cancel();
    _botChatTimer?.cancel();
    _botNudgeTimer?.cancel();
    _botChatReactionSub?.cancel();

    final bool isWithBot = room.guest?.uid.startsWith('bot_') == true ||
        room.host.uid.startsWith('bot_') == true;

    AnalyticsService.logDuelMatchStart(
      category: room.config.category,
      difficulty: room.config.difficulty,
      betTokens: room.config.betTokens,
      questionCount: room.config.questionCount,
      isHost: widget.isHost,
      isWithBot: isWithBot,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LiveDuelQuizScreen(
            room: room,
            isHost: widget.isHost,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  void _showRoomClosedDialog() {
    _roomSubscription.cancel();
    _heartbeatTimer?.cancel();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('duel.room_closed'.tr(),
            style: const TextStyle(color: Colors.white)),
        content: Text('duel.room_closed_desc'.tr(),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('common.ok'.tr(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartGame() async {
    if (_currentRoom == null || _isStarting) return;

    final hasInternet = await AppUtils.hasInternetConnection();
    if (!hasInternet) {
      _showToast('errors.no_internet_ai'.tr(), isError: true);
      return;
    }

    final room = _currentRoom!;

    // 1. Check guest present
    if (room.guest == null) {
      _showToast('duel.waiting_guest'.tr(), isError: true);
      return;
    }

    // 2. Check tokens for both players
    final bet = room.config.betTokens;
    if (_userTokens < bet) {
      _showToast('duel.you_need_tokens'.tr(args: [bet.toString()]),
          isError: true);
      return;
    }
    if (room.guest!.tokens < bet) {
      _showToast('duel.guest_needs_tokens'.tr(args: [bet.toString()]),
          isError: true);
      return;
    }

    if (!mounted) return;
    final currentLocaleLang = context.locale.languageCode;
    setState(() => _isStarting = true);

    try {
      // Set room status to 'starting' so guest also sees the preparing overlay
      await DuelService.setRoomStatus(widget.roomCode, 'starting');

      // Fetch questions from Hybrid Pool / Multi-language Synchronizer
      final hostLang = room.host.language.isNotEmpty
          ? room.host.language
          : currentLocaleLang;
      final guestLang = (room.guest?.language.isNotEmpty == true)
          ? room.guest!.language
          : hostLang;

      List<Question> questions;
      if (hostLang != guestLang) {
        debugPrint(
            '🌐 Farklı diller tespit edildi: Host=$hostLang, Guest=$guestLang. Çok dilli sorular havuzdan çekiliyor...');
        questions = await QuestionPoolService.getHybridMultilingualQuestions(
          category: room.config.category,
          difficulty: room.config.difficulty,
          languageCodes: [hostLang, guestLang],
          count: room.config.questionCount,
        );
      } else {
        questions = await QuestionPoolService.getHybridQuestions(
          category: room.config.category,
          difficulty: room.config.difficulty,
          languageCode: hostLang,
          count: room.config.questionCount,
          includeSpacedRepetition:
              false, // Düelloda iki oyuncuya da eşit ortak soru
        );
      }

      if (questions.isEmpty) {
        throw Exception('Failed to generate questions');
      }

      // Spend host tokens
      await TokenService.spendTokens(bet);

      // Start the duel in Firestore
      await DuelService.startDuel(
        roomCode: widget.roomCode,
        questions: questions,
        betTokens: bet,
      );
    } catch (e) {
      debugPrint('Error starting duel: $e');
      await DuelService.setRoomStatus(widget.roomCode, 'ready');
      if (mounted) {
        setState(() => _isStarting = false);
        _showToast('duel.start_error'.tr(), isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    _roomSubscription.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isCurrentlyHost =
          _currentRoom?.hostUid == user.uid || widget.isHost;
      await DuelService.leaveRoom(
        widget.roomCode,
        isHost: isCurrentlyHost,
        uid: user.uid,
      );
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentRoom == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9F43)),
        ),
      );
    }

    final room = _currentRoom!;

    // When duel starts, show full LoadingScreen for both players until questions are ready and 5s elapsed
    if (_isStarting || room.status == 'starting' || room.status == 'in_game') {
      return LoadingScreen(
        isDataReady: room.status == 'in_game' && room.questions.isNotEmpty,
        onStart: () => _navigateToLiveQuiz(room),
        onTimeout: () async {
          if (!mounted) return;
          if (widget.isHost) {
            await DuelService.setRoomStatus(widget.roomCode, 'ready');
          }
          setState(() {
            _isStarting = false;
          });
          _showToast('errors.no_internet_ai'.tr(), isError: true);
        },
      );
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isHost = room.hostUid == myUid ||
        (widget.isHost && (room.hostUid.isEmpty || room.hostUid == myUid));
    final int prize = DuelRoom.calculatePrize(room.config.betTokens);
    final bool canStart = isHost &&
        room.guest != null &&
        _userTokens >= room.config.betTokens &&
        room.guest!.tokens >= room.config.betTokens;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leaveRoom();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E1B4B),
                    Color(0xFF0F172A)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(room),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildRoomCodeCard(room),
                          const SizedBox(height: 14),
                          _buildVsMatchupSection(room),
                          const SizedBox(height: 14),
                          _buildRoomSettingsBar(room, prize, isHost),
                          const SizedBox(height: 14),
                          const MyNativeAd(
                            height: 70,
                            factoryId: 'adFactorySmall',
                          ),
                          const SizedBox(height: 14),
                          _buildLobbyChatSection(room),
                          if (_userTokens < room.config.betTokens ||
                              (room.guest != null &&
                                  room.guest!.tokens <
                                      room.config.betTokens)) ...[
                            const SizedBox(height: 14),
                            _buildInsufficientTokensBanner(room),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActionBar(room, canStart, isHost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DuelRoom room) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text('duel.leave_room_title'.tr(),
                      style: const TextStyle(color: Colors.white)),
                  content: Text('duel.leave_room_msg'.tr(),
                      style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common.cancel'.tr(),
                          style: const TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _leaveRoom();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      child: Text('duel.leave'.tr(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          Text(
            'duel.room_lobby'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const TokenWidget(),
        ],
      ),
    );
  }

  Widget _buildRoomCodeCard(DuelRoom room) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      opacity: 0.12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF9F43), Color(0xFFFF5252)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.vpn_key_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'duel.room_code'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  room.roomCode,
                  style: const TextStyle(
                    color: Color(0xFFFFD56B),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFFFF9F43)),
            tooltip: 'duel.share_link'.tr(),
            onPressed: () => _showShareDialog(room.roomCode),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            tooltip: 'duel.copy_code'.tr(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: room.roomCode));
              _showToast('duel.code_copied'.tr());
            },
          ),
        ],
      ),
    );
  }

  void _showShareDialog(String code) {
    final shareText =
        '⚡ EmilekBul 1v1 Bilgi Düellosu!\nArkadaşın seninle yarışmak için oda açtı!\n🔑 Oda Kodu: $code\n🚀 Doğrudan Katıl: emilekbul://join?code=$code\n📲 Uygulama İndir: https://play.google.com/store/apps/details?id=com.abdullahekici.emilekbul';

    Clipboard.setData(ClipboardData(text: shareText));
    _showToast('duel.invite_link_copied'.tr());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.share_rounded, color: Color(0xFFFF9F43)),
            const SizedBox(width: 10),
            Text('duel.share_room'.tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('duel.invite_link_ready'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                shareText,
                style: const TextStyle(
                    color: Color(0xFFFFD56B), fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('common.ok'.tr(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVsMatchupSection(DuelRoom room) {
    return Row(
      children: [
        // Host Player Card
        Expanded(child: _buildPlayerCard(room.host, isHost: true)),

        // VS Badge in the center
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFFF793F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Guest Player Card
        Expanded(
          child: room.guest != null
              ? _buildPlayerCard(room.guest!, isHost: false)
              : _buildEmptyGuestCard(),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(DuelPlayer player, {required bool isHost}) {
    final titleKey = AppConstants.titleKeys[player.equippedTitle];
    final String displayTitle = (titleKey != null && titleKey.isNotEmpty)
        ? titleKey.tr()
        : player.equippedTitle;

    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      opacity: 0.1,
      child: Column(
        children: [
          // Badge: Oda Sahibi / Katılımcı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isHost
                  ? const Color(0xFFFF9F43).withValues(alpha: 0.25)
                  : const Color(0xFF6366F1).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isHost ? const Color(0xFFFF9F43) : const Color(0xFF6366F1),
                width: 0.8,
              ),
            ),
            child: Text(
              isHost ? 'duel.host'.tr() : 'duel.challenger'.tr(),
              style: TextStyle(
                color:
                    isHost ? const Color(0xFFFFD56B) : const Color(0xFFA5B4FC),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Avatar + Frame + Online Indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: UserService.getFrameColor(player.equippedFrame),
                    width: 3,
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final hasAvatar = UserService.hasAvatar(player.avatarIndex);
                    return CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF1E293B),
                      backgroundImage: hasAvatar
                          ? ResizeImage(
                              AssetImage(UserService.getAvatarPath(
                                  player.avatarIndex)),
                              width: 120,
                              height: 120,
                            )
                          : null,
                      child: hasAvatar
                          ? null
                          : const Icon(Icons.person_rounded,
                              size: 30, color: Colors.white70),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF1E293B), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            AppUtils.localizeUsername(player.username),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),

          // Title
          if (player.equippedTitle != '0' && player.equippedTitle != 'yok') ...[
            const SizedBox(height: 2),
            Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFD56B),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Tokens Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Colors.orange, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${player.tokens}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Readiness / Host Start State Badge
          const SizedBox(height: 8),
          if (isHost) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_currentRoom?.hostWantsToStart == true)
                    ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_currentRoom?.hostWantsToStart == true)
                      ? const Color(0xFF818CF8)
                      : Colors.white24,
                  width: 0.8,
                ),
              ),
              child: Text(
                (_currentRoom?.hostWantsToStart == true)
                    ? 'duel.host_wants_start_badge'.tr()
                    : 'duel.host'.tr(),
                style: TextStyle(
                  color: (_currentRoom?.hostWantsToStart == true)
                      ? const Color(0xFFA5B4FC)
                      : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: player.isReady
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : const Color(0xFFFF9F43).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: player.isReady
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFF9F43),
                  width: 0.8,
                ),
              ),
              child: Text(
                player.isReady
                    ? 'duel.ready_badge'.tr()
                    : 'duel.not_ready_badge'.tr(),
                style: TextStyle(
                  color: player.isReady
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFFD56B),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],

          // Friend Action Button (if opponent)
          _buildFriendStatusButton(player.uid),

          // Kick Button for Host
          if (widget.isHost && !isHost) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _confirmKickGuest(player),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_remove_rounded,
                        color: Colors.redAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'duel.kick_guest'.tr(),
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmKickGuest(DuelPlayer guest) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person_remove_rounded,
                color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'duel.kick_confirm_title'.tr(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'duel.kick_confirm_msg'
              .tr(args: [AppUtils.localizeUsername(guest.username)]),
          style: const TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await DuelService.kickGuest(widget.roomCode);
              _guestBotFlowTriggered = false;
              _startBotApplicantTimer();
              _showToast(
                  '${AppUtils.localizeUsername(guest.username)} odadan çıkarıldı.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('duel.kick_guest'.tr(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendStatusButton(String otherUid) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || otherUid.isEmpty || myUid == otherUid) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<FriendshipStatus>(
      stream: FriendService.streamFriendshipStatus(otherUid),
      builder: (context, snapshot) {
        final status = snapshot.data ?? FriendshipStatus.none;

        if (status == FriendshipStatus.friends) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'friends.already_friends'.tr(),
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        if (status == FriendshipStatus.sentPending) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Colors.orange, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'friends.request_sent'.tr(),
                    style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        if (status == FriendshipStatus.receivedPending) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                final res = await FriendService.acceptRequestFrom(otherUid);
                final msgKey = res['message'] as String? ?? 'common.error';
                _showToast(msgKey.tr(), isError: res['success'] != true);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'friends.accept_request'.tr(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              final res = await FriendService.sendFriendRequest(otherUid);
              final msgKey = res['message'] as String? ?? 'common.error';
              _showToast(msgKey.tr(), isError: res['success'] != true);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_rounded,
                      color: Color(0xFFA5B4FC), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'friends.add_friend'.tr(),
                    style: const TextStyle(
                        color: Color(0xFFA5B4FC),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyGuestCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      opacity: 0.06,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border:
                  Border.all(color: Colors.white24, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white38, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'duel.waiting_guest'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'duel.share_code_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSettingsBar(DuelRoom room, int prize, bool isHost) {
    final allCats = [
      ...AppCategories.categories,
      ...AppCategories.bonusPoolCategories
    ];
    final currentCat = allCats.firstWhere(
      (c) => c.name == room.config.category,
      orElse: () => allCats.first,
    );

    Color diffColor;
    String diffKey;
    switch (room.config.difficulty) {
      case 'Kolay':
        diffColor = const Color(0xFF4CAF50);
        diffKey = 'category_ui.difficulty.easy';
        break;
      case 'Zor':
        diffColor = const Color(0xFFE91E63);
        diffKey = 'category_ui.difficulty.hard';
        break;
      case 'Imkansız':
        diffColor = const Color(0xFF9C27B0);
        diffKey = 'category_ui.difficulty.impossible';
        break;
      default:
        diffColor = const Color(0xFFFF9800);
        diffKey = 'category_ui.difficulty.medium';
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 18,
      opacity: 0.08,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: currentCat.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(currentCat.icon, color: currentCat.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentCat.key.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: diffColor.withValues(alpha: 0.4),
                            width: 0.8),
                      ),
                      child: Text(
                        diffKey.tr(),
                        style: TextStyle(
                            color: diffColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${room.config.questionCount} ${'duel.questions'.tr()}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11),
                    ),
                    Text('•',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11)),
                    Text(
                      '${room.config.betTokens} 🪙',
                      style: const TextStyle(
                          color: Color(0xFFFFD56B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isHost)
            ElevatedButton.icon(
              onPressed: () => _showRoomSettingsModal(room),
              icon:
                  const Icon(Icons.tune_rounded, size: 16, color: Colors.black),
              label: Text(
                'duel.edit_settings'.tr(),
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F43),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD56B), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    '$prize 🪙',
                    style: const TextStyle(
                        color: Color(0xFFFFD56B),
                        fontSize: 12,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRoomSettingsModal(DuelRoom room) {
    HapticFeedback.lightImpact();
    final allCats = [
      ...AppCategories.categories,
      ...AppCategories.bonusPoolCategories
    ];

    String tempCategory = room.config.category;
    String tempDifficulty = room.config.difficulty;
    int tempCount = room.config.questionCount;
    int tempBet = room.config.betTokens;

    final difficulties = [
      {
        'name': 'Kolay',
        'key': 'category_ui.difficulty.easy',
        'color': const Color(0xFF4CAF50)
      },
      {
        'name': 'Orta',
        'key': 'category_ui.difficulty.medium',
        'color': const Color(0xFFFF9800)
      },
      {
        'name': 'Zor',
        'key': 'category_ui.difficulty.hard',
        'color': const Color(0xFFE91E63)
      },
      {
        'name': 'Imkansız',
        'key': 'category_ui.difficulty.impossible',
        'color': const Color(0xFF9C27B0)
      },
    ];
    const counts = [5, 6, 7];
    const bets = [10, 25, 50, 100, 250, 500, 1000];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentCat = allCats.firstWhere(
              (c) => c.name == tempCategory,
              orElse: () => allCats.first,
            );
            final prize = DuelRoom.calculatePrize(tempBet);

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Colors.white24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded,
                              color: Color(0xFFFF9F43), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'duel.room_settings'.tr(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // 1. Kategori
                        Text(
                          'category_ui.preview_category'.tr(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            _showCategoryPickerSheetInModal(
                                allCats, tempCategory, (catName) {
                              setModalState(() => tempCategory = catName);
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Icon(currentCat.icon,
                                    color: currentCat.color, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    currentCat.key.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white60),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Zorluk
                        Text(
                          'duel.difficulty'.tr(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: difficulties.map((d) {
                            final name = d['name'] as String;
                            final color = d['color'] as Color;
                            final isSelected = name == tempDifficulty;

                            return InkWell(
                              onTap: () =>
                                  setModalState(() => tempDifficulty = name),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          isSelected ? color : Colors.white12),
                                ),
                                child: Text(
                                  (d['key'] as String).tr(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // 3. Soru Sayısı
                        Text(
                          'duel.question_count'.tr(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: counts.map((count) {
                              final isSelected = count == tempCount;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () =>
                                      setModalState(() => tempCount = count),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFF9F43)
                                          : Colors.white
                                              .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFFF9F43)
                                              : Colors.white12),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.white70,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Bahis Miktarı
                        Text(
                          'duel.bet_amount'.tr(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: bets.map((bet) {
                            final isSelected = bet == tempBet;
                            final isSpecial = DuelRoom.isSpecialHighBet(bet);
                            final feePercent =
                                (DuelRoom.getCommissionRate(bet) * 100).toInt();

                            return InkWell(
                              onTap: () => setModalState(() => tempBet = bet),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? (isSpecial
                                          ? const LinearGradient(colors: [
                                              Color(0xFFA855F7),
                                              Color(0xFFEC4899)
                                            ])
                                          : const LinearGradient(colors: [
                                              Color(0xFFFF9F43),
                                              Color(0xFFFF5252)
                                            ]))
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : (isSpecial
                                            ? Colors.purpleAccent
                                                .withValues(alpha: 0.5)
                                            : Colors.white12),
                                    width: isSpecial ? 1.2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSpecial
                                          ? Icons.workspace_premium_rounded
                                          : Icons.monetization_on_rounded,
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : (isSpecial
                                              ? const Color(0xFFC084FC)
                                              : Colors.orange),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      bet >= 1000 ? '1K' : '$bet',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isSpecial) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.black
                                                  .withValues(alpha: 0.3)
                                              : const Color(0xFFA855F7)
                                                  .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '%$feePercent',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFFD8B4FE),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Ödül Özeti
                        Builder(
                          builder: (context) {
                            final feePercent =
                                (DuelRoom.getCommissionRate(tempBet) * 100)
                                    .toInt();
                            final isSpecial =
                                DuelRoom.isSpecialHighBet(tempBet);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSpecial
                                      ? [
                                          const Color(0xFFA855F7)
                                              .withValues(alpha: 0.2),
                                          const Color(0xFFEC4899)
                                              .withValues(alpha: 0.12),
                                        ]
                                      : [
                                          const Color(0xFFFF9F43)
                                              .withValues(alpha: 0.18),
                                          const Color(0xFF6366F1)
                                              .withValues(alpha: 0.12),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSpecial
                                      ? const Color(0xFFA855F7)
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFFF9F43)
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'duel.pot_prize'.tr(),
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tempBet * 2} Token (${'duel.fee_info'.tr(args: [
                                              '$feePercent'
                                            ])})',
                                        style: TextStyle(
                                          color: isSpecial
                                              ? const Color(0xFF34D399)
                                              : Colors.white
                                                  .withValues(alpha: 0.6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        isSpecial
                                            ? Icons.military_tech_rounded
                                            : Icons.emoji_events_rounded,
                                        color: isSpecial
                                            ? const Color(0xFFD8B4FE)
                                            : const Color(0xFFFFD56B),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$prize Token',
                                        style: TextStyle(
                                          color: isSpecial
                                              ? const Color(0xFFD8B4FE)
                                              : const Color(0xFFFFD56B),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                        final newConfig = DuelConfig(
                          category: tempCategory,
                          difficulty: tempDifficulty,
                          questionCount: tempCount,
                          betTokens: tempBet,
                        );
                        await DuelService.updateRoomConfig(
                            widget.roomCode, newConfig);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('duel.settings_saved'.tr()),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9F43),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'duel.save_settings'.tr(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryPickerSheetInModal(List<CategoryItem> allCats,
      String currentCategory, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                'category_ui.select_category'.tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: allCats.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cat = allCats[index];
                    final isSelected = cat.name == currentCategory;

                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(cat.name);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFFF9F43)
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      tileColor: isSelected
                          ? const Color(0xFFFF9F43).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      leading: Icon(cat.icon, color: cat.color),
                      title: Text(
                        cat.key.tr(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFFF9F43))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLobbyChatSection(DuelRoom room) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 22,
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chat Header
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 8),
              Text(
                'duel.lobby_chat'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Message Stream
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: StreamBuilder<List<DuelChatMessage>>(
              stream: DuelService.streamRoomMessages(widget.roomCode),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'duel.no_messages_yet'.tr(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_chatScrollController.hasClients) {
                    _chatScrollController
                        .jumpTo(_chatScrollController.position.maxScrollExtent);
                  }
                });

                final myUid = FirebaseAuth.instance.currentUser?.uid;

                return ListView.builder(
                  controller: _chatScrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderUid == myUid;

                    String displayText = msg.text;
                    if (msg.type == 'quick' && msg.phraseKey != null) {
                      displayText = msg.phraseKey!.tr();
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            Builder(
                              builder: (context) {
                                final hasAvatar =
                                    UserService.hasAvatar(msg.senderAvatar);
                                return CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF1E293B),
                                  backgroundImage: hasAvatar
                                      ? ResizeImage(
                                          AssetImage(UserService.getAvatarPath(
                                              msg.senderAvatar)),
                                          width: 48,
                                          height: 48,
                                        )
                                      : null,
                                  child: hasAvatar
                                      ? null
                                      : const Icon(Icons.person_rounded,
                                          size: 12, color: Colors.white70),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Container(
                              padding: msg.type == 'emoji'
                                  ? const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2)
                                  : const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: msg.type == 'emoji'
                                    ? Colors.transparent
                                    : isMe
                                        ? const Color(0xFF6366F1)
                                            .withValues(alpha: 0.85)
                                        : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: msg.type == 'emoji'
                                    ? null
                                    : Border.all(
                                        color: isMe
                                            ? const Color(0xFF818CF8)
                                                .withValues(alpha: 0.4)
                                            : Colors.white12,
                                      ),
                              ),
                              child: Text(
                                displayText,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: msg.type == 'emoji' ? 24 : 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Emojis Row
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                '😂',
                '🔥',
                '❤️',
                '😎',
                '👏',
                '🏆',
                '🤔',
                '⚡',
                '🚀',
                '😱'
              ].map((emoji) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _sendQuickMessage(text: emoji, type: 'emoji'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Quick Phrases Row (Translated in all languages!)
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                {'key': 'duel.chat.hello', 'text': 'Merhaba! 👋'},
                {
                  'key': 'duel.chat.increase_bet',
                  'text': 'Bahisi arttır! 🪙⬆️'
                },
                {'key': 'duel.chat.decrease_bet', 'text': 'Bahisi azalt! 🪙⬇️'},
                {
                  'key': 'duel.chat.increase_questions',
                  'text': 'Soru sayısını arttır! ❓⬆️'
                },
                {
                  'key': 'duel.chat.decrease_questions',
                  'text': 'Soru sayısını azalt! ❓⬇️'
                },
                {'key': 'duel.chat.ready', 'text': 'Ben hazırım! ⚡'},
                {'key': 'duel.chat.good_luck', 'text': 'Bol şans! 🍀'},
                {'key': 'duel.chat.start_game', 'text': 'Hadi başlayalım! 🚀'},
                {
                  'key': 'duel.chat.well_played',
                  'text': 'İyi olan kazansın! 🏆'
                },
              ].map((phrase) {
                final key = phrase['key']!;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _sendQuickMessage(
                        text: phrase['text']!, type: 'quick', phraseKey: key),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        key.tr(),
                        style: const TextStyle(
                          color: Color(0xFFC7D2FE),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Custom Text Input Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _chatTextController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'duel.type_message'.tr(),
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _handleSendCustomText(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _handleSendCustomText,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuickMessage(
      {required String text, required String type, String? phraseKey}) async {
    HapticFeedback.lightImpact();
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid ?? '';

    DuelPlayer? myPlayer;
    if (_currentRoom?.host.uid == myUid) {
      myPlayer = _currentRoom?.host;
    } else if (_currentRoom?.guest?.uid == myUid) {
      myPlayer = _currentRoom?.guest;
    }

    final username = myPlayer?.username ?? user?.displayName ?? 'Oyuncu';
    final avatar = myPlayer?.avatarIndex ?? '1';

    final msg = DuelChatMessage(
      id: '',
      senderUid: myUid,
      senderName: username,
      senderAvatar: avatar,
      text: text,
      type: type,
      phraseKey: phraseKey,
      createdAt: DateTime.now(),
    );

    await DuelService.sendRoomMessage(widget.roomCode, msg);
  }

  Future<void> _handleSendCustomText() async {
    final text = _chatTextController.text.trim();
    if (text.isEmpty) return;
    _chatTextController.clear();
    await _sendQuickMessage(text: text, type: 'text');
  }

  Widget _buildInsufficientTokensBanner(DuelRoom room) {
    final bet = room.config.betTokens;
    final bool hostNeeds = _userTokens < bet;
    final bool guestNeeds = room.guest != null && room.guest!.tokens < bet;

    String msg = '';
    if (hostNeeds && guestNeeds) {
      msg = 'duel.both_need_tokens'.tr(args: [bet.toString()]);
    } else if (hostNeeds) {
      msg = 'duel.you_need_tokens'.tr(args: [bet.toString()]);
    } else {
      msg = 'duel.guest_needs_tokens'.tr(args: [bet.toString()]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(DuelRoom room, bool canStart, bool isHost) {
    final bool isGuestPresent = room.guest != null;
    final bool isGuestReady = room.guest?.isReady == true;
    final bool hostWantsToStart = room.hostWantsToStart;

    if (isHost) {
      // Host Button States
      String buttonText = 'duel.start_duel_button'.tr();
      Color buttonColor = const Color(0xFFFF9F43);
      Color textColor = Colors.black;
      IconData buttonIcon = Icons.play_arrow_rounded;
      VoidCallback? onButtonTap;

      if (!isGuestPresent) {
        buttonText = 'duel.waiting_guest'.tr();
        onButtonTap = null;
      } else if (!isGuestReady) {
        if (hostWantsToStart) {
          buttonText = 'duel.start_when_guest_ready'.tr();
          buttonColor = const Color(0xFF6366F1);
          textColor = Colors.white;
          buttonIcon = Icons.hourglass_top_rounded;
          onButtonTap = () {
            HapticFeedback.lightImpact();
            DuelService.setHostWantsToStart(widget.roomCode,
                wantsToStart: false);
          };
        } else {
          buttonText = 'duel.start_duel_button'.tr();
          buttonColor = const Color(0xFFFF9F43);
          textColor = Colors.black;
          buttonIcon = Icons.play_arrow_rounded;
          onButtonTap = () {
            HapticFeedback.mediumImpact();
            DuelService.setHostWantsToStart(widget.roomCode,
                wantsToStart: true);
          };
        }
      } else {
        // Guest is ready!
        buttonText = 'duel.guest_is_ready_start'.tr();
        buttonColor = const Color(0xFF10B981);
        textColor = Colors.white;
        buttonIcon = Icons.rocket_launch_rounded;
        onButtonTap = canStart ? _handleStartGame : null;
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onButtonTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              disabledBackgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: onButtonTap != null ? 8 : 0,
              shadowColor: buttonColor.withValues(alpha: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  buttonIcon,
                  color: onButtonTap != null ? textColor : Colors.white38,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    buttonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onButtonTap != null ? textColor : Colors.white38,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Guest Button States (Ready / Not Ready Toggle)
      final bool amIReady = room.guest?.isReady == true;

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hostWantsToStart && !amIReady) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on_rounded,
                        color: Color(0xFFFFD56B), size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'duel.host_waiting_for_you'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD56B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  if (!amIReady) {
                    final hasInternet = await AppUtils.hasInternetConnection();
                    if (!hasInternet) {
                      _showToast('errors.no_internet_ai'.tr(), isError: true);
                      return;
                    }
                  }
                  DuelService.setPlayerReady(
                    widget.roomCode,
                    isHost: false,
                    isReady: !amIReady,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: amIReady
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFF9F43),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: (amIReady
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF9F43))
                      .withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      amIReady
                          ? Icons.check_circle_rounded
                          : Icons.flash_on_rounded,
                      color: amIReady ? Colors.white : Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amIReady
                          ? 'duel.ready_cancel'.tr()
                          : 'duel.im_ready'.tr(),
                      style: TextStyle(
                        color: amIReady ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
