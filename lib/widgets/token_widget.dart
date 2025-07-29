import 'package:flutter/material.dart';
import '../services/token_service.dart';
import '../screens/token_screen.dart';

class TokenWidget extends StatefulWidget {
  const TokenWidget({super.key});

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with TickerProviderStateMixin {
  int _tokenAmount = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTokenAmount();
  }

void _initAnimations() {
  _pulseController = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  )..repeat(reverse: true);

  _pulseAnimation = Tween<double>(
    begin: 1.0,
    end: 1.1,
  ).animate(CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeInOut,
  ));
}



  Future<void> _loadTokenAmount() async {
    final amount = await TokenService.getTokenAmount();
    if (mounted) {
      setState(() {
        _tokenAmount = amount;
      });
    }
  }

  void _showTokenScreen() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const TokenScreen(),
      ),
    )
        .then((_) {
      // Token ekranından döndüğünde token miktarını yenile
      _loadTokenAmount();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  return FutureBuilder<int>(
    future: TokenService.getTokenAmount(),
    builder: (context, snapshot) {
      int displayedAmount = snapshot.data ?? _tokenAmount;

      return GestureDetector(
        onTap: _showTokenScreen,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade600, Colors.orange.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '$displayedAmount', // HATA BURADAYDI, DÜZELTİLDİ
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black26,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}


  // Bu metodu ekleyin - dışarıdan token güncellemesi için
  Future<void> refreshTokens() async {
    await _loadTokenAmount();
  }
    }