import 'package:flutter/material.dart';
import '../screens/support_sessions_screen.dart';

class CopingFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String mode;
  final Color? color;

  const CopingFeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.mode,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: () => _navigateToSession(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardColor,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: cardColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSession(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupportSessionsScreen(
          supportType: _mapModeToSupportType(mode),
          title: title,
        ),
      ),
    );
  }
  
  String _mapModeToSupportType(String mode) {
    switch (mode) {
      case 'suicide':
        return 'crisis_support';
      case 'anxiety':
        return 'anxiety_support';
      case 'depression':
        return 'depression_support';
      case 'anger':
        return 'anger_management';
      case 'addiction':
        return 'recovery_support';
      case 'comfort':
        return 'general_comfort';
      case 'introspection':
        return 'introspection';
      case 'shadow_work':
        return 'shadow_work';
      case 'values':
        return 'values_clarification';
      case 'trauma_patterns':
        return 'trauma_patterns';
      case 'attachment':
        return 'attachment_styles';
      case 'existential':
        return 'existential_exploration';
      case 'rage_room':
        return 'rage_room';
      case 'confession':
        return 'confession_booth';
      default:
        return 'general_comfort';
    }
  }
}