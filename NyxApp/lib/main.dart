import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/coping_corner_screen.dart';
import 'screens/sensory_selfcare_screen.dart';
import 'screens/resident_records_screen.dart';
import 'screens/mindful_memos_screen.dart';
import 'screens/welcome_screen.dart';
import 'providers/mood_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'services/logging_service.dart';
import 'services/notification_service.dart';
import 'services/achievement_service.dart';
import 'widgets/achievement_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging first
  await LoggingService.initialize();
  LoggingService.logInfo('🚀 Nyx App starting...');
  
  // Load environment variables from system environment
  LoggingService.logInfo('✅ Environment variables access initialized');
  LoggingService.logInfo('✅ All requests now route through Render backend');
  
  // Initialize notification service
  await NotificationService.initialize();
  LoggingService.logInfo('✅ Notification service initialized');
  
  // Initialize achievement service
  await AchievementService.initialize();
  LoggingService.logInfo('✅ Achievement service initialized');
  
  runApp(const NyxApp());
}

class NyxApp extends StatelessWidget {
  const NyxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Nyx',
            theme: themeProvider.getTheme(),
            initialRoute: '/',
            routes: {
              '/': (context) => const WelcomeScreen(),
              '/home': (context) => const AchievementOverlay(
                child: MainNavigation(),
              ),
            },
          );
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 2; // Start at Home (center)

  final List<Widget> _screens = [
    const MindfulMemosScreen(),
    const CopingCornerScreen(),
    const HomeScreen(),
    const SensorySelfcareScreen(),
    const ResidentRecordsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupAchievements();
  }

  Future<void> _initializeNotifications() async {
    // Load and apply saved notification preferences
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await NotificationService.loadAndApplyNotificationPreferences(
      userProvider.currentUserId,
    );
    LoggingService.logInfo('✅ Notification preferences loaded');
  }

  void _setupAchievements() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final moodProvider = Provider.of<MoodProvider>(context, listen: false);
    userProvider.setMoodProvider(moodProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Theme.of(context).colorScheme.outline,
        selectedLabelStyle: const TextStyle(fontSize: 10, height: 1.5),
        unselectedLabelStyle: const TextStyle(fontSize: 10, height: 1.5),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline, size: 24),
            activeIcon: Icon(Icons.lightbulb, size: 24),
            label: 'Mindful\nMemos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline, size: 24),
            activeIcon: Icon(Icons.favorite, size: 24),
            label: 'Coping\nCorner',
          ),
          BottomNavigationBarItem(
            icon: Text('𖣂', style: TextStyle(fontSize: 28)),
            activeIcon: Text('𖣂', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.games_outlined, size: 24),
            activeIcon: Icon(Icons.games, size: 24),
            label: 'Sensory\nSelfcare',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 24),
            activeIcon: Icon(Icons.person, size: 24),
            label: 'Resident\nRecords',
          ),
        ],
      ),
    );
  }
}