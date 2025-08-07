import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_service.dart';

class PromptService {
  static const String _promptResponsesKey = 'prompt_responses';
  
  static Future<String> generatePrompt(String promptType, String? userId) async {
    final chatService = ChatService();
    
    String promptRequest;
    if (promptType == 'introspective') {
      promptRequest = '''Generate a thoughtful, introspective journal prompt that encourages self-reflection and mental health awareness. 
      Focus on topics like emotions, personal growth, self-discovery, coping strategies, or understanding patterns in behavior. 
      Make it engaging but not overwhelming. Keep it to 1-2 sentences and make it accessible for someone dealing with mental health challenges.
      
      Examples of good introspective prompts:
      - "What emotion have you been avoiding lately, and what might it be trying to tell you?"
      - "Describe a moment this week when you felt most like yourself. What was happening?"
      - "If your inner critic had a day off, what would you tell yourself instead?"
      
      Generate a NEW prompt in this style:''';
    } else {
      promptRequest = '''Generate a general, creative journal prompt that's engaging and thought-provoking but not focused on mental health. 
      This should be fun, imaginative, or intellectually stimulating. Topics could include creativity, memories, hypotheticals, 
      personal interests, or creative writing prompts. Keep it to 1-2 sentences.
      
      Examples of good general prompts:
      - "If you could have dinner with any fictional character, who would it be and what would you ask them?"
      - "Write about a childhood memory that still makes you smile."
      - "You discover a hidden room in your house. Describe what's inside and how it got there."
      
      Generate a NEW prompt in this style:''';
    }
    
    try {
      final response = await chatService.sendMessage(
        promptRequest,
        'queries',
        true,
        userId: userId,
      );
      
      // Clean up the response to remove any quotes or extra formatting
      String cleanResponse = response.trim();
      if (cleanResponse.startsWith('"') || cleanResponse.startsWith("'")) {
        cleanResponse = cleanResponse.substring(1);
      }
      if (cleanResponse.endsWith('"') || cleanResponse.endsWith("'")) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 1);
      }
      return cleanResponse;
    } catch (e) {
      // Fallback prompts if API fails
      return _getFallbackPrompt(promptType);
    }
  }
  
  static String _getFallbackPrompt(String promptType) {
    if (promptType == 'introspective') {
      final introspectivePrompts = [
        "What's one thing you've learned about yourself this week?",
        "If you could send a message to your past self from one year ago, what would you say?",
        "What emotion have you been avoiding lately, and what might it be trying to tell you?",
        "Describe a moment recently when you felt most at peace. What was happening?",
        "What pattern in your life would you like to change, and what small step could you take toward that?",
        "If your inner critic took a vacation, what would your inner cheerleader say instead?",
        "What's something you're grateful for that you might usually take for granted?",
        "What does 'taking care of yourself' look like for you today?",
      ];
      final index = DateTime.now().millisecondsSinceEpoch % introspectivePrompts.length;
      return introspectivePrompts[index];
    } else {
      final generalPrompts = [
        "If you could master any skill instantly, what would it be and how would you use it?",
        "Write about your perfect day from start to finish, with no limitations.",
        "If you could have dinner with any historical figure, who would it be and what would you ask?",
        "You find a time capsule you buried 10 years ago. What do you hope is inside?",
        "If you could live in any fictional world for a week, where would you go and what would you do?",
        "Write a letter to your future self to be opened in 5 years.",
        "If you could solve one world problem, what would it be and how would you approach it?",
        "Describe your ideal creative space. What would it look like and what would you create there?",
      ];
      final index = DateTime.now().millisecondsSinceEpoch % generalPrompts.length;
      return generalPrompts[index];
    }
  }
  
  static Future<void> savePromptResponse({
    required String prompt,
    required String response,
    required String promptType,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final promptResponse = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'prompt': prompt,
      'response': response,
      'promptType': promptType,
      'userId': userId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    // Get existing responses
    final existingResponses = await getPromptResponses(userId);
    existingResponses.add(promptResponse);
    
    // Keep only the last 50 responses
    if (existingResponses.length > 50) {
      existingResponses.removeRange(0, existingResponses.length - 50);
    }
    
    // Save back to preferences
    final responseData = existingResponses.map((r) => json.encode(r)).toList();
    await prefs.setStringList('${_promptResponsesKey}_$userId', responseData);
  }
  
  static Future<List<Map<String, dynamic>>> getPromptResponses(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final responseData = prefs.getStringList('${_promptResponsesKey}_$userId') ?? [];
    
    return responseData
        .map((jsonString) {
          try {
            return json.decode(jsonString) as Map<String, dynamic>;
          } catch (e) {
            return null;
          }
        })
        .where((response) => response != null)
        .cast<Map<String, dynamic>>()
        .toList()
        ..sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
  }
  
  static Future<void> deletePromptResponse(String userId, String responseId) async {
    final responses = await getPromptResponses(userId);
    responses.removeWhere((response) => response['id'] == responseId);
    
    final prefs = await SharedPreferences.getInstance();
    final responseData = responses.map((r) => json.encode(r)).toList();
    await prefs.setStringList('${_promptResponsesKey}_$userId', responseData);
  }
  
  static Future<int> getPromptResponseCount(String userId) async {
    final responses = await getPromptResponses(userId);
    return responses.length;
  }
  
  static Future<Map<String, int>> getPromptTypeBreakdown(String userId) async {
    final responses = await getPromptResponses(userId);
    final breakdown = <String, int>{};
    
    for (final response in responses) {
      final type = response['promptType'] as String;
      breakdown[type] = (breakdown[type] ?? 0) + 1;
    }
    
    return breakdown;
  }
}