import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QotdResponse {
  final String id;
  final String question;
  final String answer;
  final DateTime date;

  QotdResponse({
    required this.id,
    required this.question,
    required this.answer,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'date': date.toIso8601String(),
    };
  }

  factory QotdResponse.fromJson(Map<String, dynamic> json) {
    return QotdResponse(
      id: json['id'],
      question: json['question'],
      answer: json['answer'],
      date: DateTime.parse(json['date']),
    );
  }
}

class QotdResponsesService {
  static const String _storageKey = 'qotd_responses';

  static Future<void> saveResponse(String question, String answer) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    // Generate unique ID using timestamp to ensure each response is saved separately
    final uniqueId = '${now.millisecondsSinceEpoch}';
    
    final response = QotdResponse(
      id: uniqueId,
      question: question,
      answer: answer,
      date: now,
    );

    final responses = await getAllResponses();
    
    // Add the new response (no longer removing existing responses)
    responses.add(response);
    
    // Keep only the last 100 responses to prevent storage bloat
    if (responses.length > 100) {
      responses.sort((a, b) => b.date.compareTo(a.date));
      responses.removeRange(100, responses.length);
    }

    final jsonList = responses.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  static Future<List<QotdResponse>> getAllResponses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => QotdResponse.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<QotdResponse>> getRecentResponses([int limit = 10]) async {
    final responses = await getAllResponses();
    responses.sort((a, b) => b.date.compareTo(a.date));
    return responses.take(limit).toList();
  }

  static Future<int> getTotalResponseCount() async {
    final responses = await getAllResponses();
    return responses.length;
  }

  static Future<List<QotdResponse>> getResponsesForDate(DateTime date) async {
    final targetDate = date.toIso8601String().split('T')[0];
    final responses = await getAllResponses();
    
    // Return all responses for the specified date
    return responses.where((r) {
      final responseDate = r.date.toIso8601String().split('T')[0];
      return responseDate == targetDate;
    }).toList();
  }
  
  static Future<QotdResponse?> getResponseForDate(DateTime date) async {
    final responsesForDate = await getResponsesForDate(date);
    return responsesForDate.isNotEmpty ? responsesForDate.first : null;
  }

  static Future<void> deleteResponse(String id) async {
    final responses = await getAllResponses();
    responses.removeWhere((r) => r.id == id);
    
    final prefs = await SharedPreferences.getInstance();
    final jsonList = responses.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  static Future<void> clearAllResponses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}