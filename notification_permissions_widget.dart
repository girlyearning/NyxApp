import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/logging_service.dart';

class NotificationPermissionsWidget extends StatefulWidget {
  const NotificationPermissionsWidget({super.key});

  @override
  State<NotificationPermissionsWidget> createState() => _NotificationPermissionsWidgetState();
}

class _NotificationPermissionsWidgetState extends State<NotificationPermissionsWidget> {
  Map<String, bool> _permissionStatus = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await NotificationService.checkAllSettings();
      setState(() {
        _permissionStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      LoggingService.logError('Error checking permissions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService.requestPermissions();
      await _checkPermissions(); // Refresh status
      
      // Show settings guide
      await NotificationService.showBackgroundSettingsGuide();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions requested! Check logs for manual setup guide.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      LoggingService.logError('Error requesting permissions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background Notifications & Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Permission status
              ..._permissionStatus.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.check_circle : Icons.error,
                      color: entry.value ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPermissionDisplayName(entry.key),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      entry.value ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        color: entry.value ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )).toList(),
              
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _requestPermissions,
                      icon: const Icon(Icons.security),
                      label: const Text('Request Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checkPermissions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Help text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Manual Setup Required',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For reliable background notifications, you may need to manually disable battery optimization for Nyx in your device settings. Check the app logs after requesting permissions for detailed steps.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPermissionDisplayName(String key) {
    switch (key) {
      case 'notifications':
        return 'Notifications';
      case 'battery_optimization':
        return 'Battery Optimization Exemption';
      case 'exact_alarms':
        return 'Exact Alarm Scheduling';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }
}