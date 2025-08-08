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
    } else if (promptType == 'adhd') {
      promptRequest = '''Generate a journal prompt specifically designed for someone with ADHD. 
      The prompt should help with ADHD-specific challenges like executive function, time blindness, emotional regulation, 
      hyperfocus, task initiation, or working memory. Make it actionable and structured to help with ADHD thought patterns.
      Keep it to 1-2 sentences and make it ADHD-friendly (clear, specific, engaging).
      
      Examples of good ADHD prompts:
      - "What's one task you've been avoiding? Break it down into 3 tiny steps you could do in 5 minutes each."
      - "Describe your current hyperfocus topic and how you could use this interest to tackle something on your to-do list."
      - "What time of day does your brain work best? What could you schedule during that golden hour tomorrow?"
      
      Generate ONLY the NEW prompt for ADHD (no explanation, reasoning, or context about ADHD):''';
    } else if (promptType == 'asd') {
      promptRequest = '''Generate a journal prompt specifically designed for someone with autism/ASD. 
      The prompt should help with autism-specific experiences like sensory processing, social situations, routine changes, 
      special interests, masking, or pattern recognition. Make it clear and literal, avoiding abstract metaphors.
      Keep it to 1-2 sentences and make it autism-friendly (specific, structured, predictable).
      
      Examples of good autism/ASD prompts:
      - "What sensory experience today was most comfortable or uncomfortable? Describe the specific details."
      - "Write about a social rule you've observed that doesn't make logical sense to you."
      - "Describe your favorite routine and why each step is important to you."
      
      Generate ONLY the NEW prompt for ASD (no explanation, reasoning, or context about autism):''';
    } else if (promptType == 'audhd') {
      promptRequest = '''Generate a journal prompt specifically designed for someone with both ADHD and autism (AuDHD). 
      The prompt should address the unique intersection of both conditions, like conflicting needs (routine vs novelty), 
      executive dysfunction with sensory issues, or hyperfocus on special interests. Be understanding of internal conflicts.
      Keep it to 1-2 sentences and acknowledge the dual experience.
      
      Examples of good AuDHD prompts:
      - "How do you balance your need for routine (autism) with your need for novelty (ADHD) today?"
      - "Describe a time when your ADHD and autism traits worked together as a superpower."
      - "What's one accommodation you wish you could have that would help both your ADHD and autism?"
      
      Generate ONLY the NEW prompt for AuDHD (no explanation, reasoning, or context about ADHD or autism):''';
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
    } else if (promptType == 'adhd') {
      final adhdPrompts = [
        "What's one task you've been avoiding? Break it down into 3 tiny steps you could do in 5 minutes each.",
        "Rate your focus level right now from 1-10. What one thing could shift it up by just one point?",
        "What did you hyperfocus on recently? How did it feel during and after?",
        "Name 3 things in your environment right now that are either helping or hindering your focus.",
        "What's your biggest win from today, even if it seems small?",
        "If you could only do ONE thing tomorrow, what would make you feel most accomplished?",
        "What reminder do you need to hear right now? Write it as if you're texting a friend.",
        "Describe your ideal workspace for maximum focus. What's one element you could add today?",
      ];
      final index = DateTime.now().millisecondsSinceEpoch % adhdPrompts.length;
      return adhdPrompts[index];
    } else if (promptType == 'asd') {
      final asdPrompts = [
        "What sensory experience today was most comfortable or uncomfortable? Describe the specific details.",
        "Which part of your routine brought you the most comfort today?",
        "Write about a social situation you navigated today. What worked and what didn't?",
        "What pattern did you notice today that others might have missed?",
        "Describe your current special interest and one new thing you learned about it.",
        "What's one way you accommodated your own needs today?",
        "Write about a texture, sound, or sensation you encountered today and how it affected you.",
        "What's one social expectation you'd like to opt out of, and why?",
      ];
      final index = DateTime.now().millisecondsSinceEpoch % asdPrompts.length;
      return asdPrompts[index];
    } else if (promptType == 'audhd') {
      final audhdPrompts = [
        "How did your need for routine clash with your need for novelty today?",
        "What's one way your autism and ADHD traits complemented each other recently?",
        "Describe a moment when you needed both stimulation AND quiet. How did you handle it?",
        "What special interest are you currently hyperfocusing on? How does it bring you joy?",
        "Write about a time today when you had to choose between structure and spontaneity.",
        "What's one thing that helps both your ADHD brain and your autistic brain feel calm?",
        "How did masking and impulsivity interact for you in a recent social situation?",
        "What's one accommodation that would help both sides of your neurotype?",
      ];
      final index = DateTime.now().millisecondsSinceEpoch % audhdPrompts.length;
      return audhdPrompts[index];
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