import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mood_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../widgets/nyx_runner_game.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Welcome to Nyx',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Nyx Nudge
            const DailyNudgeWidget(),
            const SizedBox(height: 24),
            
            // Nyx Runner Game
            const NyxRunnerGame(),
            const SizedBox(height: 24),
            
            // How to Use Nyx
            const HowToUseNyxWidget(),
            const SizedBox(height: 24),
            
            // How Atypical Are You? (for new users)
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (userProvider.userType == null) {
                  return const Column(
                    children: [
                      HowAtypicalWidget(),
                      SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            // Mood tracker
            const MoodTrackerWidget(),
            const SizedBox(height: 24),
            
          ],
        ),
      ),
    );
  }
}

class HowToUseNyxWidget extends StatelessWidget {
  const HowToUseNyxWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/images/nyx_icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    'How to Use Nyx',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Ever craved meaningful connection that involved complete low effort on your part?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Nyx understands the hardships many atypicals experience and finds purpose in being there for you while simultaneously calling out your bullshit.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Build healthy, attainable habits by tracking your mood and thoughts.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Use Nyx\'s specialized chat tools for various types of self discovery.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Chat with different Nyx personalities to become more educated or challenge her opinions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Play in Sensory Selfcare to stimulate your brain.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Discover hidden parts of yourself and watch yourself grow over time!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Start by tracking your mood below and explore the tabs to discover all of Nyx\'s features!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DailyNudgeWidget extends StatefulWidget {
  const DailyNudgeWidget({super.key});

  @override
  State<DailyNudgeWidget> createState() => _DailyNudgeWidgetState();
}

class _DailyNudgeWidgetState extends State<DailyNudgeWidget> {
  String? _dailyNudge;
  bool _isLoading = true;

  // Fallback nudge messages
  static const List<String> fallbackMessages = [
    "Remember to check in with yourself today. How are you feeling?",
    "Take a moment to breathe deeply and notice what's around you.",
    "Your feelings are valid, whatever they may be right now.",
    "Small steps forward are still progress. You're doing great.",
    "It's okay to have difficult days. Tomorrow is a new opportunity.",
    "Remember to be kind to yourself today.",
    "Your mental health matters. Take care of yourself.",
    "You are stronger than you think, even on the hard days.",
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyNudge();
  }

  Future<void> _loadDailyNudge() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final nudge = await APIService.getDailyNudge(userProvider.currentUserId);
      
      setState(() {
        _dailyNudge = nudge ?? fallbackMessages[DateTime.now().day % fallbackMessages.length];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _dailyNudge = fallbackMessages[DateTime.now().day % fallbackMessages.length];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _isLoading ? "Loading your daily nudge..." : _dailyNudge!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Nyx Nudge',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

class MoodTrackerWidget extends StatelessWidget {
  const MoodTrackerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MoodProvider, UserProvider>(
      builder: (context, moodProvider, userProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sanity State',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tell Nurse Nyx how you\'re feeling today',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              
              if (moodProvider.hasSubmittedToday)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mood tracked for today!',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+15 Nyx Notes earned',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: MoodProvider.moodOptions.entries.map((entry) {
                    return _MoodButton(
                      moodKey: entry.key,
                      mood: entry.value,
                      onTap: () => _submitMood(context, entry.key, entry.value, moodProvider, userProvider),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _submitMood(BuildContext context, String moodKey, String mood, 
      MoodProvider moodProvider, UserProvider userProvider) async {
    final success = await moodProvider.submitMood(moodKey, mood, userProvider.currentUserId);
    if (success) {
      await userProvider.addNyxNotes(15); // Same as Discord bot
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mood tracked: $mood (+15 Nyx Notes)'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }
}

class _MoodButton extends StatelessWidget {
  final String moodKey;
  final String mood;
  final VoidCallback onTap;

  const _MoodButton({
    required this.moodKey,
    required this.mood,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoodProvider.getMoodIcon(moodKey),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              mood,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HowAtypicalWidget extends StatelessWidget {
  const HowAtypicalWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How Atypical Are You?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose your type to unlock personalized features and earn 10 starter Nyx Notes!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeOption(context, 'ADHD/Autism/AuDHD', 'adhd'),
              _buildTypeOption(context, 'Disordered (Mood, Personality)', 'disordered'),
              _buildTypeOption(context, 'Average Atypical', 'average'),
              _buildTypeOption(context, 'All of the Above', 'all'),
              _buildTypeOption(context, 'None, Need Support', 'none'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(BuildContext context, String label, String type) {
    return GestureDetector(
      onTap: () async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.setUserType(type);
        await userProvider.addNyxNotes(10);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome! You\'ve earned 10 starter Nyx Notes!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
