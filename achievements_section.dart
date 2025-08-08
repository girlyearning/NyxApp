import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';

class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, MoodProvider>(
      builder: (context, userProvider, moodProvider, child) {
        final achievements = _getAchievements(context, userProvider, moodProvider);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achievements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            if (achievements.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start your journey!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track your mood and earn your first achievement',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: achievements.map((achievement) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AchievementCard(achievement: achievement),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }

  List<Achievement> _getAchievements(BuildContext context, UserProvider userProvider, MoodProvider moodProvider) {
    final achievements = <Achievement>[];
    
    
    // Nyx Notes Achievements
    if (userProvider.nyxNotes >= 100) {
      achievements.add(Achievement(
        title: 'Note Collector',
        description: 'Earned 100 Nyx Notes',
        icon: Icons.monetization_on,
        color: Colors.amber,
        isUnlocked: true,
      ));
    }
    
    if (userProvider.nyxNotes >= 500) {
      achievements.add(Achievement(
        title: 'Note Hoarder',
        description: 'Earned 500 Nyx Notes',
        icon: Icons.savings,
        color: Theme.of(context).colorScheme.primary,
        isUnlocked: true,
      ));
    }
    
    // Streak Achievements
    final currentStreak = _calculateStreak(moodProvider);
    if (currentStreak >= 3) {
      achievements.add(Achievement(
        title: 'Consistency',
        description: 'Maintained a 3-day streak',
        icon: Icons.local_fire_department,
        color: Theme.of(context).colorScheme.primary,
        isUnlocked: true,
      ));
    }
    
    if (currentStreak >= 7) {
      achievements.add(Achievement(
        title: 'Week Warrior',
        description: 'Maintained a 7-day streak',
        icon: Icons.whatshot,
        color: Colors.red,
        isUnlocked: true,
      ));
    }
    
    
    return achievements;
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

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final int? nyxNotesReward;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    this.nyxNotesReward,
  });
}

class AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const AchievementCard({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !achievement.isUnlocked;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked 
            ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
            : achievement.color.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLocked 
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)
                : achievement.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLocked ? Icons.lock : achievement.icon,
              color: isLocked 
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                : achievement.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLocked 
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                      : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLocked 
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: achievement.isUnlocked 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              achievement.isUnlocked ? 'Unlocked' : 'Locked',
              style: TextStyle(
                color: achievement.isUnlocked 
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}