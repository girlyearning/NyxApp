import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';
import '../widgets/stats_card.dart';
import '../widgets/mood_summary.dart';
import '../widgets/weekly_mood_chart.dart';
import '../screens/profile_customization_screen.dart';
import 'settings_screen.dart';
import '../screens/saved_sessions_screen.dart';
import '../screens/qotd_responses_screen.dart';
import '../screens/prompt_responses_screen.dart';
import '../services/profile_service.dart';
import '../services/qotd_responses_service.dart';
import '../services/prompt_service.dart';
import '../models/profile_icon.dart';

class ResidentRecordsScreen extends StatefulWidget {
  const ResidentRecordsScreen({super.key});

  @override
  State<ResidentRecordsScreen> createState() => _ResidentRecordsScreenState();
}

class _ResidentRecordsScreenState extends State<ResidentRecordsScreen> with WidgetsBindingObserver {
  ProfileIcon? _profileIcon;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfileIcon();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh profile icon when app comes back into focus
      _loadProfileIcon();
    }
  }

  Future<void> _loadProfileIcon() async {
    try {
      final icon = await ProfileService.getSelectedIcon();
      if (mounted) {
        setState(() {
          _profileIcon = icon;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileIcon = ProfileIconData.getDefaultIcon();
          _isLoadingProfile = false;
        });
      }
    }
  }

  // Method to refresh profile icon from external sources
  Future<void> refreshProfileIcon() async {
    await _loadProfileIcon();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resident Records',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.white,
            ),
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Consumer2<UserProvider, MoodProvider>(
          builder: (context, userProvider, moodProvider, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Header
                _buildProfileHeader(context, userProvider),
                const SizedBox(height: 16), // Reduced from 24 to 16

                // Sanity & Symptoms State Charts
                Column(
                  children: [
                    // Sanity State Trends on top
                    const WeeklyMoodChart(),
                    const SizedBox(height: 16),
                  ],
                ),
                const SizedBox(height: 24),

                // Nyx Notes & Stats
                _buildStatsSection(context, userProvider, moodProvider),
                const SizedBox(height: 24),

                // Mood Summary
                const MoodSummaryWidget(),
                const SizedBox(height: 24),

                // Activity Summary
                _buildActivitySection(context, userProvider, moodProvider),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProvider userProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8), // Reduced from 12 to 8
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12), // Reduced from 16 to 12
      ),
      child: Column(
        children: [
          // Profile Avatar
          _isLoadingProfile
              ? CircleAvatar(
                  radius: 24, // Reduced from 30 to 24
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 24, // Reduced from 30 to 24
                  backgroundColor: _profileIcon!.color,
                  child: Icon(
                    _profileIcon!.icon,
                    size: 24, // Reduced from 30 to 24
                    color: Colors.white,
                  ),
                ),
          const SizedBox(height: 8), // Reduced from 12 to 8
          
          // User Name
          Text(
            userProvider.userName.isEmpty ? 'Resident' : userProvider.userName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith( // Reduced from headlineSmall to titleLarge
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4), // Reduced from 8 to 4
          
          // Member since
          Text(
            'Nyx Resident since ${DateTime.now().year}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith( // Reduced from bodyMedium to bodySmall
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8), // Reduced from 16 to 8
          
          // Edit Profile Button (smaller horizontally)
          SizedBox(
            width: 90, // Made even skinnier (was 100)
            child: ElevatedButton(
              onPressed: () => _showEditProfile(context, userProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Reduced from 24 to 20
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
              ),
              child: Text(
                'Edit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith( // Make text smaller
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, UserProvider userProvider, MoodProvider moodProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Stats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Nyx Notes',
                value: '${userProvider.nyxNotes}',
                subtitle: 'Total earned',
                icon: Icons.monetization_on,
                color: const Color(0xFFF2BFCF), // #f2bfcf
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Streak',
                value: '${_calculateStreak(moodProvider)}',
                subtitle: 'Days in a row',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedSessionsScreen(),
                    ),
                  );
                },
                child: StatsCard(
                  title: 'Sessions',
                  value: '${_calculateChatSessions()}',
                  subtitle: 'Chat sessions',
                  icon: Icons.chat,
                  color: const Color(0xFFADCF86), // #adcf86
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: FutureBuilder<int>(
                future: _calculateQotdResponses(),
                builder: (context, snapshot) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QotdResponsesScreen(),
                        ),
                      );
                    },
                    child: StatsCard(
                      title: 'QOTD\nResponses',
                      value: '${snapshot.data ?? 0}',
                      subtitle: 'Questions answered',
                      icon: Icons.psychology,
                      color: Colors.purple,
                    ),
                  );
                }
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<int>(
                future: _getPromptResponsesCount(userProvider),
                builder: (context, snapshot) {
                  return GestureDetector(
                    onTap: () => _showPromptResponses(context, userProvider),
                    child: StatsCard(
                      title: 'Prompt\nResponses',
                      value: '${snapshot.data ?? 0}',
                      subtitle: 'Journal prompts',
                      icon: Icons.lightbulb,
                      color: const Color(0xFF86ADCF), // Light blue
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildActivitySection(BuildContext context, UserProvider userProvider, MoodProvider moodProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              _buildActivityItem(
                'Last mood entry',
                _getLastMoodEntry(moodProvider),
                Icons.mood,
              ),
              const Divider(),
              _buildActivityItem(
                'Joined Nyx',
                'August 2025',
                Icons.calendar_today,
              ),
              const Divider(),
              _buildActivityItem(
                'Total app usage',
                '${_calculateAppUsage()} hours',
                Icons.access_time,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showEditProfile(BuildContext context, UserProvider userProvider) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileCustomizationScreen(),
      ),
    );
    
    // If user made changes, refresh both the display name and profile icon
    if (result == true) {
      final newName = await ProfileService.getUserDisplayName();
      await userProvider.setUserName(newName);
      
      // Reload the profile icon to prevent flashing
      await _loadProfileIcon();
    }
  }

  int _calculateStreak(MoodProvider moodProvider) {
    // Simple streak calculation - count consecutive days with mood entries
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

  int _calculateChatSessions() {
    // Placeholder - would track actual chat sessions in real app
    return 12;
  }

  String _getLastMoodEntry(MoodProvider moodProvider) {
    final recentMoods = moodProvider.moodHistory;
    if (recentMoods.isEmpty) return 'Never';
    
    final lastMood = recentMoods.last;
    final now = DateTime.now();
    final difference = now.difference(lastMood.date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  int _calculateAppUsage() {
    // Placeholder - would track actual usage time
    return 24;
  }

  Future<int> _calculateQotdResponses() async {
    return await QotdResponsesService.getTotalResponseCount();
  }
  
  Future<int> _getPromptResponsesCount(UserProvider userProvider) async {
    try {
      return await PromptService.getPromptResponseCount(userProvider.currentUserId);
    } catch (e) {
      return 0;
    }
  }
  
  void _showPromptResponses(BuildContext context, UserProvider userProvider) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PromptResponsesScreen(),
      ),
    );
  }
}