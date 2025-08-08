import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/qyknotes_service.dart';
import '../services/achievement_service.dart';
import '../services/profile_service.dart';
import '../models/profile_icon.dart';
import '../providers/mood_provider.dart';

class UserProvider extends ChangeNotifier {
  int _nyxNotes = 0;
  String _userName = '';
  String _userId = '';
  int _chatSessions = 0;
  int _journalEntries = 0;
  int _gamesPlayed = 0;
  int _qykNotesCount = 0;
  DateTime? _createdAt;
  String? _userType;
  MoodProvider? _moodProvider;
  ProfileIcon? _selectedProfileIcon;

  int get nyxNotes => _nyxNotes;
  String get userName => _userName;
  String get currentUserId => _userId.isEmpty ? 'flutter_user' : _userId;
  int? get chatSessions => _chatSessions;
  int? get journalEntries => _journalEntries;
  int? get gamesPlayed => _gamesPlayed;
  int get qykNotes => _qykNotesCount;
  DateTime? get createdAt => _createdAt;
  String? get userType => _userType;
  ProfileIcon get selectedProfileIcon => _selectedProfileIcon ?? ProfileIconData.getDefaultIcon();

  UserProvider() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _nyxNotes = prefs.getInt('nyx_notes') ?? 0;
    _userName = prefs.getString('user_name') ?? '';
    _userId = prefs.getString('user_id') ?? '';
    _chatSessions = prefs.getInt('chat_sessions') ?? 0;
    _journalEntries = prefs.getInt('journal_entries_count') ?? 0;
    _gamesPlayed = prefs.getInt('games_played') ?? 0;
    _userType = prefs.getString('user_type');
    
    
    final createdAtString = prefs.getString('created_at');
    if (createdAtString != null) {
      _createdAt = DateTime.parse(createdAtString);
    } else {
      // Set created_at to now if it doesn't exist (existing users)
      _createdAt = DateTime.now();
      await prefs.setString('created_at', _createdAt!.toIso8601String());
    }
    
    // Load QYK notes count
    await refreshQykNotesCount();
    
    // Load profile icon
    _selectedProfileIcon = await ProfileService.getSelectedIcon();
    
    notifyListeners();
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nyx_notes', _nyxNotes);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_id', _userId);
    await prefs.setInt('chat_sessions', _chatSessions);
    await prefs.setInt('journal_entries_count', _journalEntries);
    await prefs.setInt('games_played', _gamesPlayed);
    if (_userType != null) {
      await prefs.setString('user_type', _userType!);
    }
    if (_createdAt != null) {
      await prefs.setString('created_at', _createdAt!.toIso8601String());
    }
  }

  Future<void> addNyxNotes(int amount) async {
    _nyxNotes += amount;
    await _saveUserData();
    notifyListeners();
    await checkAchievements();
  }


  Future<void> setUserName(String name) async {
    _userName = name;
    await _saveUserData();
    notifyListeners();
  }

  Future<void> incrementChatSessions() async {
    _chatSessions++;
    await _saveUserData();
    notifyListeners();
    await checkAchievements();
  }

  Future<void> incrementJournalEntries() async {
    _journalEntries++;
    await _saveUserData();
    notifyListeners();
    await checkAchievements();
  }

  Future<void> incrementGamesPlayed() async {
    _gamesPlayed++;
    await _saveUserData();
    notifyListeners();
    await checkAchievements();
  }

  Future<void> refreshQykNotesCount() async {
    _qykNotesCount = await QykNotesService.getNotesCount();
    notifyListeners();
    await checkAchievements();
  }

  Future<void> setUserType(String type) async {
    _userType = type;
    await _saveUserData();
    notifyListeners();
  }

  void setMoodProvider(MoodProvider moodProvider) {
    _moodProvider = moodProvider;
  }

  Future<void> checkAchievements() async {
    if (_moodProvider != null) {
      await AchievementService.checkForNewAchievements(this, _moodProvider!);
    }
  }

  Future<void> updateProfileIcon(ProfileIcon icon) async {
    _selectedProfileIcon = icon;
    await ProfileService.setSelectedIcon(icon);
    notifyListeners();
  }

  /// Refreshes all user data from storage (used after data clearing)
  Future<void> refreshUserData() async {
    await _loadUserData();
    await refreshQykNotesCount();
    notifyListeners();
  }
}