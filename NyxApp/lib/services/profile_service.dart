import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_icon.dart';

class ProfileService {
  static const String _selectedIconKey = 'selected_profile_icon';
  static const String _userNameKey = 'user_display_name';
  
  // Cache to prevent flickering
  static ProfileIcon? _cachedIcon;
  static String? _cachedName;

  // Get the currently selected profile icon
  static Future<ProfileIcon> getSelectedIcon() async {
    // Return cached icon if available
    if (_cachedIcon != null) {
      return _cachedIcon!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final iconDataString = prefs.getString(_selectedIconKey);
    
    ProfileIcon icon;
    if (iconDataString != null) {
      try {
        final iconData = json.decode(iconDataString);
        // Check if it's the new format with baseIconId and colorId
        if (iconData['baseIconId'] != null && iconData['colorId'] != null) {
          icon = ProfileIcon.fromJson(iconData);
        } else {
          // Legacy format, return default
          icon = ProfileIconData.getDefaultIcon();
        }
      } catch (e) {
        // If parsing fails, return default
        icon = ProfileIconData.getDefaultIcon();
      }
    } else {
      icon = ProfileIconData.getDefaultIcon();
    }
    
    // Cache the icon
    _cachedIcon = icon;
    return icon;
  }

  // Set the selected profile icon
  static Future<void> setSelectedIcon(ProfileIcon icon) async {
    final prefs = await SharedPreferences.getInstance();
    final iconDataString = json.encode(icon.toJson());
    await prefs.setString(_selectedIconKey, iconDataString);
    
    // Update cache
    _cachedIcon = icon;
  }

  // Get user display name
  static Future<String> getUserDisplayName() async {
    // Return cached name if available
    if (_cachedName != null) {
      return _cachedName!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_userNameKey) ?? 'Anonymous User';
    
    // Cache the name
    _cachedName = name;
    return name;
  }

  // Set user display name
  static Future<void> setUserDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final finalName = name.trim().isNotEmpty ? name.trim() : 'Anonymous User';
    await prefs.setString(_userNameKey, finalName);
    
    // Update cache
    _cachedName = finalName;
  }

  // Check if user has customized their profile
  static Future<bool> hasCustomizedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_selectedIconKey) || prefs.containsKey(_userNameKey);
  }

  // Reset profile to defaults
  static Future<void> resetProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedIconKey);
    await prefs.remove(_userNameKey);
    
    // Clear cache
    _cachedIcon = null;
    _cachedName = null;
  }
  
  // Clear cache (useful when profile is updated from another screen)
  static void clearCache() {
    _cachedIcon = null;
    _cachedName = null;
  }
}