import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const PredictionApp());

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
  int _periodNumber = 1;
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
              const SizedBox(height: 16),
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
                      "💸JALWA NUMBER H@CK💸",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 4),
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
          const SizedBox(height: 4),
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
  Size get preferredSize => const Size.fromHeight(200);
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
          height: 200,
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
                      const SizedBox(height: 8),
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

class PredictionWindow extends StatefulWidget {
  final String gameTimer;
  final String wins;
  final String losses;
  final String prediction;
  final String periodNumber;
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onHide;

  const PredictionWindow({
    Key? key,
    required this.gameTimer,
    required this.wins,
    required this.losses,
    required this.prediction,
    required this.periodNumber,
    required this.isRunning,
    required this.onStart,
    required this.onStop,
    required this.onHide,
  }) : super(key: key);

  @override
  _PredictionWindowState createState() => _PredictionWindowState();
}

class _PredictionWindowState extends State<PredictionWindow> {
  int _getPredictedNumber(String prediction, String periodNumber) {
    String digits = periodNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    String lastThreeDigits = digits.length > 3
        ? digits.substring(digits.length - 3)
        : digits.padLeft(3, '0');

    final int seed = int.parse(lastThreeDigits[lastThreeDigits.length - 1]);
    final bool isBig = prediction.toLowerCase() == 'big';

    if (isBig) {
      return ((seed * 7 + 3) % 5) + 5;
    } else {
      return (seed * 3 + 1) % 5;
    }
  }

  String _formatPeriodNumber(String periodNumber) {
    String digits = periodNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) {
      return '...${digits.substring(digits.length - 4)}';
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final bool isBig = widget.prediction.toLowerCase() == 'big';
    final predictedNumber =
        _getPredictedNumber(widget.prediction, widget.periodNumber);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.greenAccent.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Period and Hack Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Period: ${_formatPeriodNumber(widget.periodNumber)}',
                    style: GoogleFonts.orbitron(
                      color: Colors.greenAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      'AI Hack',
                      style: GoogleFonts.chakraPetch(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(color: Colors.greenAccent.withOpacity(0.3), height: 16),
              // Predictions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPredictionBox(
                      'AI NUMBER',
                      widget.prediction.toUpperCase(),
                      Colors.greenAccent,
                      isBig),
                  _buildPredictionBox('NUMBER', predictedNumber.toString(),
                      Colors.greenAccent, isBig),
                ],
              ),
              Divider(color: Colors.greenAccent.withOpacity(0.3), height: 16),
              // Stats
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Win: ${widget.wins}",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Time: ${widget.gameTimer}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Loss: ${widget.losses}",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildButton(
                      widget.isRunning ? 'STOP' : 'START',
                      widget.isRunning ? widget.onStop : widget.onStart,
                      widget.isRunning ? Colors.redAccent : Colors.greenAccent),
                  _buildButton('HIDE', widget.onHide, Colors.grey.shade600),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionBox(
      String title, String value, Color titleColor, bool isBig) {
    Color valueColor;
    if (title == 'AI NUMBER') {
      valueColor = isBig ? Colors.yellow : Colors.lightBlue;
    } else {
      valueColor = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.chakraPetch(
              color: titleColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
              shadows: [
                Shadow(
                  blurRadius: 8.0,
                  color: valueColor.withOpacity(0.5),
                ),
                Shadow(
                  blurRadius: 15.0,
                  color: valueColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed, Color color) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          side: BorderSide(color: color.withOpacity(0.5), width: 1),
        ),
        child: Text(
          text,
          style: GoogleFonts.orbitron(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class AdvancedMatrixEffect extends StatefulWidget {
  final double height;
  final double width;

  const AdvancedMatrixEffect(
      {required this.height, required this.width, Key? key})
      : super(key: key);

  @override
  _AdvancedMatrixEffectState createState() => _AdvancedMatrixEffectState();
}

class _AdvancedMatrixEffectState extends State<AdvancedMatrixEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<List<String>> _matrix;
  late int rows, columns;

  @override
  void initState() {
    super.initState();

    rows = (widget.height / 20).ceil();
    columns = (widget.width / 12).ceil();
    _matrix = List.generate(
        rows, (_) => List.generate(columns, (_) => _randomChar()));

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100))
      ..addListener(() {
        setState(() {
          for (int i = 0; i < rows; i++) {
            for (int j = 0; j < columns; j++) {
              if (Random().nextDouble() > 0.95) {
                _matrix[i][j] = _randomChar();
              }
            }
          }
        });
      })
      ..repeat();
  }

  String _randomChar() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return chars[Random().nextInt(chars.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: MatrixPainter(_matrix, rows, columns),
    );
  }
}

class MatrixPainter extends CustomPainter {
  final List<List<String>> matrix;
  final int rows;
  final int columns;

  MatrixPainter(this.matrix, this.rows, this.columns);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        final textStyle = TextStyle(
          color: Colors.greenAccent.shade400.withOpacity(Random().nextDouble()),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        );
        textPainter.text = TextSpan(text: matrix[i][j], style: textStyle);
        textPainter.layout();
        textPainter.paint(canvas, Offset(j * 12.0, i * 20.0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
