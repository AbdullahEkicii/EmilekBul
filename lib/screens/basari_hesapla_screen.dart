import 'package:flutter/material.dart';
import 'package:emilekbul/services/database_helper.dart';
import 'package:emilekbul/screens/welcome_screen.dart';
import 'package:emilekbul/screens/past_tests_screen.dart';
import '../widgets/my_native_ad.dart';

class BasariHesaplaScreen extends StatefulWidget {
  final VoidCallback onStart;
  const BasariHesaplaScreen({super.key, required this.onStart});

  @override
  State<BasariHesaplaScreen> createState() => _BasariHesaplaScreenState();
}

class _BasariHesaplaScreenState extends State<BasariHesaplaScreen>
    with TickerProviderStateMixin {
  Map<String, Map<String, int>> _categoryStats = {};
  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStats());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await DatabaseHelper.instance.getCategoryStatsFromTests();
      if (mounted) {
        setState(() {
          _categoryStats = stats;
          _loading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veriler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F7CFF), Color(0xFFA67BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _loading
                        ? _buildLoadingState()
                        : _categoryStats.isEmpty
                            ? _buildEmptyState()
                            : _buildStatsList(),
                  ),
                  // Native Ad - Detaylı İncele butonunun üstüne eklendi
                 // Padding(
                   // padding: const EdgeInsets.symmetric(horizontal: 20),
                   // child: MyNativeAd(),
                 // ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7F7CFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(
                          Icons.analytics_outlined,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Detaylı İncele',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const PastTestsScreen(),
                              transitionsBuilder: (
                                context,
                                animation,
                                secondaryAnimation,
                                child,
                              ) {
                                return SlideTransition(
                                  position: animation.drive(
                                    Tween(
                                      begin: const Offset(1.0, 0.0),
                                      end: Offset.zero,
                                    ).chain(
                                      CurveTween(
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                  ),
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Başarı İstatistikleri',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kategori bazında performansınızı görüntüleyin',
            style: TextStyle(fontSize: 16, color: Colors.grey[900]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F7CFF)),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'İstatistikler yükleniyor...',
            style: TextStyle(color: Color(0xFF718096), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7F7CFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Color(0xFF7F7CFF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Henüz Test Çözülmedi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'İlk testinizi çözdükten sonra\nistatistiklerinizi burada görebilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _categoryStats.length,
        itemBuilder: (context, index) {
          final entry = _categoryStats.entries.elementAt(index);
          return _buildCategoryCard(entry, index);
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    MapEntry<String, Map<String, int>> entry,
    int index,
  ) {
    final category = entry.key;
    final correct = entry.value['correct'] ?? 0;
    final wrong = entry.value['wrong'] ?? 0;
    final total = correct + wrong;
    final successRate = total > 0 ? (correct / total) : 0.0;
    final percent = (successRate * 100).toStringAsFixed(1);

    return Container(
      margin: EdgeInsets.only(bottom: 16, top: index == 0 ? 8 : 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFF7F7CFF).withOpacity(0.1),
            width: 1,
          ),
        ),
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, const Color(0xFF7F7CFF).withOpacity(0.02)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryHeader(category, successRate),
                const SizedBox(height: 20),
                _buildProgressBar(successRate),
                const SizedBox(height: 20),
                _buildStatsRow(correct, wrong, percent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String category, double successRate) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getSuccessColor(successRate).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(category),
            color: _getSuccessColor(successRate),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getSuccessMessage(successRate),
                style: TextStyle(
                  fontSize: 14,
                  color: _getSuccessColor(successRate),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double successRate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Başarı Oranı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF718096),
              ),
            ),
            Text(
              '${(successRate * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getSuccessColor(successRate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: successRate,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getSuccessColor(successRate),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int correct, int wrong, String percent) {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            'Doğru',
            correct.toString(),
            const Color(0xFF10B981),
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatBox(
            'Yanlış',
            wrong.toString(),
            const Color(0xFFEF4444),
            Icons.cancel_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatBox(
            'Toplam',
            (correct + wrong).toString(),
            const Color(0xFF7F7CFF),
            Icons.quiz_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 18,
      left: 12,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => WelcomeScreen(onStart: widget.onStart),
            ),
            (route) => false,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Color _getSuccessColor(double successRate) {
    if (successRate >= 0.8) return const Color(0xFF10B981); // Yeşil
    if (successRate >= 0.6) return const Color(0xFFF59E0B); // Turuncu
    return const Color(0xFFEF4444); // Kırmızı
  }

  String _getSuccessMessage(double successRate) {
    if (successRate >= 0.8) return 'Bu konuda bilgilisin!';
    if (successRate >= 0.6) return 'Başarılı';
    if (successRate >= 0.4) return 'Gelişim Alanı Var';
    return 'Başka kategori tercih edebilirsin';
  }

  IconData _getCategoryIcon(String category) {
    // Kategori adına göre icon döndürün
    switch (category.toLowerCase()) {
      case 'matematik':
        return Icons.calculate_outlined;
      case 'fen':
        return Icons.science_outlined;
      case 'tarih':
        return Icons.history_edu_outlined;
      case 'türkçe':
        return Icons.menu_book_outlined;
      case 'coğrafya':
        return Icons.public_outlined;
      case 'İngilizce':
        return Icons.language_outlined;
      default:
        return Icons.quiz_outlined;
    }
  }
}
