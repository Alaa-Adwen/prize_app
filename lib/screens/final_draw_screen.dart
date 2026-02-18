import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class FinalDrawScreen extends StatefulWidget {
  const FinalDrawScreen({super.key});

  @override
  State<FinalDrawScreen> createState() => _FinalDrawScreenState();
}

class _FinalDrawScreenState extends State<FinalDrawScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _starsController;
  late AnimationController _wheelController;
  late AnimationController _glowController;
  late AnimationController _titleController;
  late AnimationController _winnerScaleController;
  late AnimationController _winnerRotateController;
  late AnimationController _fireworksController;

  // State
  late ConfettiController _confettiController;
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedBranch;
  List<Map<String, String>> _customerSerials = [];
  List<String> _removedSerials = [];
  bool _isSpinning = false;
  bool _isLoading = false;
  String? _winningSerial;
  String? _winningCustomerName;
  String? _winningCustomerPhone;
  double _targetRotations = 0;
  int _winnerIndex = 0;

  final Map<String, String> _branchCodes = {
    'فرع خانيونس البلد': '01',
    'فرع خانيونس النص': '02',
    'فرع دير البلح': '03',
    'فرع غزة': '04',
  };

  @override
  void initState() {
    super.initState();

    _starsController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _wheelController = AnimationController(
      duration: const Duration(milliseconds: 9000),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _titleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _winnerScaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _winnerRotateController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fireworksController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 6),
    );
    _confettiControllerLeft = ConfettiController(
      duration: const Duration(seconds: 6),
    );
    _confettiControllerRight = ConfettiController(
      duration: const Duration(seconds: 6),
    );
  }

  Widget _buildPointer() {
    return Positioned(
      top: -20,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFFD700,
                  ).withOpacity(0.7 + _glowController.value * 0.3),
                  blurRadius: 25 + _glowController.value * 15,
                  spreadRadius: 5 + _glowController.value * 3,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.arrow_drop_down, color: Color(0xFFFFD700), size: 80),
                Positioned(
                  top: 10,
                  child: Icon(Icons.star, color: Colors.white, size: 20),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: _isSpinning ? null : _spinWheel,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: _isSpinning
                  ? null
                  : RadialGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFD700),
                        Color(0xFFFFB800),
                      ],
                    ),
              color: _isSpinning ? const Color(0xFF1A0A3E) : null,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFffffff), width: 5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(
                    _isSpinning ? 0.4 : 0.8 + _glowController.value * 0.2,
                  ),
                  blurRadius: _isSpinning
                      ? 20
                      : 30 + _glowController.value * 20,
                  spreadRadius: _isSpinning ? 3 : 5 + _glowController.value * 5,
                ),
              ],
            ),
            child: Center(
              child: _isSpinning
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD700),
                        strokeWidth: 4,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF1A0A3E),
                          size: 40,
                        ),
                        Text(
                          'إبدأ',
                          style: TextStyle(
                            color: Color(0xFF1A0A3E),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _starsController.dispose();
    _wheelController.dispose();
    _glowController.dispose();
    _titleController.dispose();
    _winnerScaleController.dispose();
    _winnerRotateController.dispose();
    _fireworksController.dispose();
    _confettiController.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchTodaysSerials() async {
    if (_selectedBranch == null) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final branchCode = _branchCodes[_selectedBranch];

      // Fetch ALL registrations for this branch (entire database, not just today)
      final snapshot = await firestore
          .collection('customer_serial')
          .where('branch', isEqualTo: _selectedBranch)
          .get();

      Map<String, Map<String, String>> customerSerialMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final customerName = data['name'] ?? '';
        final customerPhone = data['phone'] ?? '';

        // Create unique key using name and phone
        final uniqueKey = '$customerName|$customerPhone';

        // Skip if customer already has a serial assigned (one serial per customer)
        if (customerSerialMap.containsKey(uniqueKey)) {
          continue;
        }

        final serials = List<String>.from(data['serials'] ?? []);

        // Find the first serial for this branch that hasn't been removed
        for (var serial in serials) {
          if (serial.startsWith('KH-$branchCode') &&
              !_removedSerials.contains(serial)) {
            customerSerialMap[uniqueKey] = {
              'name': customerName,
              'phone': customerPhone,
              'serial': serial,
            };
            break; // Take ONLY the first serial for this customer
          }
        }
      }

      // Convert to list format
      List<Map<String, String>> customerSerialsList = customerSerialMap.values
          .map(
            (entry) => {
              'name': entry['name']!,
              'phone': entry['phone']!,
              'serial': entry['serial']!,
            },
          )
          .toList();

      setState(() {
        _customerSerials = customerSerialsList;
        _isLoading = false;
      });

      if (customerSerialsList.isEmpty) {
        _showSnackBar('لا توجد قسائم لهذا الفرع');
      } else {
        _showSnackBar(
          'تم تحميل ${customerSerialsList.length} عميل من ${_selectedBranch}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء تحميل القسائم: $e');
    }
  }

  void _removeSerialFromPool(String serial) {
    setState(() {
      _removedSerials.add(serial);
      _customerSerials.removeWhere((item) => item['serial'] == serial);
    });
    _showSnackBar('تم إزالة القسيمة من السحب النهائي');
  }

  void _spinWheel() async {
    if (_isSpinning || _customerSerials.isEmpty) return;

    final random = math.Random();
    final winnerIndex = random.nextInt(_customerSerials.length);
    final winner = _customerSerials[winnerIndex];
    final winningSerial = winner['serial']!;
    final customerName = winner['name']!;
    final customerPhone = winner['phone']!;

    final extraRotations = 10 + random.nextInt(5);

    // Calculate rotation to land on winner at the top
    final double segmentSize = 1.0 / _customerSerials.length;

    // Add randomization within the slice (0.2 to 0.8 of segment = middle 60% of slice)
    // This makes it land randomly within the slice instead of always at the border
    final double randomOffsetWithinSlice = 0.2 + (random.nextDouble() * 0.6);
    final double sliceOffset = segmentSize * randomOffsetWithinSlice;

    final double positionOffset =
        (1.0 - (winnerIndex * segmentSize + sliceOffset)) % 1.0;

    setState(() {
      _isSpinning = true;
      _winningSerial = null;
      _winningCustomerName = null;
      _winningCustomerPhone = null;
      _winnerIndex = winnerIndex;
      _targetRotations = extraRotations.toDouble() + positionOffset;
    });

    // Play spinning sound effect (play once, no loop)
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop); // Don't loop
      await _audioPlayer.play(AssetSource('sounds/wheel_spin.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }

    _wheelController.reset();
    await _wheelController.animateTo(
      1.0,
      duration: const Duration(seconds: 9),
      curve:
          Curves.easeOut, // Fast start, gradual slowdown (matches daily draw)
    );

    setState(() {
      _winningSerial = winningSerial;
      _winningCustomerName = customerName;
      _winningCustomerPhone = customerPhone;
      _isSpinning = false;
    });

    // Epic celebration
    _confettiController.play();
    _confettiControllerLeft.play();
    _confettiControllerRight.play();
    _fireworksController.forward(from: 0);
    _winnerScaleController.forward(from: 0);
    _winnerRotateController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _showWinnerDialog(customerName, customerPhone, winningSerial);
      }
    });
  }

  void _showWinnerDialog(
    String customerName,
    String customerPhone,
    String winningSerial,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _winnerScaleController,
              _fireworksController,
            ]),
            builder: (context, child) {
              final scale = Curves.elasticOut.transform(
                _winnerScaleController.value,
              );

              return Stack(
                children: [
                  // Fireworks effect
                  CustomPaint(
                    painter: _FireworksPainter(_fireworksController.value),
                    size: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height,
                    ),
                  ),

                  // Main dialog
                  Center(
                    child: Transform.scale(
                      scale: scale,
                      child: SingleChildScrollView(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          constraints: BoxConstraints(maxWidth: 400),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF0A0520),
                                Color(0xFF1A0A3E),
                                Color(0xFF2D1B69),
                                Color(0xFF4A2CAD),
                                Color(0xFF6B46C1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Color(0xFFFFD700),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFFFD700).withOpacity(0.8),
                                blurRadius: 50,
                                spreadRadius: 15,
                              ),
                              BoxShadow(
                                color: Color(0xFF4A2CAD).withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Crown and title
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow background
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0xFFFFD700).withOpacity(0.4),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Crown icon
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 1000),
                                    curve: Curves.elasticOut,
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: Transform.rotate(
                                          angle: (1 - value) * math.pi * 2,
                                          child: Container(
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  Color(0xFFFFD700),
                                                  Color(0xFFFFB800),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(
                                                    0xFFFFD700,
                                                  ).withOpacity(0.6),
                                                  blurRadius: 25,
                                                  spreadRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.emoji_events,
                                              color: Color(0xFF1A0A3E),
                                              size: 50,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Congratulations text with shimmer
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFFFFF),
                                      Color(0xFFFFD700),
                                      Color(0xFFFFFFFF),
                                      Color(0xFFFFD700),
                                    ],
                                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  '★ الفائز الكبير ★',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                    shadows: [
                                      Shadow(
                                        color: Color(
                                          0xFFFFD700,
                                        ).withOpacity(0.8),
                                        blurRadius: 25,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 4),

                              Text(
                                'السحب النهائي الكبير',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFFFD700).withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 20),

                              // Winner name card
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Color(0xFFFFD700).withOpacity(0.6),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFFD700).withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          color: Color(0xFFFFD700),
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'صاحب الحظ السعيد',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700).withOpacity(0.2),
                                            Color(0xFFFFB800).withOpacity(0.2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        customerName,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Color(
                                                0xFFFFD700,
                                              ).withOpacity(0.6),
                                              blurRadius: 12,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Serial number - premium gold ticket
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFE55C),
                                      Color(0xFFFFB800),
                                      Color(0xFFFFD700),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFFD700).withOpacity(0.8),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.workspace_premium,
                                          color: Color(0xFF1A0A3E),
                                          size: 20,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'رقم القسيمة الفائزة',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Color(
                                              0xFF1A0A3E,
                                            ).withOpacity(0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xFF1A0A3E,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          winningSerial,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1A0A3E),
                                            fontFamily: 'monospace',
                                            letterSpacing: 2,
                                            shadows: [
                                              Shadow(
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Celebratory message
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color(0xFFFFD700).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '🎊 ألف مبروك! 🎊',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 20),

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _audioPlayer.stop(); // Stop sound
                                        Navigator.pop(context);
                                        _removeSerialFromPool(winningSerial);
                                        _confettiController.stop();
                                        _confettiControllerLeft.stop();
                                        _confettiControllerRight.stop();
                                      },
                                      icon: Icon(
                                        Icons.delete_forever,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'إزالة',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 6,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _audioPlayer.stop(); // Stop sound
                                        Navigator.pop(context);
                                        _confettiController.stop();
                                        _confettiControllerLeft.stop();
                                        _confettiControllerRight.stop();
                                      },
                                      icon: Icon(Icons.celebration, size: 20),
                                      label: Text(
                                        'إغلاق',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFFFD700),
                                        foregroundColor: Color(0xFF1A0A3E),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Color(0xFF2D1B69),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
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
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Dark gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A0520).withOpacity(0.8),
                      Color(0xFF1A0A3E).withOpacity(0.7),
                      Color(0xFF2D1B69).withOpacity(0.7),
                      Color(0xFF4A2CAD).withOpacity(0.6),
                    ],
                  ),
                ),
              ),

              // Animated stars
              AnimatedBuilder(
                animation: _starsController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _StarsPainter(_starsController.value),
                    size: Size.infinite,
                  );
                },
              ),

              // Triple confetti cannons
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: math.pi / 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 25,
                  gravity: 0.1,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFFFFA500),
                    Color(0xFFFFFFFF),
                    Color(0xFF4A2CAD),
                    Color(0xFFFF1744),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: ConfettiWidget(
                  confettiController: _confettiControllerLeft,
                  blastDirection: 0,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.1,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFFFFFFFF),
                    Color(0xFF4A2CAD),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ConfettiWidget(
                  confettiController: _confettiControllerRight,
                  blastDirection: math.pi,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.1,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFFFFFFFF),
                    Color(0xFF4A2CAD),
                  ],
                ),
              ),

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            _buildBranchDropdown(),
                            SizedBox(height: 40),
                            if (_selectedBranch != null &&
                                _customerSerials.isNotEmpty) ...[
                              _buildRouletteWheel(),
                            ] else if (_isLoading) ...[
                              SizedBox(height: 100),
                              CircularProgressIndicator(
                                color: Color(0xFFFFD700),
                                strokeWidth: 4,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'جاري التحميل...',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ] else if (_selectedBranch != null) ...[
                              SizedBox(height: 100),
                              Icon(
                                Icons.info_outline,
                                size: 64,
                                color: Color(0xFFFFD700).withOpacity(0.5),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'لا توجد قسائم لهذا الفرع اليوم',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.3), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Animated title
          Expanded(
            child: AnimatedBuilder(
              animation: _titleController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFD700),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFD700),
                      ],
                      stops: [
                        0.0,
                        _titleController.value * 0.5,
                        _titleController.value,
                        0.5 + _titleController.value * 0.5,
                        1.0,
                      ],
                    ).createShader(bounds);
                  },
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'السحب النهائي الكبير',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFD700).withOpacity(0.8),
                                  blurRadius: 20,
                                ),
                                Shadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                      Text(
                        'مركز كهرمانة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFD700).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 25,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque, color: Color(0xFFFFD700), size: 28),
              SizedBox(width: 12),
              Text(
                'اختر الفرع',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 2,
            margin: EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFFFD700).withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: Color(0xFF1A0A3E),
            value: _selectedBranch,
            onChanged: (value) {
              setState(() {
                _selectedBranch = value;
                _removedSerials.clear();
              });
              _fetchTodaysSerials();
            },
            items: _branchCodes.keys.map((String branchName) {
              return DropdownMenuItem<String>(
                value: branchName,
                child: Text(
                  branchName,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              hintText: 'اختر فرعك',
              hintStyle: TextStyle(
                fontSize: 17,
                color: Color(0xFFFFD700).withOpacity(0.5),
                fontWeight: FontWeight.w900,
              ),
              prefixIcon: Icon(
                Icons.location_on,
                color: Color(0xFFFFD700),
                size: 24,
              ),
              suffixIcon: Icon(
                Icons.arrow_drop_down_circle,
                color: Color(0xFFFFD700),
                size: 28,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Color(0xFFFFD700).withOpacity(0.4),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Color(0xFFFFD700).withOpacity(0.4),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Color(0xFFFFD700), width: 3),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLabel(int currentIndex) {
    String currentText;

    if (_customerSerials.isEmpty) {
      currentText = "---";
    } else if (!_isSpinning && _winningSerial != null) {
      currentText = _winningSerial!;
    } else {
      // Using the same calculation as daily draw screen
      final double rotationInTurns = _wheelController.value * _targetRotations;
      final double currentRotation = rotationInTurns % 1.0;

      // Calculate which index is at the top (accounting for clockwise rotation)
      final int displayIndex =
          ((1.0 - currentRotation) * _customerSerials.length).floor() %
          _customerSerials.length;

      currentText = _customerSerials[displayIndex]['serial']!;
    }

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A0A3E).withOpacity(0.95),
                const Color(0xFF2D1B69).withOpacity(0.95),
                const Color(0xFF4A2CAD).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              width: 3,
              color: Color(
                0xFFFFD700,
              ).withOpacity(0.7 + _glowController.value * 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFFD700,
                ).withOpacity(0.5 + _glowController.value * 0.3),
                blurRadius: 20 + _glowController.value * 15,
                spreadRadius: 3 + _glowController.value * 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                "القسيمة الحالية",
                style: TextStyle(
                  color: Color(0xFFFFD700).withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                currentText,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 3,
                  shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouletteWheel() {
    return AnimatedBuilder(
      animation: Listenable.merge([_wheelController, _glowController]),
      builder: (context, child) {
        final double rotationInTurns =
            _wheelController.value * _targetRotations;

        int currentIndex = 0;
        if (_customerSerials.isNotEmpty) {
          final double currentRotation = rotationInTurns % 1.0;
          currentIndex =
              ((1.0 - currentRotation) * _customerSerials.length).floor() %
              _customerSerials.length;
        }

        double blurAmount = 0.0;
        if (_isSpinning) {
          final progress = _wheelController.value;

          if (progress < 0.15) {
            // First 15% (0-2s) - Quickly fade IN to max blur as speed ramps up to max (0 to 6.0)
            blurAmount = (progress / 0.15) * 6.0;
          } else if (progress < 0.60) {
            // 15% to 60% (2s-7.8s) - Maintain peak blur as wheel spins fast
            blurAmount = 6.0;
          } else {
            // Last 40% (7.8s-13s) - Gradually fade OUT as wheel slows down (6.0 to 0)
            final slowdownProgress = (progress - 0.60) / 0.40;
            blurAmount = 6.0 * (1.0 - slowdownProgress);
          }
        }

        return Column(
          children: [
            _buildLiveLabel(currentIndex),
            const SizedBox(height: 40),
            Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(
                      0xFFFFD700,
                    ).withOpacity(0.6 + _glowController.value * 0.3),
                    blurRadius: 60 + _glowController.value * 30,
                    spreadRadius: 8 + _glowController.value * 4,
                  ),
                  BoxShadow(
                    color: Color(0xFF4A2CAD).withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blurAmount,
                      sigmaY: blurAmount,
                    ),
                    child: Transform.rotate(
                      angle: rotationInTurns * 2 * math.pi,
                      child: CustomPaint(
                        size: const Size(360, 360),
                        painter: _RouletteWheelPainter(_customerSerials),
                      ),
                    ),
                  ),
                  _buildPointer(),
                  _buildCenterButton(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Roulette wheel painter
class _RouletteWheelPainter extends CustomPainter {
  final List<Map<String, String>> customerSerials;
  late final List<Map<String, String>> effectiveSerials;

  _RouletteWheelPainter(this.customerSerials) {
    effectiveSerials = customerSerials.isEmpty
        ? [
            {'name': '???', 'serial': '????', 'phone': ''},
            {'name': '???', 'serial': '????', 'phone': ''},
            {'name': '???', 'serial': '????', 'phone': ''},
          ]
        : customerSerials;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final int count = effectiveSerials.length;
    final segmentAngle = (2 * math.pi) / count;

    final List<Color> colors = [
      const Color(0xFFde2624),
      const Color(0xFF1487cf),
      const Color(0xFFfdb636),
      const Color(0xFF359b47),
      const Color(0xFF000000),
    ];

    // Add start angle offset to align index 0 at the top
    double startAngleOffset = -math.pi / 2;

    for (int i = 0; i < count; i++) {
      // Draw slice with gradient
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i % colors.length],
            colors[i % colors.length].withOpacity(0.7),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleOffset + (i * segmentAngle),
        segmentAngle,
        true,
        paint,
      );

      // Draw golden borders
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleOffset + (i * segmentAngle),
        segmentAngle,
        true,
        borderPaint,
      );

      // Draw text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      // Match the text rotation to the slice rotation with offset
      canvas.rotate(startAngleOffset + (i * segmentAngle) + (segmentAngle / 2));

      String displayText;
      if (count > 60) {
        displayText = "...";
      } else {
        String fullSerial = effectiveSerials[i]['serial']!;
        displayText = fullSerial.length >= 4
            ? fullSerial.substring(fullSerial.length - 4)
            : fullSerial;
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: count > 30 ? 9 : 14,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(radius * 0.65, -textPainter.height / 2));
      canvas.restore();
    }

    // Premium outer ring
    final outerRingPaint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFFFFF), Color(0xFFFFD700)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, outerRingPaint);
  }

  @override
  bool shouldRepaint(_RouletteWheelPainter oldDelegate) =>
      oldDelegate.customerSerials != customerSerials;
}

// Stars painter
class _StarsPainter extends CustomPainter {
  final double animationValue;

  _StarsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 1.0 + random.nextDouble() * 3.0;
      final twinkle =
          (math.sin((animationValue * 2 * math.pi) + (i * 0.5)) + 1) / 2;
      paint.color = Color(0xFFFFD700).withOpacity(0.3 + (twinkle * 0.6));
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => true;
}

// Fireworks painter
class _FireworksPainter extends CustomPainter {
  final double animationValue;

  _FireworksPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue == 0) return;

    final random = math.Random(123);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final centerX = random.nextDouble() * size.width;
      final centerY = random.nextDouble() * size.height * 0.5;

      final explosionProgress = (animationValue + i * 0.2) % 1.0;
      final radius = explosionProgress * 100;
      final opacity = (1.0 - explosionProgress) * 0.8;

      for (int j = 0; j < 12; j++) {
        final angle = (j / 12) * 2 * math.pi;
        final x = centerX + math.cos(angle) * radius;
        final y = centerY + math.sin(angle) * radius;

        paint.color = [
          Color(0xFFFFD700),
          Color(0xFFFF1744),
          Color(0xFF00D2D3),
          Color(0xFFFFFFFF),
        ][j % 4].withOpacity(opacity);

        canvas.drawCircle(Offset(x, y), 4.0 * (1.0 - explosionProgress), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter oldDelegate) => true;
}
