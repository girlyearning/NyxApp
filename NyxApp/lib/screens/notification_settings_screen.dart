import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _notificationsEnabled = false;
  
  // Daily Nudge settings
  bool _dailyNudgeEnabled = true;
  TimeOfDay _dailyNudgeTime = const TimeOfDay(hour: 9, minute: 0);
  
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _notificationsEnabled = await NotificationService.areNotificationsEnabled();
    
    // Load saved preferences
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _dailyNudgeEnabled = prefs.getBool('daily_nudge_enabled') ?? true;
      final nudgeHour = prefs.getInt('daily_nudge_hour') ?? 9;
      final nudgeMinute = prefs.getInt('daily_nudge_minute') ?? 0;
      _dailyNudgeTime = TimeOfDay(hour: nudgeHour, minute: nudgeMinute);
      
      
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await NotificationService.requestPermissions();
    if (granted) {
      setState(() {
        _notificationsEnabled = true;
      });
      // Apply the settings that were configured while notifications were disabled
      _saveAndApplySettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications enabled! Your settings have been applied.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _disableNotifications() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Notifications'),
        content: const Text('This will cancel all scheduled notifications and disable notification permissions. You can re-enable them later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Cancel all notifications
      await NotificationService.cancelAllNotifications();
      
      setState(() {
        _notificationsEnabled = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications have been disabled and cleared.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _selectTime(TimeOfDay currentTime, Function(TimeOfDay) onTimeSelected) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    
    if (picked != null && picked != currentTime) {
      setState(() {
        onTimeSelected(picked);
      });
      _saveAndApplySettings();
    }
  }

  Future<void> _saveAndApplySettings() async {
    // Save settings regardless of notification state
    // This allows users to configure settings before enabling notifications

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    await NotificationService.saveNotificationPreferences(
      dailyNudgeEnabled: _dailyNudgeEnabled,
      dailyNudgeHour: _dailyNudgeTime.hour,
      dailyNudgeMinute: _dailyNudgeTime.minute,
      morningMoodEnabled: false,
      morningMoodHour: 8,
      morningMoodMinute: 0,
      eveningMoodEnabled: false,
      eveningMoodHour: 20,
      eveningMoodMinute: 0,
    );
    
    // Only schedule notifications if they are enabled
    if (_notificationsEnabled) {
      await NotificationService.loadAndApplyNotificationPreferences(
        userProvider.currentUserId,
      );
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
          'Notification Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permissions Section
            if (!_notificationsEnabled) ...[
              Card(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Notifications are disabled',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable notifications to receive daily nudges',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        child: const Text('Enable Notifications'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Daily Nudge Section
            _buildSectionHeader('Daily Nyx Nudge'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Daily Nudge'),
                    subtitle: Text(_notificationsEnabled 
                        ? 'Receive a supportive message each day'
                        : 'Enable notifications first to activate'),
                    value: _dailyNudgeEnabled && _notificationsEnabled,
                    onChanged: _notificationsEnabled ? (value) {
                      setState(() {
                        _dailyNudgeEnabled = value;
                      });
                      _saveAndApplySettings();
                    } : null,
                  ),
                  if (_dailyNudgeEnabled) ...[
                    const Divider(),
                    ListTile(
                      title: const Text('Time'),
                      subtitle: Text(_formatTime(_dailyNudgeTime)),
                      trailing: const Icon(Icons.access_time),
                      enabled: _notificationsEnabled,
                      onTap: _notificationsEnabled
                          ? () => _selectTime(_dailyNudgeTime, (time) {
                                _dailyNudgeTime = time;
                              })
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            
            
            const SizedBox(height: 24),
            
            // Test Notification Section
            if (_notificationsEnabled) ...[
              Card(
                color: Colors.blue.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Test if notifications are working on your device',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await NotificationService.showTestNotification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent! Check if you received it.'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Send Test Notification'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Info Section
            Card(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Notifications will be sent at your local time. Make sure your device time zone is set correctly.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Disable Notifications Option (when enabled)
            if (_notificationsEnabled) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_off,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Disable all notifications and clear scheduled reminders',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _disableNotifications,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Disable All Notifications'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }
}