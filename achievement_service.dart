import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';
import '../widgets/achievements_section.dart';

class AchievementService {
  static final StreamController<Achievement> _achievementController = 
      StreamController<Achievement>.broadcast();
  
  static Stream<Achievement> get achievementStream => _achievementController.stream;

  static final Map<String, bool> _unlockedAchievements = {};
  static const String _prefsKey = 'unlocked_achievements';
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = prefs.getString(_prefsKey);
      
      if (achievementsJson != null) {
        final Map<String, dynamic> achievementsMap = jsonDecode(achievementsJson);
        _unlockedAchievements.clear();
        achievementsMap.forEach((key, value) {
          _unlockedAchievements[key] = value as bool;
        });
      }
      
      _isInitialized = true;
    } catch (e) {
      // If there's an error loading, just start with empty achievements
      _unlockedAchievements.clear();
      _isInitialized = true;
    }
  }

  static Future<void> _saveUnlockedAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = jsonEncode(_unlockedAchievements);
      await prefs.setString(_prefsKey, achievementsJson);
    } catch (e) {
      // Silently fail if we can't save - not critical
    }
  }

  static List<Achievement> _getAllPossibleAchievements(
      UserProvider userProvider, MoodProvider moodProvider) {
    final achievements = <Achievement>[];
    final currentStreak = _calculateStreak(moodProvider);
    final uniqueMoods = moodProvider.getUniqueMoodCount();
    final accountAge = DateTime.now()
        .difference(userProvider.createdAt ?? DateTime.now())
        .inDays;

    // Starting Achievements
    achievements.add(Achievement(
      title: 'First Conversation',
      description: 'Start your first chat with Nyx',
      icon: Icons.chat,
      color: Colors.teal,
      isUnlocked: (userProvider.chatSessions ?? 0) >= 1,
    ));

    achievements.add(Achievement(
      title: 'Dear Diary',
      description: 'Write your first journal entry',
      icon: Icons.book,
      color: Colors.brown,
      isUnlocked: (userProvider.journalEntries ?? 0) >= 1,
    ));

    achievements.add(Achievement(
      title: 'Game On',
      description: 'Play your first game',
      icon: Icons.sports_esports,
      color: Colors.lime,
      isUnlocked: (userProvider.gamesPlayed ?? 0) >= 1,
    ));

    achievements.add(Achievement(
      title: 'Quick Thinker',
      description: 'Create your first Qyk Note',
      icon: Icons.flash_on,
      color: Colors.yellow[700]!,
      isUnlocked: userProvider.qykNotes >= 1,
    ));

    // Notes Achievements
    achievements.add(Achievement(
      title: 'Note Gatherer',
      description: 'Earn 50 Nyx Notes',
      icon: Icons.star,
      color: Colors.yellow[600]!,
      isUnlocked: userProvider.nyxNotes >= 50,
    ));

    achievements.add(Achievement(
      title: 'Note Collector',
      description: 'Earn 100 Nyx Notes',
      icon: Icons.monetization_on,
      color: Colors.amber,
      isUnlocked: userProvider.nyxNotes >= 100,
    ));

    achievements.add(Achievement(
      title: 'Note Enthusiast',
      description: 'Earn 250 Nyx Notes',
      icon: Icons.grade,
      color: Colors.amber[700]!,
      isUnlocked: userProvider.nyxNotes >= 250,
    ));

    achievements.add(Achievement(
      title: 'Note Hoarder',
      description: 'Earn 500 Nyx Notes',
      icon: Icons.savings,
      color: Color(0xFF87A96B), // Sage green
      isUnlocked: userProvider.nyxNotes >= 500,
    ));

    achievements.add(Achievement(
      title: 'Note Master',
      description: 'Earn 1000 Nyx Notes',
      icon: Icons.workspace_premium,
      color: Colors.deepPurple,
      isUnlocked: userProvider.nyxNotes >= 1000,
    ));

    // Streak Achievements
    achievements.add(Achievement(
      title: 'Consistency',
      description: 'Maintain a 3-day streak',
      icon: Icons.local_fire_department,
      color: Color(0xFF87A96B), // Sage green
      isUnlocked: currentStreak >= 3,
    ));

    achievements.add(Achievement(
      title: 'Week Warrior',
      description: 'Maintain a 7-day streak',
      icon: Icons.whatshot,
      color: Colors.red,
      isUnlocked: currentStreak >= 7,
    ));

    // Activity Achievements
    achievements.add(Achievement(
      title: 'Chatty Friend',
      description: 'Have 10 conversations with Nyx',
      icon: Icons.forum,
      color: Colors.cyan,
      isUnlocked: (userProvider.chatSessions ?? 0) >= 10,
    ));

    achievements.add(Achievement(
      title: 'Thoughtful Writer',
      description: 'Write 5 journal entries',
      icon: Icons.edit_note,
      color: Colors.brown[600]!,
      isUnlocked: (userProvider.journalEntries ?? 0) >= 5,
    ));

    achievements.add(Achievement(
      title: 'Casual Gamer',
      description: 'Play 10 games',
      icon: Icons.videogame_asset,
      color: Colors.lightGreen,
      isUnlocked: (userProvider.gamesPlayed ?? 0) >= 10,
    ));

    achievements.add(Achievement(
      title: 'Emotional Explorer',
      description: 'Track 3 different moods',
      icon: Icons.explore,
      color: Colors.teal[400]!,
      isUnlocked: uniqueMoods >= 3,
    ));

    achievements.add(Achievement(
      title: 'Feeling Finder',
      description: 'Track 5 different moods',
      icon: Icons.sentiment_satisfied,
      color: Colors.indigo[400]!,
      isUnlocked: uniqueMoods >= 5,
    ));

    // Time-based Achievements
    achievements.add(Achievement(
      title: 'One Week Strong',
      description: 'Be a resident for 7 days',
      icon: Icons.access_time,
      color: Colors.grey[600]!,
      isUnlocked: accountAge >= 7,
    ));

    achievements.add(Achievement(
      title: 'Monthly Resident',
      description: 'Be a resident for 30 days',
      icon: Icons.schedule,
      color: Colors.blueGrey,
      isUnlocked: accountAge >= 30,
    ));

    return achievements;
  }

  static Future<void> checkForNewAchievements(
      UserProvider userProvider, MoodProvider moodProvider) async {
    // Ensure we're initialized before checking achievements
    await initialize();
    
    final achievements = _getAllPossibleAchievements(userProvider, moodProvider);
    bool hasNewAchievements = false;

    for (final achievement in achievements) {
      if (achievement.isUnlocked && 
          !(_unlockedAchievements[achievement.title] ?? false)) {
        _unlockedAchievements[achievement.title] = true;
        hasNewAchievements = true;
        
        // Award Nyx Notes based on achievement type
        int nyxNotesReward = _getNyxNotesReward(achievement.title);
        userProvider.addNyxNotes(nyxNotesReward);
        
        // Create achievement with reward info
        final achievementWithReward = Achievement(
          title: achievement.title,
          description: achievement.description,
          icon: achievement.icon,
          color: achievement.color,
          isUnlocked: achievement.isUnlocked,
          nyxNotesReward: nyxNotesReward,
        );
        
        _achievementController.add(achievementWithReward);
      }
    }
    
    // Save to persistent storage if we have new achievements
    if (hasNewAchievements) {
      await _saveUnlockedAchievements();
    }
  }

  static int _getNyxNotesReward(String achievementTitle) {
    // Starting achievements
    if (['First Conversation', 'Dear Diary', 'Game On', 'Quick Thinker']
        .contains(achievementTitle)) {
      return 25;
    }
    
    // Check-in milestones
    if (['Getting Started', 'Regular Visitor'].contains(achievementTitle)) {
      return 50;
    }
    if (['Committed Soul', 'Dedicated Resident'].contains(achievementTitle)) {
      return 75;
    }
    if (achievementTitle == 'Centurion') {
      return 100;
    }
    
    // Notes achievements (no additional reward since they're based on notes earned)
    if (['Note Gatherer', 'Note Collector', 'Note Enthusiast', 'Note Hoarder', 'Note Master']
        .contains(achievementTitle)) {
      return 0;
    }
    
    // Streak achievements
    if (['Consistency', 'Week Warrior'].contains(achievementTitle)) {
      return 40;
    }
    
    // Activity achievements
    if (['Chatty Friend', 'Thoughtful Writer', 'Casual Gamer', 
         'Emotional Explorer', 'Feeling Finder'].contains(achievementTitle)) {
      return 35;
    }
    
    // Time-based achievements
    if (['One Week Strong', 'Monthly Resident'].contains(achievementTitle)) {
      return 50;
    }
    
    return 25; // Default reward
  }

  static int _calculateStreak(MoodProvider moodProvider) {
    final recentMoods = moodProvider.getRecentMoods(30);
    if (recentMoods.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final dayMoods = recentMoods.where((mood) {
        return mood.date.year == checkDate.year &&
            mood.date.month == checkDate.month &&
            mood.date.day == checkDate.day;
      }).toList();

      if (dayMoods.isNotEmpty) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  static void dispose() {
    _achievementController.close();
  }
}