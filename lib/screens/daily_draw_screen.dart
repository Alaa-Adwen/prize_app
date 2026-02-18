import 'dart:ui';
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class DailyDrawScreen extends StatefulWidget {
  const DailyDrawScreen({super.key});

  @override
  State<DailyDrawScreen> createState() => _DailyDrawScreenState();
}

class _DailyDrawScreenState extends State<DailyDrawScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _starsController;
  late AnimationController _wheelController;
  late AnimationController _glowController;

  // State
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedBranch;
  List<String> _serialNumbers = [];
  bool _isSpinning = false;
  bool _isLoading = false;
  String? _winningSerial;
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
      duration: const Duration(milliseconds: 10000),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  Widget _buildPointer() {
    return Positioned(
      top: -10,
      child: Container(
        child: const Icon(
          Icons.arrow_drop_down,
          color: Color(0xFFFFD700),
          size: 60,
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: _isSpinning ? null : _spinWheel,
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A3E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFffffff), width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: _isSpinning
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'إبدأ',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _starsController.dispose();
    _wheelController.dispose();
    _glowController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchTodaysSerials() async {
    if (_selectedBranch == null) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final branchCode = _branchCodes[_selectedBranch];
      final now = DateTime.now();

      final snapshot = await firestore
          .collection('customer_serial')
          .where('branch', isEqualTo: _selectedBranch)
          .get();

      List<String> allSerials = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime? recordDate;

        if (data['createdAt'] != null) {
          final createdAt = data['createdAt'] as Timestamp;
          recordDate = createdAt.toDate();
        } else if (data['date'] != null) {
          final dateField = data['date'];
          if (dateField is Timestamp) {
            recordDate = dateField.toDate();
          }
        }

        if (recordDate != null &&
            recordDate.year == now.year &&
            recordDate.month == now.month &&
            recordDate.day == now.day) {
          final serials = List<String>.from(data['serials'] ?? []);
          allSerials.addAll(
            serials.where((s) => s.startsWith('KH-$branchCode')),
          );
        }
      }

      setState(() {
        _serialNumbers = allSerials;
        _isLoading = false;
      });

      if (allSerials.isEmpty) {
        _showSnackBar('لا توجد قسائم لهذا الفرع اليوم');
      } else {
        _showSnackBar('تم تحميل ${allSerials.length} قسيمة');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء تحميل القسائم: $e');
    }
  }

  void _spinWheel() async {
    if (_isSpinning || _serialNumbers.isEmpty) return;

    final random = math.Random();
    final winnerIndex = random.nextInt(_serialNumbers.length);
    final winningSerial = _serialNumbers[winnerIndex];

    final double segmentSize = 1.0 / _serialNumbers.length;

    // Add randomization within the slice (0.2 to 0.8 of segment = middle 60% of slice)
    final double randomOffsetWithinSlice = 0.2 + (random.nextDouble() * 0.6);
    final double sliceOffset = segmentSize * randomOffsetWithinSlice;

    final double positionOffset =
        (1.0 - (winnerIndex * segmentSize + sliceOffset)) % 1.0;

    setState(() {
      _isSpinning = true;
      _winnerIndex = winnerIndex;
      _targetRotations = 10.0 + positionOffset;
    });

    // Play spinning sound effect (let it play naturally)
    try {
      await _audioPlayer.play(AssetSource('sounds/wheel_spin.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }

    _wheelController.reset();
    await _wheelController.animateTo(
      1.0,
      duration: const Duration(seconds: 9),
      curve: Curves.easeOut, // Simple ease in and out
    );

    String customerName = '';
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('customer_serial')
          .where('serials', arrayContains: winningSerial)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        customerName = snapshot.docs.first.data()['name'] ?? '';
      }
    } catch (e) {
      // Continue without name
    }

    setState(() {
      _winningSerial = winningSerial;
      _isSpinning = false;
    });

    _confettiController.play();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showWinnerDialog(customerName);
      }
    });
  }

  void _showWinnerDialog(String customerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F0528),
                  Color(0xFF1A0A3E),
                  Color(0xFF2D1B69),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.6),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 70),
                SizedBox(height: 16),
                Text(
                  '🎉 مبروك 🎉',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 20),
                if (customerName.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFFFD700).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'الفائز',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFB800)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFFD700).withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'رقم القسيمة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A0A3E).withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _winningSerial ?? '',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A0A3E),
                            fontFamily: 'monospace',
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _confettiController.stop();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFD700),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'إغلاق',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A0A3E),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
            ),
          ),
          child: Stack(
            children: [
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
              AnimatedBuilder(
                animation: _starsController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _StarsPainter(_starsController.value),
                    size: Size.infinite,
                  );
                },
              ),
              Align(
                alignment: Alignment.center,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFFFFA500),
                    Color(0xFFFFFFFF),
                    Color(0xFF4A2CAD),
                  ],
                  numberOfParticles: 20,
                  gravity: 0.1,
                ),
              ),
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
                            if (_selectedBranch != null ||
                                _serialNumbers.isNotEmpty) ...[
                              _buildRouletteWheel(),
                            ] else if (_isLoading) ...[
                              SizedBox(height: 100),
                              CircularProgressIndicator(
                                color: Color(0xFFFFD700),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'جاري التحميل...',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
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
                                  letterSpacing: 0,
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          Text(
            'السحب اليومي',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD700),
              letterSpacing: 0,
              shadows: [
                Shadow(
                  color: Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFD700).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mosque, color: Color(0xFFFFD700), size: 26),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'مركز كهرمانة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                    letterSpacing: 0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFFFD700).withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            dropdownColor: Color.fromARGB(255, 26, 10, 62),
            value: _selectedBranch,
            onChanged: (value) {
              setState(() => _selectedBranch = value);
              _fetchTodaysSerials();
            },
            items: _branchCodes.keys.map((String branchName) {
              return DropdownMenuItem<String>(
                value: branchName,
                child: Text(
                  branchName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              hintText: 'اختر الفرع',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Color(0xFFFFD700).withOpacity(0.5),
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
              prefixIcon: Icon(
                Icons.location_on,
                color: Color(0xFFFFD700),
                size: 22,
              ),
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: Color(0xFFFFD700),
                size: 28,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Color(0xFFFFD700).withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Color(0xFFFFD700).withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLabel(int currentIndex) {
    String currentText;

    if (_serialNumbers.isEmpty) {
      currentText = "---";
    } else {
      double currentRotation =
          (_wheelController.value * _targetRotations) % 1.0;
      int displayIndex =
          ((1.0 - currentRotation) * _serialNumbers.length).floor() %
          _serialNumbers.length;
      currentText = _serialNumbers[displayIndex];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A3E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "القسيمة الحالية",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            currentText,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouletteWheel() {
    return AnimatedBuilder(
      animation: Listenable.merge([_wheelController, _glowController]),
      builder: (context, child) {
        final double rotationInTurns =
            _wheelController.value * _targetRotations;

        int currentIndex = 0;
        if (_serialNumbers.isNotEmpty) {
          final double totalRotation = rotationInTurns % 1.0;
          final int displayIndex =
              ((1.0 - totalRotation) * _serialNumbers.length).floor() %
              _serialNumbers.length;
          currentIndex = displayIndex;
        }

        double blurAmount = 0.0;
        if (_isSpinning) {
          final progress = _wheelController.value;

          // easeInOut reaches max speed around t=0.5 (middle)
          // Blur matches the velocity
          if (progress < 0.5) {
            // Accelerating phase - blur increases
            blurAmount = 5.0 * (progress / 0.5);
          } else {
            // Decelerating phase - blur decreases
            blurAmount = 5.0 * ((1.0 - progress) / 0.5);
          }
        }

        return Column(
          children: [
            _buildLiveLabel(currentIndex),
            const SizedBox(height: 30),
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(
                      0xFFFFD700,
                    ).withOpacity(0.4 + _glowController.value * 0.3),
                    blurRadius: 40 + _glowController.value * 20,
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
                        size: const Size(320, 320),
                        painter: _RouletteWheelPainter(_serialNumbers),
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

class _RouletteWheelPainter extends CustomPainter {
  final List<String> serialNumbers;
  late final List<String> effectiveSerials;

  _RouletteWheelPainter(this.serialNumbers) {
    effectiveSerials = serialNumbers.isEmpty
        ? ['????', '????', '????']
        : serialNumbers;
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

    double startAngleOffset = -math.pi / 2;

    for (int i = 0; i < count; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleOffset + (i * segmentAngle),
        segmentAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = const Color(0xFFffffff).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleOffset + (i * segmentAngle),
        segmentAngle,
        true,
        borderPaint,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngleOffset + (i * segmentAngle) + (segmentAngle / 2));

      String displayText;
      if (count > 60) {
        displayText = "...";
      } else {
        String fullSerial = effectiveSerials[i];
        displayText = fullSerial.length >= 4
            ? fullSerial.substring(fullSerial.length - 4)
            : fullSerial;
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: count > 30 ? 8 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(radius * 0.6, -textPainter.height / 2));
      canvas.restore();
    }

    final outerCirclePaint = Paint()
      ..color = const Color(0xFFffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, outerCirclePaint);
  }

  @override
  bool shouldRepaint(_RouletteWheelPainter oldDelegate) =>
      oldDelegate.serialNumbers != serialNumbers;
}

class _StarsPainter extends CustomPainter {
  final double animationValue;

  _StarsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 1.0 + random.nextDouble() * 2.5;
      final twinkle =
          (math.sin((animationValue * 2 * math.pi) + (i * 0.5)) + 1) / 2;
      paint.color = Color(0xFFFFD700).withOpacity(0.3 + (twinkle * 0.5));
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => true;
}
