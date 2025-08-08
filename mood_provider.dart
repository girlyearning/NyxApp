import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

class MoodEntry {
  final String mood;
  final String emoji;
  final DateTime date;

  MoodEntry({
    required this.mood,
    required this.emoji,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'mood': mood,
      'emoji': emoji,
      'date': date.toIso8601String(),
    };
  }

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      mood: json['mood'],
      emoji: json['emoji'],
      date: DateTime.parse(json['date']),
    );
  }
}


class MoodProvider extends ChangeNotifier {
  List<MoodEntry> _moodHistory = [];
  bool _hasSubmittedToday = false;

  // Mood options with contextual icons instead of emojis
  static const Map<String, String> moodOptions = {
    'neutral': 'Neutral',
    'anxious': 'Anxious', 
    'depressed': 'Depressed',
    'angry': 'Angry',
    'happy': 'Happy',
    'manic': 'Manic'
  };

  // Get icon for mood type
  static IconData getMoodIcon(String moodKey) {
    switch (moodKey) {
      case 'neutral':
        return Icons.horizontal_rule;
      case 'anxious':
        return Icons.cyclone; // Swirly tornado icon for anxiety
      case 'depressed':
        return Icons.trending_down;
      case 'angry':
        return Icons.flash_on;
      case 'happy':
        return Icons.sunny;
      case 'manic':
        return Icons.auto_awesome;
      default:
        return Icons.circle;
    }
  }

  List<MoodEntry> get moodHistory => _moodHistory;
  bool get hasSubmittedToday => _hasSubmittedToday;

  MoodProvider() {
    _loadMoodHistory();
  }

  Future<void> _loadMoodHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? moodData = prefs.getString('mood_history');
    
    if (moodData != null) {
      final List<dynamic> decoded = json.decode(moodData);
      _moodHistory = decoded.map((item) => MoodEntry.fromJson(item)).toList();
      _checkTodaySubmission();
      notifyListeners();
    }
  }


  Future<void> _saveMoodHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_moodHistory.map((e) => e.toJson()).toList());
    await prefs.setString('mood_history', encoded);
  }

  void _checkTodaySubmission() {
    final today = DateTime.now();
    _hasSubmittedToday = _moodHistory.any((entry) =>
        entry.date.year == today.year &&
        entry.date.month == today.month &&
        entry.date.day == today.day);
  }

  Future<bool> submitMood(String emoji, String mood, String userId) async {
    if (_hasSubmittedToday) return false;

    try {
      // Try to submit to API first
      await APIService.trackMood(
        userId: userId,
        mood: emoji,
        notes: mood,
      );

      // Add to local storage regardless of API success (for offline support)
      final entry = MoodEntry(
        mood: mood,
        emoji: emoji,
        date: DateTime.now(),
      );

      _moodHistory.add(entry);
      _hasSubmittedToday = true;
      
      await _saveMoodHistory();
      notifyListeners();
      
      return true;
    } catch (e) {
      // Still save locally if API fails
      final entry = MoodEntry(
        mood: mood,
        emoji: emoji,
        date: DateTime.now(),
      );

      _moodHistory.add(entry);
      _hasSubmittedToday = true;
      
      await _saveMoodHistory();
      notifyListeners();
      
      return false; // API failed but local save succeeded
    }
  }

  List<MoodEntry> getRecentMoods(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _moodHistory.where((entry) => entry.date.isAfter(cutoff)).toList();
  }

  double getMoodScore(String mood) {
    switch (mood) {
      case 'Happy': return 5.0;
      case 'Manic': return 4.0;
      case 'Neutral': return 3.0;
      case 'Anxious': return 2.0;
      case 'Angry': return 2.0;
      case 'Depressed': return 1.0;
      default: return 3.0;
    }
  }

  int getUniqueMoodCount() {
    final uniqueMoods = <String>{};
    for (final entry in _moodHistory) {
      uniqueMoods.add(entry.mood);
    }
    return uniqueMoods.length;
  }

  /// Reloads mood data from storage (used after data clearing)
  Future<void> loadMoodData() async {
    _moodHistory.clear();
    _hasSubmittedToday = false;
    await _loadMoodHistory();
  }
}