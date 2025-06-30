import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

void main() => runApp(const PredictionApp());

class AnimatedGradientBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final double borderRadius;

  const AnimatedGradientBorder({
    Key? key,
    required this.child,
    this.borderWidth = 1.5, // Thinner border for smoother appearance
    this.borderRadius = 12.0,
  }) : super(key: key);

  @override
  _AnimatedGradientBorderState createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // Faster pulsing effect
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Smooth pulsing curve
    ));

    // Start animation with a delay for stability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.repeat(
            reverse: true); // Reverse animation for breathing effect
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return RepaintBoundary(
          // Isolate repaints for better performance
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: SweepGradient(
                center: Alignment.center,
                startAngle:
                    _animation.value * 6.28318, // 2 * pi for smooth rotation
                colors: [
                  Color(0xFF00FF00)
                      .withOpacity(0.4 + (_animation.value * 0.6)), // Green
                  Color(0xFF8000FF)
                      .withOpacity(0.4 + (_animation.value * 0.6)), // Purple
                  Color(0xFFFF00FF)
                      .withOpacity(0.4 + (_animation.value * 0.6)), // Pink
                  Color(0xFFFF0000)
                      .withOpacity(0.4 + (_animation.value * 0.6)), // Red
                  Color(0xFF0000FF)
                      .withOpacity(0.4 + (_animation.value * 0.6)), // Blue
                  Color(0xFF00FF00).withOpacity(
                      0.4 + (_animation.value * 0.6)), // Green (loop)
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.green.withOpacity(0.2 + (_animation.value * 0.4)),
                  blurRadius: 6 + (_animation.value * 8),
                  spreadRadius: _animation.value * 3,
                ),
                BoxShadow(
                  color: Colors.purple
                      .withOpacity(0.15 + (_animation.value * 0.3)),
                  blurRadius: 8 + (_animation.value * 10),
                  spreadRadius: _animation.value * 2,
                ),
                BoxShadow(
                  color:
                      Colors.pink.withOpacity(0.1 + (_animation.value * 0.25)),
                  blurRadius: 4 + (_animation.value * 6),
                  spreadRadius: _animation.value * 1.5,
                ),
              ],
            ),
            child: Container(
              margin: EdgeInsets.all(widget.borderWidth),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                    widget.borderRadius - widget.borderWidth),
                color: const Color(0xFF1a1b20),
              ),
              child: widget.child,
            ),
          ),
        );
      },
      child: widget.child, // Cache child widget
    );
  }
}

class PredictionApp extends StatelessWidget {
  const PredictionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PredictionScreen(),
    );
  }
}

class PredictionScreen extends StatefulWidget {
  @override
  _PredictionScreenState createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  String _prediction = "Big";
  int _periodNumber = 0;
  int _remainingTime = 10;
  bool _isRunning = false;
  bool _hasValidDeposit = false;
  bool _isMandatoryStarted = false;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;
  Timer? _depositCheckTimer;

  @override
  void initState() {
    super.initState();

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initial deposit check
    _checkDepositStatus();

    // Set up periodic deposit check every 30 seconds
    _depositCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDepositStatus();
    });
  }

  Future<void> _checkDepositStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        setState(() => _hasValidDeposit = false);
        return;
      }

      final response = await http.post(
        Uri.parse('https://www.dmwin3.com/api/wallet/recharge-history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'page': 1,
          'limit': 10,
          'startDate': DateTime.now().toString().split(' ')[0],
          'endDate': DateTime.now().toString().split(' ')[0],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool hasValidDeposit = false;

        if (data['data'] != null && data['data']['records'] != null) {
          for (var record in data['data']['records']) {
            if (record['status'] == 'Complete' ||
                record['status'] == 'success') {
              final depositDate =
                  DateTime.parse(record['createTime'] ?? record['time']);
              final now = DateTime.now();

              if (depositDate.year == now.year &&
                  depositDate.month == now.month &&
                  depositDate.day == now.day) {
                hasValidDeposit = true;
                break;
              }
            }
          }
        }

        setState(() => _hasValidDeposit = hasValidDeposit);
      } else {
        print('API Error: ${response.statusCode}');
        setState(() => _hasValidDeposit = false);
      }
    } catch (e) {
      print('Error checking deposit status: $e');
      setState(() => _hasValidDeposit = false);
    }
  }

  Future<void> _openDepositPage() async {
    try {
      final Uri url =
          Uri.parse('https://www.dmwin3.com/#/wallet/RechargeHistory');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch deposit page';
      }
    } catch (e) {
      print('Error opening deposit page: $e');
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Error',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Unable to open deposit page. Please try again later.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _handleMandatoryStart() {
    setState(() {
      _isMandatoryStarted = true;
    });
  }

  void _handleStartButtonPress() {
    if (!_hasValidDeposit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Deposit Required',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please make a deposit for today to start predictions.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openDepositPage();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: Text(
                'Make Deposit',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (!_isMandatoryStarted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Start Required',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please press the START button in the top bar first.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (_isRunning) {
      _stopPrediction();
    } else {
      _startPrediction();
    }
  }

  void _startPrediction() {
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _remainingTime = 10;
          _periodNumber++;
          _prediction = Random().nextBool() ? "Big" : "Small";
        }
      });
    });
  }

  void _stopPrediction() {
    setState(() {
      _isRunning = false;
      _timer.cancel();
      _remainingTime = 10;
    });
  }

  @override
  void dispose() {
    _depositCheckTimer?.cancel();
    _timer.cancel();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PredictionAppBar(
        gameTimer: formatTime(_remainingTime),
        wins: "10",
        losses: "5",
        prediction: _prediction,
        periodNumber: "Period: $_periodNumber",
        onMandatoryStart: _handleMandatoryStart,
        isMandatoryStarted: _isMandatoryStarted,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedStartButton(
              isRunning: _isRunning,
              onPressed: _handleStartButtonPress,
              scaleAnimation: _buttonScaleAnimation,
              animationController: _buttonAnimationController,
              isEnabled: _hasValidDeposit && _isMandatoryStarted,
            ),
            if (!_hasValidDeposit) ...[
              const SizedBox(height: 16),
              Text(
                '⚠️ Deposit required to start predictions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.amber,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else if (!_isMandatoryStarted) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Press START in top bar to begin',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.amber,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PredictionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String gameTimer;
  final String wins;
  final String losses;
  final String prediction;
  final String periodNumber;
  final VoidCallback onMandatoryStart;
  final bool isMandatoryStarted;

  const PredictionAppBar({
    required this.gameTimer,
    required this.wins,
    required this.losses,
    required this.prediction,
    required this.periodNumber,
    required this.onMandatoryStart,
    required this.isMandatoryStarted,
  });

  int _getPredictedNumber(String prediction, String periodNumber) {
    // Get last 3 digits of period number
    String digits = periodNumber.replaceAll(RegExp(r'[^0-9]'), '');
    String lastThreeDigits = digits.length > 3
        ? digits.substring(digits.length - 3)
        : digits.padLeft(3, '0');

    // Use the last digit and prediction for number generation
    final int seed = int.parse(lastThreeDigits[2]);
    final bool isBig = prediction.toLowerCase() == 'big';

    if (isBig) {
      return ((seed * 7 + 3) % 5) + 5; // Generates number between 5-9 for BIG
    } else {
      return (seed * 3 + 1) % 5; // Generates number between 0-4 for SMALL
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBig = prediction.toLowerCase() == 'big';
    final predictedNumber = _getPredictedNumber(prediction, periodNumber);

    return PreferredSize(
      preferredSize: const Size.fromHeight(205),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1a1b20),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 12,
              right: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title with modern design
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade900, Colors.blue.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "💸 NUMBER HACK V3.1💸",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                // Game info with modern cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Period Number (Left)
                    Expanded(
                      flex: 2,
                      child: _buildInfoCard(
                        "Period",
                        _formatPeriodNumber(periodNumber),
                        const Color(0xFF2a2d36),
                        Icons.timer_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Big/Small Prediction (Center)
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2d36),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isBig ? Colors.yellow : Colors.lightBlue,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "PREDICTION",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              prediction,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isBig ? Colors.yellow : Colors.lightBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Number Prediction (Right)
                    Expanded(
                      flex: 2,
                      child: _buildInfoCard(
                        "Number",
                        predictedNumber.toString(),
                        const Color(0xFF2a2d36),
                        Icons.casino_outlined,
                        color: predictedNumber >= 5
                            ? Colors.yellow
                            : Colors.lightBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Stats bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2d36),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Win: $wins",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Time: $gameTimer",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Loss: $losses",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                // Developer signature at bottom (centered)
                Container(
                  alignment: Alignment.center,
                  child: Text(
                    "By Developer_01 💸🚀",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white38,
                      fontStyle: FontStyle.italic,
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

  Widget _buildInfoCard(
      String label, String value, Color bgColor, IconData icon,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeriodNumber(String periodNumber) {
    String digits = periodNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 3) {
      return digits.substring(digits.length - 3);
    }
    return digits.padLeft(3, '0');
  }

  @override
  Size get preferredSize => const Size.fromHeight(240);
}

class AnimatedStartButton extends StatelessWidget {
  final bool isRunning;
  final bool isEnabled;
  final VoidCallback onPressed;
  final Animation<double> scaleAnimation;
  final AnimationController animationController;

  const AnimatedStartButton({
    required this.isRunning,
    required this.onPressed,
    required this.scaleAnimation,
    required this.animationController,
    this.isEnabled = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: isEnabled ? (_) => animationController.forward() : null,
      onTapUp: isEnabled ? (_) => animationController.reverse() : null,
      onTapCancel: isEnabled ? () => animationController.reverse() : null,
      onTap: isEnabled ? onPressed : null,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Container(
          width: 200,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                isEnabled
                    ? (isRunning ? Colors.red.shade400 : Colors.blue.shade400)
                    : Colors.grey.shade400,
                isEnabled
                    ? (isRunning ? Colors.red.shade700 : Colors.blue.shade700)
                    : Colors.grey.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isEnabled
                        ? (isRunning ? Colors.red : Colors.blue)
                        : Colors.grey)
                    .withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEnabled
                            ? (isRunning ? Icons.stop : Icons.play_arrow)
                            : Icons.lock,
                        size: 64,
                        color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnabled ? (isRunning ? "STOP" : "START") : "LOCKED",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              Colors.white.withOpacity(isEnabled ? 1.0 : 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdvancedPredictionBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String gameTimer;
  final String wins;
  final String losses;
  final String currentPrediction;
  final String periodNumber;
  final List<String> next5Predictions;
  final VoidCallback onMandatoryStart;
  final bool isMandatoryStarted;

  const AdvancedPredictionBar({
    Key? key,
    required this.gameTimer,
    required this.wins,
    required this.losses,
    required this.currentPrediction,
    required this.periodNumber,
    required this.next5Predictions,
    required this.onMandatoryStart,
    required this.isMandatoryStarted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("🎨 AdvancedPredictionBar.build() called");
    print("   next5Predictions: $next5Predictions");
    print("   next5Predictions.length: ${next5Predictions.length}");
    print("   gameTimer: $gameTimer");
    print("   periodNumber: $periodNumber");

    return PreferredSize(
      preferredSize: const Size.fromHeight(260),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1a1b20),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Enhanced Header with Animated Gradient Border
                AnimatedGradientBorder(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade800.withOpacity(0.3),
                          Colors.blue.shade800.withOpacity(0.3),
                          Colors.green.shade800.withOpacity(0.3),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.psychology,
                            color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "🚀NEXT AI PREDICTIONS🎯",
                          style: GoogleFonts.orbitron(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.greenAccent.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.trending_up,
                            color: Colors.greenAccent, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Simple List Design
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListView.builder(
                      itemCount: 5,
                      padding: EdgeInsets.zero,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable scrolling for better performance
                      shrinkWrap: true, // Optimize layout
                      itemBuilder: (context, index) {
                        final prediction = index < next5Predictions.length
                            ? next5Predictions[index]
                            : "Loading...";

                        final nextPeriodFull =
                            _getNextPeriodNumber(periodNumber, index + 1);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              // Period text
                              Text(
                                "Period",
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "-",
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Period number
                              Expanded(
                                child: Text(
                                  nextPeriodFull == "???"
                                      ? "Loading..."
                                      : nextPeriodFull,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 15,
                                    color: nextPeriodFull == "???"
                                        ? Colors.grey
                                        : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Prediction
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: prediction == "Loading..."
                                      ? Colors.grey.withOpacity(0.2)
                                      : prediction.toLowerCase() == "big"
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: prediction == "Loading..."
                                        ? Colors.grey.withOpacity(0.4)
                                        : prediction.toLowerCase() == "big"
                                            ? Colors.green.withOpacity(0.6)
                                            : Colors.red.withOpacity(0.6),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  prediction == "Loading..."
                                      ? "Loading..."
                                      : prediction.toUpperCase(),
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: prediction == "Loading..."
                                        ? Colors.grey
                                        : prediction.toLowerCase() == "big"
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Compact Timer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, color: Colors.white70, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        "Next: ${gameTimer}s",
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPeriodNumber(String periodNumber) {
    String digits = periodNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 3) {
      return digits.substring(digits.length - 3);
    }
    return digits.padLeft(3, '0');
  }

  String _getNextPeriodNumber(String currentPeriod, int offset) {
    try {
      String digits = currentPeriod.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        // For 17-digit numbers, use BigInt to handle large numbers
        if (digits.length == 17) {
          BigInt current = BigInt.parse(digits);
          BigInt next = current + BigInt.from(offset);
          return next.toString(); // Return full 17-digit number
        } else if (digits.length >= 3) {
          // Handle shorter numbers normally
          int current = int.parse(digits);
          int next = current + offset;
          return next.toString();
        }
      }
    } catch (e) {
      print("❌ Error calculating next period: $e");
    }
    return "???";
  }

  @override
  Size get preferredSize => const Size.fromHeight(245);
}
