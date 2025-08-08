import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';
import '../widgets/achievements_section.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Achievements',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Consumer2<UserProvider, MoodProvider>(
        builder: (context, userProvider, moodProvider, child) {
          final allAchievements = _getAllPossibleAchievements(userProvider, moodProvider);
          final unlockedCount = allAchievements.where((a) => a.isUnlocked).length;
          final totalCount = allAchievements.length;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Achievement Progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$unlockedCount / $totalCount Unlocked',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: totalCount > 0 ? unlockedCount / totalCount : 0,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${((unlockedCount / totalCount) * 100).toStringAsFixed(1)}% Complete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Achievement Categories
                _buildAchievementCategory(
                  context,
                  'Getting Started',
                  Icons.rocket_launch,
                  Colors.pink,
                  _getStartingAchievements(allAchievements),
                ),
                
                _buildAchievementCategory(
                  context,
                  'Nyx Notes',
                  Icons.monetization_on,
                  Colors.amber,
                  _getNotesAchievements(allAchievements),
                ),
                
                _buildAchievementCategory(
                  context,
                  'Streaks & Consistency',
                  Icons.local_fire_department,
                  Color(0xFF87A96B), // Sage green
                  _getStreakAchievements(allAchievements),
                ),
                
                _buildAchievementCategory(
                  context,
                  'Activities',
                  Icons.sports_esports,
                  Colors.green,
                  _getActivityAchievements(allAchievements),
                ),
                
                _buildAchievementCategory(
                  context,
                  'Time & Dedication',
                  Icons.access_time,
                  Colors.purple,
                  _getTimeAchievements(allAchievements),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAchievementCategory(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Achievement> achievements,
  ) {
    if (achievements.isEmpty) return const SizedBox.shrink();
    
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unlockedCount/${achievements.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Achievement Cards
        ...achievements.map((achievement) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AchievementCard(achievement: achievement),
          );
        }).toList(),
        
        const SizedBox(height: 20),
      ],
    );
  }

  List<Achievement> _getAllPossibleAchievements(UserProvider userProvider, MoodProvider moodProvider) {
    final achievements = <Achievement>[];
    final currentStreak = _calculateStreak(moodProvider);
    final uniqueMoods = moodProvider.getUniqueMoodCount();
    final accountAge = DateTime.now().difference(userProvider.createdAt ?? DateTime.now()).inDays;
    
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
    
    achievements.add(Achievement(
      title: 'Fortnight Focus',
      description: 'Maintain a 14-day streak',
      icon: Icons.local_fire_department,
      color: Color(0xFF6B8E47), // Darker sage green
      isUnlocked: currentStreak >= 14,
    ));
    
    achievements.add(Achievement(
      title: 'Monthly Momentum',
      description: 'Maintain a 30-day streak',
      icon: Icons.fireplace,
      color: Colors.red[700]!,
      isUnlocked: currentStreak >= 30,
    ));
    
    achievements.add(Achievement(
      title: 'Unstoppable Force',
      description: 'Maintain a 60-day streak',
      icon: Icons.bolt,
      color: Colors.purple,
      isUnlocked: currentStreak >= 60,
    ));
    
    achievements.add(Achievement(
      title: 'Streak Legend',
      description: 'Maintain a 100-day streak',
      icon: Icons.auto_awesome,
      color: Colors.indigo,
      isUnlocked: currentStreak >= 100,
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
      title: 'Deep Thinker',
      description: 'Have 50 conversations with Nyx',
      icon: Icons.psychology_alt,
      color: Colors.blue[600]!,
      isUnlocked: (userProvider.chatSessions ?? 0) >= 50,
    ));
    
    achievements.add(Achievement(
      title: 'Thoughtful Writer',
      description: 'Write 5 journal entries',
      icon: Icons.edit_note,
      color: Colors.brown[600]!,
      isUnlocked: (userProvider.journalEntries ?? 0) >= 5,
    ));
    
    achievements.add(Achievement(
      title: 'Prolific Author',
      description: 'Write 25 journal entries',
      icon: Icons.menu_book,
      color: Colors.deepPurple[400]!,
      isUnlocked: (userProvider.journalEntries ?? 0) >= 25,
    ));
    
    achievements.add(Achievement(
      title: 'Casual Gamer',
      description: 'Play 10 games',
      icon: Icons.videogame_asset,
      color: Colors.lightGreen,
      isUnlocked: (userProvider.gamesPlayed ?? 0) >= 10,
    ));
    
    achievements.add(Achievement(
      title: 'Gaming Enthusiast',
      description: 'Play 50 games',
      icon: Icons.casino,
      color: Colors.green,
      isUnlocked: (userProvider.gamesPlayed ?? 0) >= 50,
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
    
    achievements.add(Achievement(
      title: 'Veteran Resident',
      description: 'Be a resident for 1 year',
      icon: Icons.celebration,
      color: Colors.amber[800]!,
      isUnlocked: accountAge >= 365,
    ));
    
    return achievements;
  }

  List<Achievement> _getStartingAchievements(List<Achievement> all) {
    final startingTitles = {'First Steps', 'First Conversation', 'Dear Diary', 'Game On'};
    return all.where((a) => startingTitles.contains(a.title)).toList();
  }


  List<Achievement> _getNotesAchievements(List<Achievement> all) {
    final notesTitles = {'Note Gatherer', 'Note Collector', 'Note Enthusiast', 'Note Hoarder', 'Note Master'};
    return all.where((a) => notesTitles.contains(a.title)).toList();
  }

  List<Achievement> _getStreakAchievements(List<Achievement> all) {
    final streakTitles = {'Consistency', 'Week Warrior', 'Fortnight Focus', 'Monthly Momentum', 'Unstoppable Force', 'Streak Legend'};
    return all.where((a) => streakTitles.contains(a.title)).toList();
  }

  List<Achievement> _getActivityAchievements(List<Achievement> all) {
    final activityTitles = {'Chatty Friend', 'Deep Thinker', 'Thoughtful Writer', 'Prolific Author', 'Casual Gamer', 'Gaming Enthusiast', 'Emotional Explorer', 'Feeling Finder'};
    return all.where((a) => activityTitles.contains(a.title)).toList();
  }

  List<Achievement> _getTimeAchievements(List<Achievement> all) {
    final timeTitles = {'One Week Strong', 'Monthly Resident', 'Veteran Resident'};
    return all.where((a) => timeTitles.contains(a.title)).toList();
  }

  int _calculateStreak(MoodProvider moodProvider) {
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
}