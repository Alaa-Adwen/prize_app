import 'package:flutter/material.dart';
import 'package:kaharamana/screens/final_draw_screen.dart';
import 'dart:math' as math;
import 'registration_screen.dart';
import 'customer_data_screen.dart';
import 'daily_draw_screen.dart';

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({Key? key}) : super(key: key);

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen>
    with TickerProviderStateMixin {
  late AnimationController _starsController;
  late AnimationController _crescentController;
  late AnimationController _buttonsController;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _crescentController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _buttonsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _starsController.dispose();
    _crescentController.dispose();
    _buttonsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ramadan_bg.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(
                  0.3,
                ), // Dark overlay for better text visibility
                BlendMode.darken,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Dark gradient overlay for better contrast
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0F0528).withOpacity(0.7),
                      Color(0xFF1A0A3E).withOpacity(0.5),
                      Color(0xFF2D1B69).withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              // Animated background stars
              _buildAnimatedStars(),
              // Islamic pattern overlay
              _buildIslamicPattern(),
              // Main content
              SafeArea(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).top -
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              SizedBox(height: 30),
                              // Logo Section with Stars and Crescent
                              _buildLogoSection(),
                              SizedBox(height: 35),
                              // Buttons Section
                              _buildAnimatedButton(
                                0,
                                'التسجيل',
                                Icons.person_add,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegistrationScreen(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 16),
                              _buildAnimatedButton(
                                1,
                                'السحب اليومي',
                                Icons.calendar_today,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DailyDrawScreen(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 16),
                              _buildAnimatedButton(
                                2,
                                'السحب النهائي',
                                Icons.calendar_month,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FinalDrawScreen(),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 16),
                              _buildAnimatedButton(
                                3,
                                'بيانات المسجلين',
                                Icons.list_alt,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CustomerDataScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          // Decorative Islamic Pattern pinned to bottom
                          Padding(
                            padding: const EdgeInsets.only(bottom: 30),
                            child: _buildDecorativePattern(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStars() {
    return AnimatedBuilder(
      animation: _starsController,
      builder: (context, child) {
        return CustomPaint(
          painter: StarsPainter(_starsController.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildIslamicPattern() {
    return Opacity(
      opacity: 0.05,
      child: CustomPaint(painter: IslamicPatternPainter(), size: Size.infinite),
    );
  }

  Widget _buildLogoSection() {
    return FadeTransition(
      opacity: _crescentController,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, -0.5), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _crescentController,
                curve: Curves.elasticOut,
              ),
            ),
        child: Column(
          children: [
            // Crescent and Star with advanced animation
            Stack(
              alignment: Alignment.center,
              children: [
                // Multiple glow layers
                AnimatedBuilder(
                  animation: _starsController,
                  builder: (context, child) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(
                              0xFFFFD700,
                            ).withOpacity(0.3 + _starsController.value * 0.2),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                          BoxShadow(
                            color: Color(0xFFFF8C00).withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Rotating ring
                AnimatedBuilder(
                  animation: _starsController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _starsController.value * 2 * math.pi,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFFFFD700).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Crescent with shimmer
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFE55C),
                        Color(0xFFFFD700),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds);
                  },
                  child: Icon(Icons.nightlight, size: 90, color: Colors.white),
                ),
                // Animated star
                AnimatedBuilder(
                  animation: _starsController,
                  builder: (context, child) {
                    return Positioned(
                      right: 30,
                      top: 20,
                      child: Transform.rotate(
                        angle: _starsController.value * math.pi,
                        child: Icon(
                          Icons.star,
                          size: 35,
                          color: Color(0xFFFFD700),
                          shadows: [
                            Shadow(color: Color(0xFFFFD700), blurRadius: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            // Logo Text with enhanced styling
            Container(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  width: 2,
                  color: Color(0xFFFFD700).withOpacity(0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFFD700).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFE55C),
                      Color(0xFFFFD700),
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  'مركز كهرمانة',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(
                        color: Color(0xFFFFD700).withOpacity(0.8),
                        blurRadius: 15,
                      ),
                      Shadow(
                        color: Color(0xFFFF8C00).withOpacity(0.5),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Subtitle - Fixed letter spacing for connected Arabic
            Text(
              'رمضان كريم',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFFFFD700).withOpacity(0.7),
                letterSpacing: 0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedButton(
    int index,
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: Offset(1.5, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _buttonsController,
          curve: Interval(
            index * 0.25,
            (index * 0.25 + 0.6).clamp(0.0, 1.0),
            curve: Curves.elasticOut,
          ),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _buttonsController,
            curve: Interval(index * 0.25, (index * 0.25 + 0.6).clamp(0.0, 1.0)),
          ),
        ),
        child: Container(
          width: double.infinity,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB800), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFFD700).withOpacity(0.5),
                blurRadius: 20,
                offset: Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Color(0xFFFFA500).withOpacity(0.3),
                blurRadius: 30,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(25),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A0A3E).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Color(0xFF1A0A3E), size: 26),
                    ),
                    SizedBox(width: 16),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A0A3E),
                        letterSpacing: 0,
                        shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorativePattern() {
    return AnimatedBuilder(
      animation: _starsController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.6 + (_starsController.value * 0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOrnament(),
              SizedBox(width: 12),
              _buildDecorativeLine(true),
              SizedBox(width: 16),
              Icon(
                Icons.mosque,
                color: Color(0xFFFFD700).withOpacity(0.8),
                size: 40,
                shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 20)],
              ),
              SizedBox(width: 16),
              _buildDecorativeLine(false),
              SizedBox(width: 12),
              _buildOrnament(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrnament() {
    return Column(
      children: [
        Icon(Icons.star, color: Color(0xFFFFD700).withOpacity(0.7), size: 16),
        SizedBox(height: 4),
        Icon(Icons.star, color: Color(0xFFFFD700).withOpacity(0.5), size: 12),
      ],
    );
  }

  Widget _buildDecorativeLine(bool leftToRight) {
    return Container(
      width: 80,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: leftToRight
              ? [Colors.transparent, Color(0xFFFFD700).withOpacity(0.7)]
              : [Color(0xFFFFD700).withOpacity(0.7), Colors.transparent],
        ),
      ),
    );
  }
}

// Custom Painter for animated stars
class StarsPainter extends CustomPainter {
  final double animationValue;

  StarsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFFFD700).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 1.0 + random.nextDouble() * 2;

      // Twinkle effect
      final twinkle =
          (math.sin((animationValue * 2 * math.pi) + (i * 0.5)) + 1) / 2;
      paint.color = Color(0xFFFFD700).withOpacity(0.3 + (twinkle * 0.4));

      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(StarsPainter oldDelegate) => true;
}

// Custom Painter for Islamic patterns
class IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final spacing = 80.0;

    // Draw geometric Islamic patterns
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Draw star pattern
        _drawIslamicStar(canvas, Offset(x, y), 30, paint);
      }
    }
  }

  void _drawIslamicStar(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    const points = 8;

    for (int i = 0; i < points; i++) {
      final angle = (i * 2 * math.pi / points) - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    // Inner circle
    canvas.drawCircle(center, radius * 0.3, paint);
  }

  @override
  bool shouldRepaint(IslamicPatternPainter oldDelegate) => false;
}
