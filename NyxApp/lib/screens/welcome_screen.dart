import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart';
import '../services/logging_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _displayName = '';
  bool _isNewUser = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    
    _loadUserStatus();
  }
  
  Future<void> _loadUserStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final displayName = await ProfileService.getUserDisplayName();
    
    // Determine if user is new based on multiple factors
    final isNew = (userProvider.chatSessions ?? 0) == 0 && 
                  (userProvider.journalEntries ?? 0) == 0 && 
                  (userProvider.gamesPlayed ?? 0) == 0 && 
                  userProvider.nyxNotes == 0 &&
                  (displayName == 'Anonymous User' || displayName.isEmpty);
    
    setState(() {
      _displayName = displayName == 'Anonymous User' ? 'Resident' : displayName;
      _isNewUser = isNew;
      _isLoading = false;
    });
    
    _controller.forward();
    
    // Request permissions for new users
    if (isNew) {
      LoggingService.logInfo('👋 New user detected, requesting permissions...');
      await _requestPermissionsForNewUser();
    }
    
    // Navigate to home after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }
  
  Future<void> _requestPermissionsForNewUser() async {
    try {
      LoggingService.logInfo('🔔 Requesting notification permissions for new user...');
      
      // Request notification permissions
      final notificationGranted = await NotificationService.requestPermissions();
      
      if (notificationGranted) {
        LoggingService.logInfo('✅ Permissions granted for new user');
        // Set up default notification preferences
        await NotificationService.saveNotificationPreferences(
          dailyNudgeEnabled: true,
          dailyNudgeHour: 9,
          dailyNudgeMinute: 0,
          morningMoodEnabled: true,
          morningMoodHour: 8,
          morningMoodMinute: 0,
          eveningMoodEnabled: true,
          eveningMoodHour: 20,
          eveningMoodMinute: 0,
        );
        
        // Apply notification settings
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await NotificationService.loadAndApplyNotificationPreferences(userProvider.currentUserId);
        
        LoggingService.logInfo('✅ Default notifications scheduled for new user');
      } else {
        LoggingService.logWarning('⚠️ Notification permissions denied by new user');
      }
    } catch (e) {
      LoggingService.logError('❌ Error requesting permissions for new user: $e');
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A7C59), // Dark sage green
              Color(0xFFC8D5B9), // Light sage green
            ],
          ),
        ),
        child: Center(
          child: _isLoading 
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isNewUser) ...[
                        Text(
                          'Welcome to Nyx,',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Your Atypical Mental Health\nPocket Companion!',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Welcome back,',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _displayName,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.7),
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
}