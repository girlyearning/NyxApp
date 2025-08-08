import 'package:flutter/material.dart';

class PersonalityColors {
  static Color getPersonalityColor(String? personality) {
    switch (personality?.toLowerCase()) {
      case 'default':
        return const Color(0xFFADCF86); // Green - balanced and supportive
      case 'ride_or_die':
        return const Color(0xFFFF69B4); // Pink - passionate and devoted
      case 'dream_analyst':
        return const Color(0xFF9370DB); // Purple - mysterious and analytical
      case 'debate_master':
        return const Color(0xFFFF6347); // Orange/Red - fiery and challenging
      case 'adhd':
        return const Color(0xFF00BCD4); // Cyan - energetic and dynamic
      case 'autistic':
        return const Color(0xFF4CAF50); // Green - structured and clear
      case 'audhd':
        return const Color(0xFF009688); // Teal - balanced blend
      default:
        return const Color(0xFFADCF86); // Default green
    }
  }

  static Color getPersonalityAccentColor(String? personality) {
    switch (personality?.toLowerCase()) {
      case 'default':
        return const Color(0xFF8BB96E); // Darker green
      case 'ride_or_die':
        return const Color(0xFFE91E63); // Darker pink
      case 'dream_analyst':
        return const Color(0xFF6B46C1); // Darker purple
      case 'debate_master':
        return const Color(0xFFFF4500); // Darker orange
      case 'adhd':
        return const Color(0xFF0097A7); // Darker cyan
      case 'autistic':
        return const Color(0xFF388E3C); // Darker green
      case 'audhd':
        return const Color(0xFF00796B); // Darker teal
      default:
        return const Color(0xFF8BB96E); // Default darker green
    }
  }

  static String getPersonalityDisplayName(String? personality) {
    switch (personality?.toLowerCase()) {
      case 'default':
        return 'Default Nyx';
      case 'ride_or_die':
        return 'Ride or Die Nyx';
      case 'dream_analyst':
        return 'Dream Analyst Nyx';
      case 'debate_master':
        return 'Debate Master Nyx';
      case 'adhd':
        return 'ADHD Nyx';
      case 'autistic':
        return 'Autistic Nyx';
      case 'audhd':
        return 'AuDHD Nyx';
      default:
        return 'Nyx';
    }
  }
}