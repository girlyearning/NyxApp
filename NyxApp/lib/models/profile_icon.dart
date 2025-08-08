import 'package:flutter/material.dart';

class ProfileIcon {
  final String baseIconId;
  final String colorId;
  final IconData icon;
  final Color color;
  final String name;

  const ProfileIcon({
    required this.baseIconId,
    required this.colorId,
    required this.icon,
    required this.color,
    required this.name,
  });

  String get id => '${baseIconId}_$colorId';

  Map<String, dynamic> toJson() {
    return {
      'baseIconId': baseIconId,
      'colorId': colorId,
      'name': name,
    };
  }

  factory ProfileIcon.fromJson(Map<String, dynamic> json) {
    return ProfileIconData.createIcon(
      json['baseIconId'],
      json['colorId'],
    );
  }
}

class BaseIcon {
  final String id;
  final IconData icon;
  final String name;
  final String category;

  const BaseIcon({
    required this.id,
    required this.icon,
    required this.name,
    required this.category,
  });
}

class ColorOption {
  final String id;
  final Color color;
  final String name;

  const ColorOption({
    required this.id,
    required this.color,
    required this.name,
  });
}

class ProfileIconData {
  // 20 Base Icons across 4 categories
  static const List<BaseIcon> baseIcons = [
    // Mental Health & Psychology (5 icons)
    BaseIcon(id: 'brain', icon: Icons.psychology, name: 'Brain', category: 'Mental Health'),
    BaseIcon(id: 'heart', icon: Icons.favorite, name: 'Heart', category: 'Mental Health'),
    BaseIcon(id: 'mood', icon: Icons.mood, name: 'Smile', category: 'Mental Health'),
    BaseIcon(id: 'healing', icon: Icons.healing, name: 'Healing', category: 'Mental Health'),
    BaseIcon(id: 'self_care', icon: Icons.spa, name: 'Self Care', category: 'Mental Health'),

    // Nature & Animals (5 icons)
    BaseIcon(id: 'pet', icon: Icons.pets, name: 'Pet', category: 'Nature'),
    BaseIcon(id: 'butterfly', icon: Icons.flutter_dash, name: 'Butterfly', category: 'Nature'),
    BaseIcon(id: 'flower', icon: Icons.local_florist, name: 'Flower', category: 'Nature'),
    BaseIcon(id: 'tree', icon: Icons.park, name: 'Tree', category: 'Nature'),
    BaseIcon(id: 'sun', icon: Icons.wb_sunny, name: 'Sun', category: 'Nature'),

    // Tech & Cyber (5 icons)
    BaseIcon(id: 'gamepad', icon: Icons.sports_esports, name: 'Gamepad', category: 'Tech'),
    BaseIcon(id: 'headphones', icon: Icons.headphones, name: 'Headphones', category: 'Tech'),
    BaseIcon(id: 'phone', icon: Icons.smartphone, name: 'Phone', category: 'Tech'),
    BaseIcon(id: 'computer', icon: Icons.computer, name: 'Computer', category: 'Tech'),
    BaseIcon(id: 'code', icon: Icons.code, name: 'Code', category: 'Tech'),

    // Creative & Mystical (5 icons)
    BaseIcon(id: 'star', icon: Icons.star, name: 'Star', category: 'Creative'),
    BaseIcon(id: 'palette', icon: Icons.palette, name: 'Art Palette', category: 'Creative'),
    BaseIcon(id: 'music', icon: Icons.music_note, name: 'Music', category: 'Creative'),
    BaseIcon(id: 'magic', icon: Icons.auto_awesome, name: 'Magic', category: 'Creative'),
    BaseIcon(id: 'diamond', icon: Icons.diamond, name: 'Diamond', category: 'Creative'),
  ];

  // 18 Color Options
  static const List<ColorOption> colorOptions = [
    ColorOption(id: 'red', color: Colors.red, name: 'Red'),
    ColorOption(id: 'burgundy', color: Color(0xFF8B0000), name: 'Burgundy'),
    ColorOption(id: 'pink', color: Colors.pink, name: 'Pink'),
    ColorOption(id: 'hot_pink', color: Color(0xFFFF1493), name: 'Hot Pink'),
    ColorOption(id: 'sunset_orange', color: Color(0xFFFF4500), name: 'Sunset Orange'),
    ColorOption(id: 'yellow', color: Colors.yellow, name: 'Yellow'),
    ColorOption(id: 'pastel_green', color: Color(0xFF98FB98), name: 'Pastel Green'),
    ColorOption(id: 'sage_green', color: Color(0xFF87A96B), name: 'Sage Green'),
    ColorOption(id: 'forest_green', color: Color(0xFF228B22), name: 'Forest Green'),
    ColorOption(id: 'light_blue', color: Colors.lightBlue, name: 'Light Blue'),
    ColorOption(id: 'teal', color: Colors.teal, name: 'Teal'),
    ColorOption(id: 'dark_blue', color: Color(0xFF00008B), name: 'Dark Blue'),
    ColorOption(id: 'navy_blue', color: Color(0xFF000080), name: 'Navy Blue'),
    ColorOption(id: 'light_purple', color: Color(0xFFDDA0DD), name: 'Light Purple'),
    ColorOption(id: 'neon_purple', color: Color(0xFF9D00FF), name: 'Neon Purple'),
    ColorOption(id: 'dark_purple', color: Color(0xFF4B0082), name: 'Dark Purple'),
    ColorOption(id: 'dark_gray', color: Color(0xFF2F2F2F), name: 'Dark Gray'),
    ColorOption(id: 'brown', color: Color(0xFF8B4513), name: 'Brown'),
  ];

  static ProfileIcon createIcon(String baseIconId, String colorId) {
    final baseIcon = getBaseIconById(baseIconId) ?? baseIcons.first;
    final colorOption = getColorById(colorId) ?? colorOptions.first;

    return ProfileIcon(
      baseIconId: baseIcon.id,
      colorId: colorOption.id,
      icon: baseIcon.icon,
      color: colorOption.color,
      name: '${colorOption.name} ${baseIcon.name}',
    );
  }

  static ProfileIcon getDefaultIcon() {
    return createIcon('heart', 'burgundy'); // Burgundy Heart as default
  }

  static BaseIcon? getBaseIconById(String id) {
    try {
      return baseIcons.firstWhere((icon) => icon.id == id);
    } catch (e) {
      return null;
    }
  }

  static ColorOption? getColorById(String id) {
    try {
      return colorOptions.firstWhere((color) => color.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<BaseIcon> getIconsByCategory(String category) {
    return baseIcons.where((icon) => icon.category == category).toList();
  }

  static List<String> getCategories() {
    return baseIcons.map((icon) => icon.category).toSet().toList();
  }
}