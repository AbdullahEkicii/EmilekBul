import '../widgets/discover_card.dart';
import '../widgets/themed_event_card.dart';
import '../features/home/widgets/home_action_buttons.dart';
import '../features/home/widgets/quests_panel.dart';
import '../theme/app_theme.dart';
import '../services/retention_engine.dart';
import '../widgets/daily_goal_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/whats_new_dialog.dart';
import '../services/whats_new_service.dart';
import '../services/analytics_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_screen.dart';
import 'token_screen.dart';
import '../main.dart';
import '../services/update_control.dart';
import '../services/startup_dialog_queue.dart';
import '../widgets/guest_link_prompt.dart';
import '../services/user_service.dart';
import '../services/token_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/background_orbs.dart';
import 'board_mode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_utils.dart';
import '../services/notification_service.dart';
import '../services/notification_permission_manager.dart';
import 'main_shell.dart';
import 'shop_screen.dart';
import '../widgets/language_selector_button.dart';
import 'language_selection_screen.dart';
import '../services/achievement_service.dart';
import '../services/streak_service.dart';
import '../services/cloud_state_service.dart';
import '../services/league_service.dart';
import 'league_result_screen.dart';
import '../widgets/quick_match_dialog.dart';
import 'league_screen.dart';
import 'daily_challenge_screen.dart';
import '../widgets/daily_streak_dialog.dart';
import '../widgets/streak_rescue_dialog.dart';
import '../widgets/lucky_wheel_dialog.dart';
import '../widgets/friend_race_dialog.dart';
import '../widgets/friends_dialog.dart';
import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../services/presence_service.dart';
import '../models/category_model.dart';
import '../constants/app_categories.dart';
import '../services/duel_invite_service.dart';
import 'package:emilekbul/services/haptic_service.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onStart;
  final bool skipLoading;
  const WelcomeScreen({
    super.key,
    required this.onStart,
    this.skipLoading = false,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _headerAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late AnimationController _onboardingController;
  late Animation<double> _pulsingAnimation;

  bool _showOnboardingGuide = false;

  User? currentUser;
  bool _isCheckingAuth = true;
  // Giriş yapmamış (çevrimdışı/zayıf ağ) yeni kullanıcı için arka planda misafir girişi yeniden denenir
  bool _hadUser = false;
  Timer? _guestRetryTimer;
  int _guestRetries = 0;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<FriendRequest>>? _friendRequestsSub;
  StreamSubscription<List<DuelInvite>>? _duelInvitesSub;
  StreamSubscription<List<PokeMessage>>? _pokesSub;
  final Set<String> _processedRequestIds = {};
  final Set<String> _processedInviteIds = {};
  final Set<String> _processedPokeIds = {};
  bool _isFirstRequestsLoad = true;
  bool _isFirstInvitesLoad = true;
  bool _hasUnseenAchievements = false;

  // Cached user data to avoid unnecessary Firestore refetches
  String? _cachedAvatarPath;
  int _cachedLevel = 1;
  bool _userDataLoaded = false;

  // Streak & Retention states
  int _streakCount = 0;
  bool _canClaimStreak = false;
  int _streakFreezes = 0;
  bool _playedToday = false;

  // Oturum başına en fazla 2 "bilgi" dialogu; bkz. StartupDialogQueue (öncelik sırası orada)
  League _league = LeagueService.leagues.first;
  bool _canSpinWheel = false;
  Stream<DocumentSnapshot>? _profileStream;
  Stream<int>? _requestsCountStream;

  Future<void> _checkConsecutiveLogin() async {
    try {
      final streakStatus = await StreakService.checkStreakStatus();
      final canSpin = await LuckyWheelDialog.canSpinToday();

      if (mounted) {
        setState(() {
          _streakCount = streakStatus['streak'] as int;
          _canClaimStreak = streakStatus['canClaimToday'] as bool;
          _streakFreezes = streakStatus['freezes'] as int;
          _playedToday = streakStatus['playedToday'] as bool;
          _canSpinWheel = canSpin;
        });

        // Seri bozulduysa (günde bir kez) kurtarma teklifi; sonrasında akış yeniden çalışır
        final rescueOffer = await StreakService.getPendingRescueOffer();
        if (rescueOffer != null && currentUser != null && mounted) {
          await StreakService.markRescueOfferShown();
          StartupDialogQueue.force(StartupDialogType.streakRescue);
          if (!mounted) return;
          await StreakRescueDialog.show(
            context,
            lostStreak: rescueOffer['streak']!,
            missedDays: rescueOffer['missed']!,
          );
          if (mounted) _checkConsecutiveLogin();
          return;
        }

        // Test çözülüp ödül açıldıysa her zaman göster; sadece hatırlatma ise oturum dialog sınırına uy
        final bool claimableNow = _canClaimStreak && _playedToday;
        bool showStreak = false;
        if (_canClaimStreak) {
          if (claimableNow) {
            StartupDialogQueue.force(StartupDialogType.dailyStreak);
            showStreak = true;
          } else {
            showStreak =
                StartupDialogQueue.tryClaim(StartupDialogType.dailyStreak);
          }
        }
        if (showStreak) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted && currentUser != null) {
              DailyStreakDialog.show(
                context,
                currentStreak: _streakCount,
                canClaimToday: _canClaimStreak,
                freezes: streakStatus['freezes'] as int,
                freezesUsed: streakStatus['freezesUsed'] as int,
                playedToday: _playedToday,
                onClaimed: () {
                  _checkConsecutiveLogin();
                  _loadUserData();
                },
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Streak check error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Animation controllers
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _onboardingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // Sadece onboarding rehberi görünürken çalışsın (boşuna frame üretmesin)
    if (_showOnboardingGuide) _onboardingController.repeat(reverse: true);

    _pulsingAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _onboardingController, curve: Curves.easeInOut),
    );

    // Animations
    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.elasticOut,
    ));

    // Auth kontrolü ve zorunlu giriş
    _checkAuthStateAndRedirect();
  }

  void _checkAuthStateAndRedirect() async {
    setState(() {
      _isCheckingAuth = !widget.skipLoading;
    });

    // Önce mevcut auth durumunu kontrol et
    currentUser = FirebaseAuth.instance.currentUser;

    // Auth başarılı ise kontrolleri paralel yap — ANR önleme
    if (currentUser != null) {
      // Streak/çark/görev durumunu buluttan geri yükle (kontrollerden önce)
      await CloudStateService.restore();

      // Tüm bağımsız kontrolleri paralel çalıştır
      await Future.wait([
        _checkAppUpdate(),
        _checkMonthlyWinner(),
        _checkConsecutiveLogin(),
        _loadUserData(),
        _checkLeague(),
      ]);

      // Check for first-time guest (depends on currentUser being set)
      // Kullanıcı hazır, ana ekran akışına devam et
    }

    // Kullanıcı giriş yapmışsa, update kontrolü yap ve animasyonları başlat
    setState(() {
      _isCheckingAuth = false;
    });

    if (currentUser != null) {
      // Bildirim izinlerini kontrol et ve planla (SADECE eski kullanıcılar için)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .get();
          final totalQuizzes = (userDoc.data())?['totalQuizzes'] as int? ?? 0;

          // Misafir hesap bağlama teklifi (kuyruk: aylık kazanandan sonra, bildirim izninden önce)
          _maybeOfferGuestLink(userDoc.data(), totalQuizzes);

          // Eğer hiç quiz çözmemişse (yeni kullanıcıysa) Loading ekranında izin İSTEME
          if (totalQuizzes > 0) {
            _checkNotifications();
          }
        } catch (e) {
          // Hata olursa yine de soralım (failsafe)
          _checkNotifications();
        }
      });
    }

    _hadUser = FirebaseAuth.instance.currentUser != null;
    AnalyticsService.logFirstSession(
        'welcome_shown', {'has_user': _hadUser ? 1 : 0});
    _maybeShowWhatsNew();
    RetentionEngine.onAppOpen();

    // Auth state changes listener
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          currentUser = user;
        });
        if (user != null) _hadUser = true;

        // Hiç giriş yapılamamış yeni kullanıcı (ağ yok/yavaş): dil listesine atma, arka planda yeniden dene
        if (user == null && !_hadUser) {
          _startGuestRetry();
          return;
        }

        // Eğer kullanıcı çıkış yaparsa, login ekranına yönlendir
        if (user == null) {
          setState(() {
            _isCheckingAuth = true;
          });

          // Hemen yönlendirme yap
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionScreen(),
              ),
            );
          }
        }
      }
    });

    // Animasyonlar giriş olmasa da başlar (çevrimdışı/zayıf ağdaki yeni kullanıcı boş ekran görmesin);
    // yalnızca sosyal dinleyiciler/presence giriş gerektirir.
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buttonAnimationController.forward();
      }
    });
    if (currentUser != null) {
      _initSocialListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = currentUser?.uid;
    if (uid == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Arka planda gereksiz Firestore okuma/dinleme yapma
      _friendRequestsSub?.cancel();
      _friendRequestsSub = null;
      _duelInvitesSub?.cancel();
      _duelInvitesSub = null;
      _pokesSub?.cancel();
      _pokesSub = null;
      PresenceService.stopPresence();
    } else if (state == AppLifecycleState.resumed) {
      // Sadece paused'da iptal edilmişse yeniden kur (çift abonelik olmasın)
      if (_friendRequestsSub == null && mounted) {
        PresenceService.startPresence();
        _startSocialStreams(uid);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guestRetryTimer?.cancel();
    _authSubscription?.cancel();
    _friendRequestsSub?.cancel();
    _duelInvitesSub?.cancel();
    _pokesSub?.cancel();
    _headerAnimationController.dispose();
    _buttonAnimationController.dispose();
    _onboardingController.dispose();
    PresenceService.stopPresence();
    super.dispose();
  }

  void _initSocialListeners() {
    final user = currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Çevrimiçi aktiflik durumunu başlat
    PresenceService.startPresence();

    // Eski askıda kalmış kullanıcı odalarını temizle
    FirebaseFirestore.instance
        .collection('duel_rooms')
        .where('hostUid', isEqualTo: uid)
        .where('status', isEqualTo: 'waiting')
        .get()
        .then((snapshot) {
      final now = DateTime.now();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        DateTime? lastActive;
        final raw = data['lastActivity'] ?? data['createdAt'];
        if (raw is Timestamp) {
          lastActive = raw.toDate();
        }
        if (lastActive == null || now.difference(lastActive).inMinutes >= 2) {
          doc.reference.update({
            'status': 'closed',
            'lastActivity': FieldValue.serverTimestamp(),
            'closeReason': 'app_restart_cleanup',
          }).catchError((_) {});
        }
      }
    }).catchError((_) {});

    _startSocialStreams(uid);
  }

  /// Sosyal Firestore dinleyicilerini (yeniden) kurar; önce eskileri iptal eder, çift abonelik olmaz.
  void _startSocialStreams(String uid) {
    // 1. Gelen Arkadaşlık İsteklerini Dinle
    _friendRequestsSub?.cancel();
    _friendRequestsSub =
        FriendService.streamIncomingRequests(uid).listen((requests) {
      if (_isFirstRequestsLoad) {
        _isFirstRequestsLoad = false;
        for (final req in requests) {
          _processedRequestIds.add(req.id);
        }
        return;
      }

      for (final req in requests) {
        if (!_processedRequestIds.contains(req.id)) {
          _processedRequestIds.add(req.id);
          NotificationService.showInstantNotification(
            id: 1000 + req.id.hashCode % 1000,
            title: 'friends.friend_req_received_title'.tr(),
            body:
                'friends.friend_req_received_body'.tr(args: [req.fromUsername]),
          );
        }
      }
    });

    // 2. Gelen 1v1 Düello Davetlerini Dinle
    _duelInvitesSub?.cancel();
    _duelInvitesSub =
        DuelInviteService.streamIncomingInvites(uid).listen((invites) {
      if (_isFirstInvitesLoad) {
        _isFirstInvitesLoad = false;
        for (final inv in invites) {
          _processedInviteIds.add(inv.id);
        }
        // Uygulama kapalıyken gelen, hâlâ geçerli olabilecek en yeni daveti göster (oda ~2 dk açık kalır)
        final fresh = invites
            .where((inv) =>
                inv.status == 'pending' &&
                DateTime.now().difference(inv.createdAt).inMinutes < 3)
            .toList();
        if (fresh.isNotEmpty && mounted) {
          _showDuelInviteModal(fresh.first);
        }
        return;
      }

      for (final inv in invites) {
        if (!_processedInviteIds.contains(inv.id) && inv.status == 'pending') {
          _processedInviteIds.add(inv.id);
          NotificationService.showInstantNotification(
            id: 2000 + inv.id.hashCode % 1000,
            title: 'duel.invite_received_title'.tr(),
            body: 'duel.invite_received_body'.tr(args: [inv.fromUsername]),
          );

          if (mounted) {
            _showDuelInviteModal(inv);
          }
        }
      }
    });

    // 3. Gelen Dürtmeleri (Poke) Dinle
    _pokesSub?.cancel();
    _pokesSub = DuelInviteService.streamIncomingPokes(uid).listen((pokes) {
      for (final poke in pokes) {
        if (!_processedPokeIds.contains(poke.id)) {
          _processedPokeIds.add(poke.id);
          NotificationService.showInstantNotification(
            id: 3000 + poke.id.hashCode % 1000,
            title: 'friends.poke_received_title'.tr(),
            body: 'friends.poke_received_body'.tr(args: [poke.fromUsername]),
          );

          // Dürtme bildirimi verildikten sonra temizle
          DuelInviteService.deletePoke(uid, poke.id);
        }
      }
    });
  }

  void _showDuelInviteModal(DuelInvite invite) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheetCtx) => GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF334155),
                  backgroundImage: ResizeImage(
                    AssetImage(UserService.getAvatarPath(invite.fromAvatar)),
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'duel.invite_received_title'.tr(),
                        style: const TextStyle(
                            color: Color(0xFFFFD56B),
                            fontWeight: FontWeight.w900,
                            fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppUtils.localizeUsername(invite.fromUsername),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('duel.category'.tr(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final allCats = [
                          ...AppCategories.categories,
                          ...AppCategories.bonusPoolCategories
                              .whereType<CategoryItem>()
                        ];
                        final cat = allCats.firstWhere(
                          (c) => c.name == invite.category,
                          orElse: () => allCats.first,
                        );
                        return Text(cat.key.tr(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13));
                      }),
                    ],
                  ),
                  Column(
                    children: [
                      Text('duel.difficulty'.tr(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(AppUtils.localizeDifficulty(invite.difficulty),
                          style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('duel.bet_amount'.tr(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Image.asset('lib/assets/coin.png',
                              width: 14, height: 14),
                          const SizedBox(width: 4),
                          Text('${invite.betTokens}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD56B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await DuelInviteService.respondToInvite(
                        myUid: currentUser!.uid,
                        inviteId: invite.id,
                        accept: false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('duel.reject_invite'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await DuelInviteService.respondToInvite(
                        myUid: currentUser!.uid,
                        inviteId: invite.id,
                        accept: true,
                      );
                      if (mounted) {
                        FriendRaceEntryDialog.show(context,
                            joinRoomCode: invite.roomCode);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('duel.accept_invite'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    await TokenService.getTokenAmount();
    if (currentUser == null) return;
    try {
      final avatarIndex =
          await UserService.getAvatarIndexFromCurrentUser(currentUser);
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      final data = userDoc.data();
      if (data != null) {
        final remoteTokens = (data['tokens'] as num?)?.toInt();
        if (remoteTokens != null) {
          await TokenService.updateTokenAmount(remoteTokens, syncRemote: false);
        }
        final referralCount = (data['referralCount'] as num?)?.toInt() ?? 0;
        if (referralCount > 0 && mounted) {
          await AchievementService.checkAndUnlockReferralAchievements(
              referralCount, context);
        }
      }
      final hasUnseen = await AchievementService.hasUnseenAchievements();
      if (mounted) {
        setState(() {
          _cachedAvatarPath =
              (avatarIndex != null && UserService.hasAvatar(avatarIndex))
                  ? UserService.getAvatarPath(avatarIndex)
                  : null;
          if (_cachedAvatarPath != null && _cachedAvatarPath!.isEmpty) {
            _cachedAvatarPath = null;
          }
          _cachedLevel = data?['level'] ?? 1;
          _hasUnseenAchievements = hasUnseen;
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      // Silently handle — fallback to default icon
    }
  }

  Widget _buildAuthButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              HapticService.light();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountScreen(),
                ),
              );
              if (mounted) {
                _loadUserData(); // Refresh cached data after returning
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _cachedAvatarPath != null
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey.shade300,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    _cachedAvatarPath!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 16,
                                      );
                                    },
                                  ),
                                ),
                              )
                            : const Icon(Icons.person,
                                color: Colors.white, size: 16),
                        if (_hasUnseenAchievements)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'welcome_screen.my_account'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_userDataLoaded)
                        Text(
                          '${'level_system.level'.tr()} $_cachedLevel',
                          style: TextStyle(
                            color: Colors.amber.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkLeague() async {
    final result = await LeagueService.evaluateWeekIfNeeded();
    final league = await LeagueService.getMyLeague();
    if (!mounted) return;
    setState(() => _league = league);
    if (result == null || result.outcome == LeagueOutcome.stayed) return;

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      // Başka bir diyalog bu oturumda zaten gösterildiyse sonucu atlamak yerine sonraki açılışa bırakma: sadece sade bildirim
      if (!StartupDialogQueue.tryClaim(StartupDialogType.leagueResult)) {
        final promoted = result.outcome == LeagueOutcome.promoted;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              promoted
                  ? 'league.promoted_desc'.tr(
                      args: [result.to.titleKey.tr(), result.reward.toString()])
                  : 'league.demoted_desc'.tr(args: [result.to.titleKey.tr()]),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LeagueResultScreen(result: result)));
    });
  }

  Widget _buildLeagueChip() {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        if (!MainShell.selectTabOf(context, 2)) {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LeagueScreen()));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _league.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _league.color.withValues(alpha: 0.55)),
        ),
        child: Text(_league.emoji, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildStreakChip() {
    return GestureDetector(
      onTap: () {
        DailyStreakDialog.show(
          context,
          currentStreak: _streakCount,
          canClaimToday: _canClaimStreak,
          freezes: _streakFreezes,
          playedToday: _playedToday,
          onClaimed: () {
            _checkConsecutiveLogin();
            _loadUserData();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$_streakCount',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenChip() {
    final uid = currentUser?.uid;
    return GestureDetector(
      onTap: () async {
        HapticService.light();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TokenScreen(),
          ),
        );
        if (mounted) {
          _loadUserData();
        }
      },
      child: ValueListenableBuilder<int>(
        valueListenable: TokenService.balanceNotifier,
        builder: (context, localTokens, _) => StreamBuilder<DocumentSnapshot>(
          stream: uid != null
              ? (_profileStream ??= UserService.getUserProfileStream(uid))
              : null,
          builder: (context, snapshot) {
            int tokens = localTokens;
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final remoteTokens = (data?['tokens'] as num?)?.toInt();
              if (remoteTokens != null) {
                tokens = remoteTokens;
              }
            }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.amber.withValues(alpha: 0.24),
                  AppColors.surfaceElevated.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(
                  '$tokens',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.amber.shade200,
                  size: 13,
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildWheelChip() {
    return GestureDetector(
      onTap: () {
        LuckyWheelDialog.show(
          context,
          onSpinCompleted: () {
            _checkConsecutiveLogin();
            _loadUserData();
          },
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎡', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
          if (_canSpinWheel)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFriendsChip() {
    final uid = currentUser?.uid;
    return GestureDetector(
      onTap: () {
        HapticService.light();
        FriendsDialog.show(context);
      },
      child: StreamBuilder<int>(
        stream: uid != null
            ? (_requestsCountStream ??=
                FriendService.streamIncomingRequestsCount(uid))
            : null,
        builder: (context, snapshot) {
          final pendingCount = snapshot.data ?? 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('👥', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              if (pendingCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '$pendingCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturedDailyCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.22),
            AppColors.surfaceElevated.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticService.light();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const DailyChallengeScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎯', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'daily_challenge.title'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'daily_challenge.badge'.tr(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'daily_challenge.card_sub'.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.amber, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Çarpanlı tahta modu girişi (yerel, tek oyunculu).
  Widget _buildBoardModeCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.20),
            AppColors.success.withValues(alpha: 0.14),
            AppColors.surfaceElevated.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.42)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticService.light();
            BoardModeScreen.open(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.grid_3x3_rounded,
                    color: Colors.tealAccent, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'board_mode.title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'board_mode.subtitle'.tr(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.tealAccent, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.airyBackgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating Logo
              Hero(
                tag: 'app_logo',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'lib/assets/app_icon.png',
                    width: 120,
                    height: 120,
                    cacheWidth: 360, // 120 * 3 for retina/high-density
                    cacheHeight: 360,
                  ),
                ),
              ),
              const SizedBox(height: 34),

              // App Title
              Text(
                'app_title'.tr(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Modern Loading indicator
              Column(
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFE6A141)),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'welcome.loading'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Logo ve diğer varlıkları önbelleğe al
    precacheImage(const AssetImage('lib/assets/app_icon.png'), context);
  }

  Future<void> _checkNotifications() async {
    try {
      if (!mounted) return;
      // Önce izin kontrolü (Kullanıcıya dialog gösterebilir); bu oturumda başka dialog çıktıysa atla
      // En düşük öncelik: diğer pencerelerin yer ayırmasını bekle
      await Future.delayed(const Duration(milliseconds: 3000));
      if (!mounted) return;
      final quiet = await _waitForQuietScreen();
      if (!mounted) return;
      if (quiet &&
          StartupDialogQueue.tryClaim(
              StartupDialogType.notificationPermission)) {
        await NotificationPermissionManager.notificationPermissions(context);
      }

      // Bildirim planlama işini arka planda, sessizce yapalım (beklemiyoruz)
      NotificationService.refreshWinBackNotifications().catchError((e) {
        debugPrint("Win-back planlama hatası: $e");
      });
      NotificationService.rescheduleNotifications().catchError((e) {
        debugPrint("Arkaplan planlama hatası: $e");
      });
    } catch (e) {
      debugPrint("Bildirim izni hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    Localizations.maybeLocaleOf(context);
    if (_isCheckingAuth) {
      return _buildLoadingScreen();
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.backgroundTop,
      body: Stack(
        children: [
          // Ferah gökyüzü-safir arka plan gradyanı
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.airyBackgroundGradient,
            ),
          ),

          // Üstten gelen yumuşak gün ışığı ve gökyüzü aydınlığı
          Positioned(
            top: -190,
            left: -170,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFDE68A).withValues(alpha: 0.18),
                    const Color(0xFF7DD3FC).withValues(alpha: 0.08),
                    const Color(0xFF7DD3FC).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Floating Orbs
          const BackgroundOrbs(),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LanguageSelectorButton(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStreakChip(),
                              const SizedBox(width: 8),
                              _buildLeagueChip(),
                              const SizedBox(width: 8),
                              _buildFriendsChip(),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildAuthButton(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTokenChip(),
                              const SizedBox(width: 8),
                              _buildWheelChip(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                          // Logo Section (kompakt üst alan: içerik ve günlük hedef ilk ekranda görünür kalır)
                          SlideTransition(
                            position: _headerSlideAnimation,
                            child: FadeTransition(
                              opacity: _headerFadeAnimation,
                              child: Hero(
                                tag: 'app_logo',
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        blurRadius: 32,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'lib/assets/app_icon.png',
                                    width: 84,
                                    height: 84,
                                    cacheWidth: 252,
                                    cacheHeight: 252,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Title Section
                          SlideTransition(
                            position: _headerSlideAnimation,
                            child: FadeTransition(
                              opacity: _headerFadeAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    'app_title'.tr(),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GlassContainer(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    borderRadius: 30,
                                    opacity: 0.1,
                                    child: Text(
                                      'welcome_screen.app_subtitle'.tr(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Main Actions
                          ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  if (_showOnboardingGuide)
                                    FadeTransition(
                                      opacity: _headerFadeAnimation,
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons
                                                .keyboard_double_arrow_down_rounded,
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE6A141)
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              'welcome.onboarding_tip'.tr(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  AnimatedBuilder(
                                    animation: _pulsingAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _showOnboardingGuide
                                            ? _pulsingAnimation.value
                                            : 1.0,
                                        child: child,
                                      );
                                    },
                                    child: StartButton(
                                      onPressed: widget.onStart,
                                      onPressedd:
                                          (category, difficulty, duration,
                                              {bool isDuel = false}) async {
                                        final navigator = Navigator.of(context);
                                        final prefs = await SharedPreferences
                                            .getInstance();

                                        if (_showOnboardingGuide) {
                                          if (mounted) {
                                            setState(() =>
                                                _showOnboardingGuide = false);
                                          }
                                          await prefs.setBool(
                                              'has_seen_onboarding_v2', true);
                                        }
                                        navigator.pushReplacement(
                                          MaterialPageRoute(
                                            builder: (context) => QuizFlow(
                                              initialCategory: category,
                                              initialDifficulty: difficulty,
                                              initialDuration: duration,
                                            ),
                                          ),
                                        );
                                      },
                                      text: 'welcome.start_button'.tr(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  QuickMatchButton(
                                    onTap: () => QuickMatchDialog.show(context),
                                  ),
                                  const SizedBox(height: 10),
                                  FriendRaceButton(
                                    onTap: () =>
                                        FriendRaceEntryDialog.show(context),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: BasariButton(
                                              onStart: widget.onStart)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: TierListButton(
                                              onPressed: widget.onStart)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildShopButton(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Retention & Daily Loop (doğrudan görünür)
                          ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  DailyGoalCard(onTokensChanged: _loadUserData),
                                  const SizedBox(height: 12),
                                  ThemedEventCard(
                                    onTap: (event) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => QuizFlow(
                                            initialCategory: event.categoryName,
                                            initialDifficulty: 'Orta',
                                            initialDuration: 30,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFeaturedDailyCard(),
                                  const SizedBox(height: 12),
                                  _buildBoardModeCard(),
                                  const SizedBox(height: 12),
                                  DiscoverCard(),
                                  const SizedBox(height: 12),
                                  QuestsPanel(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 118),
                        ],
                      ),
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mağaza kısayolu — ana ekranda My Tests ve Leaderboard ile birlikte doğrudan görünür.

  /// Güncelleme sonrası ilk açılışta (yeni kurulumda değil) "Yenilikler" penceresini bir kez gösterir.
  Future<void> _maybeShowWhatsNew() async {
    try {
      final version = await WhatsNewService.pendingVersion();
      if (version == null) return;
      await Future.delayed(const Duration(milliseconds: 3600));
      if (!await _waitForQuietScreen() || !mounted) return;
      if (!StartupDialogQueue.tryClaim(StartupDialogType.whatsNew)) return;
      await WhatsNewService.markSeen(version);
      if (!mounted) return;
      AnalyticsService.logCustomEvent(
          name: 'whats_new_shown', parameters: {'version': version});
      await WhatsNewDialog.show(context, version);
    } catch (e) {
      debugPrint('Whats new error: $e');
    }
  }

  /// Çevrimdışı/zayıf ağda açılan yeni kullanıcı için: bilgi ver, misafir girişini artan aralıklarla yeniden dene.
  void _startGuestRetry() {
    if (_guestRetryTimer != null) return;
    AnalyticsService.logFirstSession(
        'welcome_offline', {'retries': _guestRetries});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.offline_mode'.tr()),
          duration: const Duration(seconds: 6),
        ),
      );
    });
    _scheduleGuestRetry();
  }

  void _scheduleGuestRetry() {
    final delay = Duration(seconds: (15 * (_guestRetries + 1)).clamp(15, 60));
    _guestRetryTimer = Timer(delay, () async {
      _guestRetryTimer = null;
      if (!mounted || FirebaseAuth.instance.currentUser != null) return;
      _guestRetries++;
      final cred = await UserService.signInAsGuest();
      if (!mounted) return;
      if (cred != null) {
        AnalyticsService.logFirstSession(
            'guest_retry_ok', {'retries': _guestRetries});
        _resumeAfterGuestLogin();
      } else if (_guestRetries < 8) {
        _scheduleGuestRetry();
      }
    });
  }

  /// Giriş sonradan başarılı oldu: ana ekran görünür olunca akışı kullanıcıyla yeniden başlat
  /// (profil, seri ve sosyal dinleyiciler). Kullanıcı başka sayfadaysa bekler.
  void _resumeAfterGuestLogin() {
    _guestRetryTimer = Timer(const Duration(seconds: 2), () {
      _guestRetryTimer = null;
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const QuizFlow()),
          (route) => false,
        );
      } else {
        _resumeAfterGuestLogin();
      }
    });
  }

  /// Ana ekranın üstünde başka bir pencere/sayfa yoksa true döner; açıksa kapanmasını
  /// (en fazla ~20 sn) bekler. Hâlâ doluysa false: düşük öncelikli pencere bu oturumda atlanır.
  Future<bool> _waitForQuietScreen() async {
    for (var i = 0; i < 40; i++) {
      if (!mounted) return false;
      if (ModalRoute.of(context)?.isCurrent ?? false) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> _maybeOfferGuestLink(
      Map<String, dynamic>? profile, int totalQuizzes) async {
    try {
      final user = currentUser;
      if (user == null || !user.isAnonymous) return;
      final p = profile ?? const <String, dynamic>{};
      final linked = (p['email'] ?? '').toString().isNotEmpty ||
          (p['googleId'] ?? '').toString().isNotEmpty ||
          (p['playGamesId'] ?? '').toString().isNotEmpty;
      if (linked) return;
      final trigger = await GuestLinkPrompt.pendingTrigger(totalQuizzes);
      if (trigger == null) return;
      await Future.delayed(const Duration(milliseconds: 2200));
      // Başka bir pencere açıksa üst üste binmesin: ekran sakinleşene kadar bekle, olmazsa bu oturumda sorma
      if (!await _waitForQuietScreen() || !mounted) return;
      if (!StartupDialogQueue.tryClaim(StartupDialogType.guestLink)) return;
      await GuestLinkPrompt.show(context, trigger);
    } catch (e) {
      debugPrint('Guest link offer error: $e');
    }
  }

  Future<void> _checkAppUpdate() async {
    await checkUpdate(context);
  }

  Future<void> _checkMonthlyWinner() async {
    try {
      final now = DateTime.now();
      // Her ayın ilk 3 günü kontrol et
      if (now.day <= 3) {
        final prevMonthDate = DateTime(now.year, now.month - 1);
        final yearMonth =
            "${prevMonthDate.year}_${prevMonthDate.month.toString().padLeft(2, '0')}";

        // 1. Kazanan Henüz Belirlenmediyse (Sadece database'e kaydetme işlemi)
        Map<String, dynamic>? winnerData =
            await UserService.getMonthlyWinnerData(yearMonth);

        if (winnerData == null) {
          // Geçen ayın en yüksek puanını alan kişiyi bul (Artık monthly_scores koleksiyonundan)
          // NOT: Bu metodun UserService'e eklenmesi gerekebilir veya manuel sorgu
          // Şimdilik getTopUser metodunun önceki ay parametresini alacak şekilde güncellenmesi lazım
          // Ancak UserService'i karmaşıklaştırmamak için basit bir sorgu yapalım.

          final prevMonthRef = FirebaseFirestore.instance
              .collection('monthly_scores')
              .doc(yearMonth)
              .collection('scores');

          final querySnapshot = await prevMonthRef
              .orderBy('totalPoints', descending: true)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final topUserDoc = querySnapshot.docs.first;
            final topUserData = topUserDoc.data();

            // Lideri kaydet
            await UserService.recordMonthlyWinner(yearMonth, {
              'uid': topUserData['uid'] ?? topUserDoc.id,
              'username': topUserData['username'] ?? 'Bilinmeyen',
              'score': topUserData['totalPoints'] ?? 0,
              'avatarIndex': topUserData['avatarIndex'] ?? '0',
            });

            // Ödülü ver
            await UserService.giveReward(
                topUserData['uid'] ?? topUserDoc.id, 500);
          }
        }

        // 2. Kullanıcıya Göster (Eğer kazanan bu kullanıcıysa veya sadece bilgi vermek istiyorsanız)
        // Burada logic aynı kalabilir, sadece scoresReset kontrolüne gerek yok.
        final winner = await UserService.getLastMonthWinner();
        if (winner != null && winner['month'] == yearMonth) {
          final prefs = await SharedPreferences.getInstance();
          final hasSeen = prefs.getBool('seen_winner_$yearMonth') ?? false;

          // Eğer henüz görmediyse göster
          if (!hasSeen && mounted) {
            Future.delayed(const Duration(milliseconds: 1600), () {
              if (!mounted ||
                  !StartupDialogQueue.tryClaim(StartupDialogType.monthlyWinner)) {
                return;
              }
              _showWinnerDialog(winner);
              // Bir kere gösterdikten sonra işaretle
              prefs.setBool('seen_winner_$yearMonth', true);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Monthly winner check error: $e');
    }
  }

  Widget _buildShopButton() {
    return GlassContainer(
      opacity: 0.12,
      blur: 10,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticService.light();
          if (!MainShell.selectTabOf(context, 3)) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopScreen()),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.shopping_bag_rounded,
                  color: Colors.amber, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'welcome_screen.shop'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWinnerDialog(Map<String, dynamic> winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'welcome_screen.month_champion'.tr(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'welcome_screen.chamption_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 24),
              Text(
                AppUtils.localizeUsername(winner['username']),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${winner['score']} ${'welcome_screen.points'.tr()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+500 ${'welcome_screen.token_earned'.tr()}',
                      style: const TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('welcome_screen.congrats'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
