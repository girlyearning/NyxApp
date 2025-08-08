import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';
import 'dart:io';
import '../services/api_service.dart';
import '../services/logging_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Notification IDs
  static const int dailyNudgeId = 1;
  static const int morningMoodId = 2;
  static const int eveningMoodId = 3;

  // Notification channel info
  static const String channelId = 'nyx_notifications';
  static const String channelName = 'Nyx Notifications';
  static const String channelDescription = 'Mental health reminders and daily nudges from Nyx';

  // Daily nudge messages for offline mode - authentic Nyx personality
  static const List<String> dailyNudgeMessages = [
    "Another day of being human. How's that going for you so far?",
    "Time for your contractually obligated check-in. Seriously though, how are you holding up?",
    "Your feelings today are valid, even the messy complicated ones. What's going on?",
    "I've seen people have worse days than this. Still, how are you managing right now?",
    "Well, you made it through another night. That's something. How are we feeling today?",
    "Reality check time - and I mean that in the gentlest way possible. How are you doing?",
    "Not gonna lie, being a person is weird sometimes. How's your version of weird going?",
    "Your mental health nurse checking in. What does taking care of yourself look like today?",
    "Some days are survival days, some are thriving days. Which kind is today for you?",
    "It's okay if today feels heavy. I'm here either way. What's on your mind?",
    "Progress isn't linear, and that's annoyingly normal. How are you navigating today?",
    "You don't have to be okay all the time. Really. How are you actually doing right now?",
    "Another plot twist in the ongoing series that is your life. How are you handling this episode?",
    "Your asylum nurse here with a gentle reminder that you matter. How's your day treating you?",
    "Some days we thrive, some days we survive. Both count. Which one is today?",
    "Real talk: being human is complicated. How are you working through the complications today?",
    "I've seen every type of day there is. None of them define you. How's yours going?",
    "Checking in because that's what I do. But also because I genuinely want to know - how are you?",
    "Life keeps happening whether we're ready or not. How are you keeping up with it all?",
    "Your feelings are information, not instructions. What are they telling you today?",
  ];

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    
    // Set the local timezone properly
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      LoggingService.logInfo('✅ Timezone set to: $timeZoneName');
    } catch (e) {
      LoggingService.logError('❌ Failed to get timezone: $e');
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.UTC);
    }

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request manually
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    _isInitialized = true;
    LoggingService.logInfo('✅ Notification service fully initialized');
  }

  static Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 106, 190, 175), // Nyx primary color
      );

      await androidImplementation.createNotificationChannel(channel);
      LoggingService.logInfo('✅ Android notification channel created');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to specific screens
    // For now, just opening the app is sufficient
  }

  /// Guide users through enabling background app refresh and notification settings
  static Future<void> showBackgroundSettingsGuide() async {
    if (Platform.isAndroid) {
      LoggingService.logInfo('📱 Android Background Settings Guide:');
      LoggingService.logInfo('1. Go to Settings > Apps > Nyx > Battery');
      LoggingService.logInfo('2. Turn OFF "Optimize battery usage" or add Nyx to whitelist');
      LoggingService.logInfo('3. Go to Settings > Apps > Nyx > Notifications');
      LoggingService.logInfo('4. Ensure notifications are enabled');
      LoggingService.logInfo('5. Go to Settings > Battery > Battery Optimization');
      LoggingService.logInfo('6. Find Nyx and select "Don\'t optimize"');
      LoggingService.logInfo('7. Go to Settings > Apps > Special Access > Schedule exact alarm');
      LoggingService.logInfo('8. Enable for Nyx app');
    } else if (Platform.isIOS) {
      LoggingService.logInfo('📱 iOS Background Settings Guide:');
      LoggingService.logInfo('1. Go to Settings > Nyx > Background App Refresh');
      LoggingService.logInfo('2. Enable Background App Refresh');
      LoggingService.logInfo('3. Go to Settings > Notifications > Nyx');
      LoggingService.logInfo('4. Enable Allow Notifications');
      LoggingService.logInfo('5. Enable all notification styles (Badges, Sounds, Banners)');
    }
  }

  /// Check if all necessary permissions and settings are enabled
  static Future<Map<String, bool>> checkAllSettings() async {
    final results = <String, bool>{};
    
    try {
      // Check notification permission
      final notificationStatus = await Permission.notification.status;
      results['notifications'] = notificationStatus.isGranted;
      
      // Check battery optimization (Android only)
      if (Platform.isAndroid) {
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        results['battery_optimization'] = batteryStatus.isGranted;
        
        // Check exact alarm permission
        try {
          final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          if (androidImplementation != null) {
            final exactAlarmGranted = await androidImplementation.canScheduleExactNotifications();
            results['exact_alarms'] = exactAlarmGranted ?? false;
          }
        } catch (e) {
          results['exact_alarms'] = false;
        }
      }
      
      LoggingService.logInfo('📱 Settings check results: $results');
      return results;
    } catch (e) {
      LoggingService.logError('❌ Error checking settings: $e');
      return results;
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      LoggingService.logInfo('🔔 Requesting notification permissions...');
      
      if (Platform.isIOS) {
        final bool? result = await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: false,
            );
        
        final granted = result ?? false;
        LoggingService.logInfo(granted ? '✅ iOS permissions granted' : '❌ iOS permissions denied');
        return granted;
        
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        bool allPermissionsGranted = true;
        
        // Request notification permission first (Android 13+)
        final notificationStatus = await Permission.notification.request();
        if (!notificationStatus.isGranted) {
          LoggingService.logError('❌ Android notification permission denied');
          allPermissionsGranted = false;
        } else {
          LoggingService.logInfo('✅ Android notification permission granted');
        }
        
        // Request battery optimization exemption to ensure background notifications work
        try {
          final batteryOptStatus = await Permission.ignoreBatteryOptimizations.request();
          if (!batteryOptStatus.isGranted) {
            LoggingService.logWarning('⚠️ Battery optimization exemption denied - notifications may not work in background');
          } else {
            LoggingService.logInfo('✅ Battery optimization exemption granted');
          }
        } catch (e) {
          LoggingService.logError('❌ Failed to request battery optimization exemption: $e');
        }
        
        // Request exact alarm permission for Android 12+ (API 31+)
        if (androidImplementation != null) {
          try {
            final exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
            if (exactAlarmGranted != true) {
              LoggingService.logWarning('⚠️ Exact alarm permission may not be granted');
            } else {
              LoggingService.logInfo('✅ Exact alarm permission granted');
            }
          } catch (e) {
            LoggingService.logError('❌ Failed to request exact alarm permission: $e');
          }
          
          // Also request notifications permission through the plugin
          try {
            final pluginNotificationResult = await androidImplementation.requestNotificationsPermission();
            LoggingService.logInfo('📱 Plugin notification permission result: $pluginNotificationResult');
          } catch (e) {
            LoggingService.logError('❌ Failed to request plugin notification permission: $e');
          }
        }
        
        return allPermissionsGranted;
      }
      
      return false;
    } catch (e) {
      LoggingService.logError('❌ Error requesting permissions: $e');
      return false;
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      LoggingService.logInfo('🔍 Checking notification permissions...');
      
      final status = await Permission.notification.status;
      LoggingService.logInfo('📱 System notification status: ${status.toString()}');
      
      if (!status.isGranted) {
        LoggingService.logInfo('❌ System notifications are disabled');
        return false;
      }
      
      // Additional platform-specific checks
      if (Platform.isIOS) {
        final bool? hasPermission = await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions()
            .then((settings) {
              final enabled = settings?.isEnabled ?? false;
              LoggingService.logInfo('🍎 iOS notification settings enabled: $enabled');
              return enabled;
            });
        return hasPermission ?? false;
        
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          try {
            // Check if we can schedule exact alarms (important for reliable notifications)
            final canScheduleExact = await androidImplementation.canScheduleExactNotifications();
            LoggingService.logInfo('⏰ Android can schedule exact alarms: ${canScheduleExact ?? false}');
            
            // For now, return true if basic notifications are granted, even if exact alarms aren't
            // The app will still function with approximate timing
            return status.isGranted;
          } catch (e) {
            LoggingService.logError('❌ Error checking Android notification capabilities: $e');
            return status.isGranted; // Fallback to basic permission check
          }
        }
      }
      
      LoggingService.logInfo('✅ Notifications are enabled');
      return status.isGranted;
    } catch (e) {
      LoggingService.logError('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  // Schedule daily nudge notification
  static Future<void> scheduleDailyNudge({
    required int hour,
    required int minute,
    String? userId,
  }) async {
    await _cancelNotification(dailyNudgeId);

    // Get the nudge message
    String nudgeMessage;
    try {
      if (userId != null) {
        // Try to get from API
        final apiNudge = await APIService.getDailyNudge(userId);
        nudgeMessage = apiNudge ?? _getRandomNudgeMessage();
      } else {
        nudgeMessage = _getRandomNudgeMessage();
      }
    } catch (e) {
      nudgeMessage = _getRandomNudgeMessage();
    }

    await _scheduleDaily(
      id: dailyNudgeId,
      title: 'Daily Nyx Nudge',
      body: nudgeMessage,
      hour: hour,
      minute: minute,
    );
  }

  // Schedule mood check reminders
  static Future<void> scheduleMoodReminders({
    required bool morningEnabled,
    required bool eveningEnabled,
    required int morningHour,
    required int morningMinute,
    required int eveningHour,
    required int eveningMinute,
  }) async {
    // Cancel existing reminders
    await _cancelNotification(morningMoodId);
    await _cancelNotification(eveningMoodId);

    if (morningEnabled) {
      await _scheduleDaily(
        id: morningMoodId,
        title: 'Morning Mood Check',
        body: 'Good morning! How are you feeling today?',
        hour: morningHour,
        minute: morningMinute,
      );
    }

    if (eveningEnabled) {
      await _scheduleDaily(
        id: eveningMoodId,
        title: 'Evening Mood Check',
        body: 'How was your day? Take a moment to reflect on your mood.',
        hour: eveningHour,
        minute: eveningMinute,
      );
    }
  }

  // Helper method to schedule daily notifications
  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
        0, // seconds
        0, // milliseconds
        0, // microseconds
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      
      LoggingService.logInfo('📅 Scheduling notification #$id for: ${scheduledDate.toString()}');

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );
      
      LoggingService.logInfo('✅ Notification #$id scheduled successfully');
    } catch (e) {
      LoggingService.logError('❌ Failed to schedule notification #$id: $e');
    }
  }

  static String _getRandomNudgeMessage() {
    final random = Random();
    return dailyNudgeMessages[random.nextInt(dailyNudgeMessages.length)];
  }

  static Future<void> _cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Test notification - shows immediately to test if notifications are working
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      99, // Test notification ID
      'Test Notification',
      'This is a test from Nyx! If you see this, notifications are working. 🎉',
      notificationDetails,
    );
  }

  // Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Save notification preferences
  static Future<void> saveNotificationPreferences({
    required bool dailyNudgeEnabled,
    required int dailyNudgeHour,
    required int dailyNudgeMinute,
    required bool morningMoodEnabled,
    required int morningMoodHour,
    required int morningMoodMinute,
    required bool eveningMoodEnabled,
    required int eveningMoodHour,
    required int eveningMoodMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('daily_nudge_enabled', dailyNudgeEnabled);
    await prefs.setInt('daily_nudge_hour', dailyNudgeHour);
    await prefs.setInt('daily_nudge_minute', dailyNudgeMinute);
    
    await prefs.setBool('morning_mood_enabled', morningMoodEnabled);
    await prefs.setInt('morning_mood_hour', morningMoodHour);
    await prefs.setInt('morning_mood_minute', morningMoodMinute);
    
    await prefs.setBool('evening_mood_enabled', eveningMoodEnabled);
    await prefs.setInt('evening_mood_hour', eveningMoodHour);
    await prefs.setInt('evening_mood_minute', eveningMoodMinute);
  }

  // Load and apply notification preferences
  static Future<void> loadAndApplyNotificationPreferences(String? userId) async {
    LoggingService.logInfo('🔄 Loading notification preferences...');
    
    // Check if notifications are enabled first
    if (!await areNotificationsEnabled()) {
      LoggingService.logInfo('⚠️ Notifications are disabled at system level');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    
    final dailyNudgeEnabled = prefs.getBool('daily_nudge_enabled') ?? true;
    final dailyNudgeHour = prefs.getInt('daily_nudge_hour') ?? 9;
    final dailyNudgeMinute = prefs.getInt('daily_nudge_minute') ?? 0;
    
    final morningMoodEnabled = prefs.getBool('morning_mood_enabled') ?? true;
    final morningMoodHour = prefs.getInt('morning_mood_hour') ?? 8;
    final morningMoodMinute = prefs.getInt('morning_mood_minute') ?? 0;
    
    final eveningMoodEnabled = prefs.getBool('evening_mood_enabled') ?? true;
    final eveningMoodHour = prefs.getInt('evening_mood_hour') ?? 20;
    final eveningMoodMinute = prefs.getInt('evening_mood_minute') ?? 0;

    // Cancel all existing notifications first
    await cancelAllNotifications();

    if (dailyNudgeEnabled) {
      LoggingService.logInfo('📬 Scheduling daily nudge at $dailyNudgeHour:$dailyNudgeMinute');
      await scheduleDailyNudge(
        hour: dailyNudgeHour,
        minute: dailyNudgeMinute,
        userId: userId,
      );
    }

    await scheduleMoodReminders(
      morningEnabled: morningMoodEnabled,
      eveningEnabled: eveningMoodEnabled,
      morningHour: morningMoodHour,
      morningMinute: morningMoodMinute,
      eveningHour: eveningMoodHour,
      eveningMinute: eveningMoodMinute,
    );
    
    // Log pending notifications for debugging
    final pending = await getPendingNotifications();
    LoggingService.logInfo('📋 Total pending notifications: ${pending.length}');
    for (final notification in pending) {
      LoggingService.logInfo('  - #${notification.id}: ${notification.title}');
    }
  }
}