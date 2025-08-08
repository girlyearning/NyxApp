import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InfodumpEntry {
  final String id;
  final String topic;
  final String content;
  final DateTime createdAt;
  final bool isUserCreated;

  InfodumpEntry({
    required this.id,
    required this.topic,
    required this.content,
    required this.createdAt,
    required this.isUserCreated,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic': topic,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'isUserCreated': isUserCreated,
    };
  }

  factory InfodumpEntry.fromJson(Map<String, dynamic> json) {
    return InfodumpEntry(
      id: json['id'],
      topic: json['topic'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      isUserCreated: json['isUserCreated'],
    );
  }
}

class InfodumpStorageService {
  static const String _infodumpsKey = 'saved_infodumps';

  // Save a new infodump
  static Future<void> saveInfodump(InfodumpEntry infodump) async {
    final prefs = await SharedPreferences.getInstance();
    final infodumps = await getAllInfodumps();
    
    infodumps.add(infodump);
    
    final infodumpsJson = infodumps.map((i) => i.toJson()).toList();
    await prefs.setString(_infodumpsKey, json.encode(infodumpsJson));
  }

  // Get all saved infodumps
  static Future<List<InfodumpEntry>> getAllInfodumps() async {
    final prefs = await SharedPreferences.getInstance();
    final infodumpsString = prefs.getString(_infodumpsKey);
    
    if (infodumpsString == null) return [];
    
    try {
      final List<dynamic> infodumpsJson = json.decode(infodumpsString);
      return infodumpsJson.map((json) => InfodumpEntry.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Get user-created infodumps only
  static Future<List<InfodumpEntry>> getUserInfodumps() async {
    final allInfodumps = await getAllInfodumps();
    return allInfodumps.where((infodump) => infodump.isUserCreated).toList();
  }

  // Get AI-generated infodumps only
  static Future<List<InfodumpEntry>> getGeneratedInfodumps() async {
    final allInfodumps = await getAllInfodumps();
    return allInfodumps.where((infodump) => !infodump.isUserCreated).toList();
  }

  // Delete a specific infodump
  static Future<void> deleteInfodump(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final infodumps = await getAllInfodumps();
    
    infodumps.removeWhere((infodump) => infodump.id == id);
    
    final infodumpsJson = infodumps.map((i) => i.toJson()).toList();
    await prefs.setString(_infodumpsKey, json.encode(infodumpsJson));
  }

  // Clear all infodumps
  static Future<void> clearAllInfodumps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_infodumpsKey);
  }

  // Generate unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}