import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'notification_settings_screen.dart';
import 'about_screen.dart';
import 'achievements_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../providers/mood_provider.dart';
import '../services/logging_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyNudgesEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyNudgesEnabled = prefs.getBool('daily_nudge_enabled') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleDailyNudges(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_nudge_enabled', value);
    setState(() {
      _dailyNudgesEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsSection(
            'Notifications',
            [
              SwitchListTile(
                secondary: Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary),
                title: const Text('Daily Nudges'),
                subtitle: const Text('Receive daily reminders'),
                value: _dailyNudgesEnabled,
                onChanged: _toggleDailyNudges,
              ),
              ListTile(
                leading: Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary),
                title: const Text('Notification Times'),
                subtitle: const Text('Customize when to receive reminders'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSettingsSection(
            'Appearance',
            [
              ListTile(
                leading: Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                title: const Text('Theme'),
                subtitle: const Text('Change app color theme'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.outline),
                onTap: () => _showThemeSelector(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSettingsSection(
            'Features',
            [
              ListTile(
                leading: Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
                title: const Text('Achievements'),
                subtitle: const Text('View all achievements and progress'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AchievementsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSettingsSection(
            'Privacy',
            [
              ListTile(
                leading: Icon(Icons.clear_all, color: Theme.of(context).colorScheme.primary),
                title: const Text('Clear Data'),
                subtitle: const Text('Reset all app data'),
                onTap: () => _showClearDataDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSettingsSection(
            'About',
            [
              ListTile(
                leading: Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                title: const Text('About Nyx'),
                subtitle: const Text('Learn more about the app'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.outline),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.verified, color: Theme.of(context).colorScheme.primary),
                title: const Text('Version'),
                subtitle: const Text('1.2.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Theme',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildThemeOption(context, 'Green (Default)', AppThemeMode.green),
                _buildThemeOption(context, 'Red', AppThemeMode.red),
                _buildThemeOption(context, 'Orange', AppThemeMode.orange),
                _buildThemeOption(context, 'Blue', AppThemeMode.blue),
                _buildThemeOption(context, 'Purple', AppThemeMode.purple),
                _buildThemeOption(context, 'Light Purple', AppThemeMode.lightPurple),
                _buildThemeOption(context, 'Pink', AppThemeMode.pink),
                _buildThemeOption(context, 'Light', AppThemeMode.light),
                _buildThemeOption(context, 'Dark', AppThemeMode.dark),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String name, AppThemeMode mode) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSelected = themeProvider.themeMode == mode;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        themeProvider.setTheme(mode);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme changed to $name'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getThemeColor(mode),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getThemeColor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.red:
        return const Color(0xFF690808);
      case AppThemeMode.orange:
        return const Color(0xFFAD570C);
      case AppThemeMode.green:
        return const Color(0xFFAECFB6);
      case AppThemeMode.blue:
        return const Color(0xFF4569A3);
      case AppThemeMode.purple:
        return const Color(0xFF460E5C);
      case AppThemeMode.lightPurple:
        return const Color(0xFF9e8df1);
      case AppThemeMode.pink:
        return const Color(0xFF911352);
      case AppThemeMode.light:
        return Colors.grey;
      case AppThemeMode.dark:
        return Colors.black;
    }
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: const Text('This feature will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete ALL your data including:\n\n• Chat history & saved sessions\n• Journal entries & folders\n• Nyx Notes balance\n• Game scores & progress\n• QOTD & prompt responses\n• QYK Notes & infodumps\n• Achievements & progress\n• Mood tracking data\n• App settings & preferences\n\nThis action cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDataClear(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDataClear(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Clearing all data...'),
          ],
        ),
      ),
    );

    try {
      bool success = await _clearAllUserData();
      
      Navigator.pop(context); // Close loading dialog
      
      if (success) {
        // Reset providers to their initial state
        if (mounted) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final moodProvider = Provider.of<MoodProvider>(context, listen: false);
          
          // Trigger reload of user data and mood data
          await userProvider.refreshUserData();
          await moodProvider.loadMoodData();
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All data has been cleared successfully! 🧹'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to clear some data. Please try again.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      LoggingService.logError('Error in data clearing process: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Clears all user data including chat history, journal entries, Nyx Notes, 
  /// saved games, achievements, and all other user-generated content
  Future<bool> _clearAllUserData() async {
    try {
      LoggingService.logInfo('🧹 Starting comprehensive data clearing...');
      
      // Clear SharedPreferences data
      await _clearSharedPreferences();
      
      // Clear any local files in app directory
      await _clearLocalFiles();
      
      LoggingService.logInfo('✅ All user data cleared successfully');
      return true;
    } catch (e) {
      LoggingService.logError('❌ Error clearing user data: $e');
      return false;
    }
  }

  /// Clears all SharedPreferences data
  Future<void> _clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys before clearing to log what we're removing
      final allKeys = prefs.getKeys();
      LoggingService.logInfo('📋 Found ${allKeys.length} SharedPreferences keys to clear');
      
      // Clear everything
      await prefs.clear();
      
      LoggingService.logInfo('🗑️ Cleared SharedPreferences data:');
      LoggingService.logInfo('   - User profile data (name, ID, type, created date)');
      LoggingService.logInfo('   - Nyx Notes balance and transactions');
      LoggingService.logInfo('   - Chat history and saved sessions');
      LoggingService.logInfo('   - Journal entries and folders');
      LoggingService.logInfo('   - QOTD responses and prompt responses');
      LoggingService.logInfo('   - QYK Notes and infodumps');
      LoggingService.logInfo('   - Game scores and achievements');
      LoggingService.logInfo('   - Mood tracking data');
      LoggingService.logInfo('   - Theme and app settings');
      LoggingService.logInfo('   - Notification preferences');
      LoggingService.logInfo('   - Session management data');
    } catch (e) {
      LoggingService.logError('Error clearing SharedPreferences: $e');
      rethrow;
    }
  }

  /// Clears any local files stored in app directory
  Future<void> _clearLocalFiles() async {
    try {
      // Clear application documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      if (await appDocDir.exists()) {
        final files = appDocDir.listSync();
        for (final file in files) {
          if (file is File) {
            try {
              await file.delete();
              LoggingService.logInfo('🗑️ Deleted file: ${file.path}');
            } catch (e) {
              LoggingService.logWarning('Failed to delete file ${file.path}: $e');
            }
          }
        }
      }

      // Clear application support directory
      try {
        final appSupportDir = await getApplicationSupportDirectory();
        if (await appSupportDir.exists()) {
          final files = appSupportDir.listSync();
          for (final file in files) {
            if (file is File) {
              try {
                await file.delete();
                LoggingService.logInfo('🗑️ Deleted support file: ${file.path}');
              } catch (e) {
                LoggingService.logWarning('Failed to delete support file ${file.path}: $e');
              }
            }
          }
        }
      } catch (e) {
        // Application support directory may not exist on all platforms
        LoggingService.logInfo('Application support directory not available or accessible');
      }

      LoggingService.logInfo('📁 Local file cleanup completed');
    } catch (e) {
      LoggingService.logError('Error clearing local files: $e');
      // Don't rethrow - file clearing is less critical than SharedPreferences
    }
  }
}