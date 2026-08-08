import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/glass_container.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/notification_permission_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_utils.dart';
import '../main.dart'; // For QuizFlow

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool _isLoading = false;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    _checkOfflineOnboardingState();
  }

  Future<void> _checkOfflineOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasStarted = prefs.getBool('offline_onboarding_started') ?? false;
    if (hasStarted) {
      final hasInternet = await AppUtils.hasInternetConnection();
      if (!hasInternet && mounted) {
        final offlineTaken = prefs.getInt('offline_tests_taken') ?? 0;
        final isLimitReached = offlineTaken >= 3;
        
        final title = isLimitReached ? "Tebrikler! 🎉" : 'errors.no_internet_ai'.tr();
        final content = isLimitReached 
            ? "Harika! 3 adet çevrimdışı deneme testini tamamladınız. Artık internet bağlantınızı açın ve yapay zeka destekli sonsuz quizlerin tadını çıkarın! 🚀"
            : "Uygulamamızı çevrimdışı denediniz! Tam deneyim ve ilerlemenizin kaydedilmesi için lütfen internet bağlantınızı açın.";

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            content: Text(
              content,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkOfflineOnboardingState(); // Re-check when pressed
                },
                child: const Text('Tekrar Dene', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      } else {
        // If they have internet now, just let them pick a language and it will auto login,
        // or we could auto login them right here if locale is already set.
        // For simplicity, we just close the dialog if it was open, or do nothing.
      }
    }
  }

  final List<Map<String, dynamic>> _languages = [
    {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
  ];

  Future<void> _handleLanguageSelection(
      BuildContext context, String languageCode) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Setting language...';
    });

    // 1. Set Locale
    await context.setLocale(Locale(languageCode));

    // Update state to reflect language change (though we are navigating away)
    setState(() {
      _loadingMessage = 'auth.guest_login_loading'
          .tr(); // Ensure you have this key or use a generic one
    });

    try {
      // 2. Auto Guest Login
      final userCredential = await UserService.signInAsGuest();

      if (userCredential != null) {
        // 3. Schedule Notifications
        await _setupNotifications();

        // 4. Navigate to Category Screen (or QuizFlow)
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const QuizFlow(initialCategory: null),
            ),
            (route) => false,
          );
        }
      } else {
        if (!context.mounted) return;
        await _handleOfflineFallback(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      await _handleOfflineFallback(context);
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleOfflineFallback(BuildContext context) async {
    final hasInternet = await AppUtils.hasInternetConnection();
    if (!hasInternet) {
      final prefs = await SharedPreferences.getInstance();
      final offlineTaken = prefs.getInt('offline_tests_taken') ?? 0;
      
      if (offlineTaken >= 3) {
         _checkOfflineOnboardingState(); // Re-use the dialog method which handles limits
         return;
      }
      
      await prefs.setBool('offline_onboarding_started', true);
      
      await _setupNotifications();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const QuizFlow(
              initialCategory: 'Genel Kültür',
              initialDifficulty: 'Kolay',
              initialDuration: 30,
            ),
          ),
          (route) => false,
        );
      }
    } else {
      _showError('Guest login failed. Please try again.');
    }
  }

  Future<void> _setupNotifications() async {
    try {
      // Check permissions (might need UI interaction, so we do it carefully)
      // Since this is the first screen, we might want to ask for permission here
      // OR let the NotificationPermissionManager handle it if it has UI logic.
      // Based on previous code, it seems to show a dialog.
      if (context.mounted) {
        await NotificationPermissionManager.notificationPermissions(context);
      }

      // Reschedule/Plan notifications
      await NotificationService.rescheduleNotifications();
    } catch (e) {
      debugPrint("Notification setup error: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF0F172A)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Orbs if available, otherwise just gradient
          // const BackgroundOrbs(),

          SafeArea(
            child: Center(
              child: _isLoading
                  ? _buildLoadingState()
                  : _buildLanguageSelectionList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 20),
        Text(
          _loadingMessage ?? 'Loading...',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildLanguageSelectionList() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'app_logo',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ]),
              child: Image.asset(
                'lib/assets/emilekbul.png',
                width: 80,
                height: 80,
                errorBuilder: (c, o, s) =>
                    const Icon(Icons.language, size: 60, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Select Language / Dil Seçin',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen devam etmek için bir dil seçin\nPlease select a language to continue',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                return _buildLanguageCard(
                  lang['name'],
                  lang['flag'],
                  lang['code'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(String name, String flag, String code) {
    return GestureDetector(
      onTap: () => _handleLanguageSelection(context, code),
      child: GlassContainer(
        borderRadius: 20,
        opacity: 0.1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
