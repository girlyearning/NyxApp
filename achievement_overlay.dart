import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../widgets/achievements_section.dart';
import '../widgets/achievement_banner.dart';

class AchievementOverlay extends StatefulWidget {
  final Widget child;

  const AchievementOverlay({
    super.key,
    required this.child,
  });

  @override
  State<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<AchievementOverlay> {
  final List<Achievement> _queuedAchievements = [];
  Achievement? _currentAchievement;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    
    // Listen to achievement stream
    AchievementService.achievementStream.listen((achievement) {
      _queuedAchievements.add(achievement);
      if (_currentAchievement == null) {
        _showNextAchievement();
      }
    });
  }

  void _showNextAchievement() {
    if (_queuedAchievements.isEmpty) {
      _currentAchievement = null;
      return;
    }

    _currentAchievement = _queuedAchievements.removeAt(0);
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: AchievementBanner(
            achievement: _currentAchievement!,
            onDismiss: _dismissCurrentAchievement,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _dismissCurrentAchievement() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    
    // Show next achievement after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _showNextAchievement();
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}