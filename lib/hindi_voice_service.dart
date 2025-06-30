import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

class HindiVoiceService {
  static final HindiVoiceService _instance = HindiVoiceService._internal();
  factory HindiVoiceService() => _instance;
  HindiVoiceService._internal();

  FlutterTts? _flutterTts;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isEnabled = true;
  double _volume = 0.8;
  double _pitch = 1.0;
  double _speechRate = 0.5;

  // Hindi phrases for different game events
  Map<String, String> hindiPhrases = {
    'insufficient_balance': 'पैसे कम हैं। पहले रीचार्ज करें।',
    'ai_analyzing': 'एआई अब विश्लेषण कर रहा है।',
    'registration_message': 'रजिस्टर करके तीन सौ डिपॉजिट करो मेरे भाई।',
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();
      _audioPlayer = AudioPlayer();

      if (_flutterTts != null) {
        // Configure TTS for Hindi
        await _flutterTts!.setLanguage("hi-IN");
        await _flutterTts!.setPitch(_pitch);
        await _flutterTts!.setVolume(_volume);
        await _flutterTts!.setSpeechRate(_speechRate);

        // Check if Hindi is available
        List<dynamic> languages = await _flutterTts!.getLanguages;
        bool hindiAvailable = languages.any((lang) =>
            lang.toString().toLowerCase().contains('hi') ||
            lang.toString().toLowerCase().contains('hindi'));

        if (!hindiAvailable) {
          print('Hindi language not available, using English as fallback');
          await _flutterTts!.setLanguage("en-US");
        }

        // Set up TTS event handlers
        _flutterTts!.setStartHandler(() {
          if (kDebugMode) print("TTS Started");
        });

        _flutterTts!.setCompletionHandler(() {
          if (kDebugMode) print("TTS Completed");
        });

        _flutterTts!.setErrorHandler((msg) {
          if (kDebugMode) print("TTS Error: $msg");
        });
      }

      _isInitialized = true;
      print('Hindi Voice Service initialized successfully');
    } catch (e) {
      print('Error initializing Hindi Voice Service: $e');
      _isInitialized = false;
    }
  }

  Future<void> speak(String key,
      {String? customText, bool immediate = false}) async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      if (immediate && _flutterTts != null) {
        await _flutterTts!.stop();
      }

      String textToSpeak = customText ?? hindiPhrases[key] ?? key;

      if (_flutterTts != null) {
        await _flutterTts!.speak(textToSpeak);
      }

      print('Speaking: $textToSpeak');
    } catch (e) {
      print('Error in speak: $e');
    }
  }

  Future<void> playRegistrationSound() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.play(AssetSource('register_voice.ogg'));
      }
    } catch (e) {
      print('Error playing registration sound: $e');
    }
  }

  Future<void> speakRegistrationMessage() async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      // Play both the audio file and the voice message
      await playRegistrationSound();

      // Wait a bit then speak the message
      await Future.delayed(const Duration(milliseconds: 2000));
      await speak('registration_message');
    } catch (e) {
      print('Error in speakRegistrationMessage: $e');
      // Fallback to just voice if audio fails
      await speak('registration_message');
    }
  }

  Future<void> stop() async {
    try {
      if (_flutterTts != null) {
        await _flutterTts!.stop();
      }
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_flutterTts != null && _isInitialized) {
      await _flutterTts!.setVolume(_volume);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_flutterTts != null && _isInitialized) {
      await _flutterTts!.setPitch(_pitch);
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    if (_flutterTts != null && _isInitialized) {
      await _flutterTts!.setSpeechRate(_speechRate);
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _flutterTts?.stop();
    _audioPlayer?.dispose();
    _isInitialized = false;
  }
}
