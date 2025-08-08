import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/logging_service.dart';
import '../services/conversation_memory_service.dart';

class NauticalNyxService {
  static const String _sessionPrefix = 'nautical_session_';
  static const String _sessionListKey = 'nautical_sessions_list';
  
  // Create a new chat session with unique session ID
  static Future<String> createNewSession(String personality) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate new session ID with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sessionId = '${personality}_$timestamp';
    
    // Get current sessions list
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    // Add new session to list
    final sessionData = {
      'sessionId': sessionId,
      'personality': personality,
      'createdAt': DateTime.now().toIso8601String(),
      'lastUpdated': DateTime.now().toIso8601String(),
      'messageCount': 0,
      'title': _getDefaultTitle(personality),
    };
    
    sessionsList.insert(0, sessionData); // Add to beginning
    
    // Save updated sessions list
    await prefs.setString(_sessionListKey, json.encode(sessionsList));
    
    // Initialize empty messages for the session
    await prefs.setString('$_sessionPrefix$sessionId', json.encode([]));
    
    LoggingService.logInfo('Created new Nautical Nyx session: $sessionId');
    return sessionId;
  }
  
  // Get all sessions for a specific personality
  static Future<List<Map<String, dynamic>>> getSessionsForPersonality(String personality) async {
    final prefs = await SharedPreferences.getInstance();
    
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    return sessionsList
        .where((session) => session['personality'] == personality)
        .cast<Map<String, dynamic>>()
        .toList();
  }
  
  // Load messages for a specific session
  static Future<List<ChatMessage>> loadSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final messagesJson = prefs.getString('$_sessionPrefix$sessionId') ?? '[]';
    final List<dynamic> messagesList = json.decode(messagesJson);
    
    return messagesList.map((json) => ChatMessage.fromJson(json)).toList();
  }
  
  // Save messages for a specific session
  static Future<void> saveSession(String sessionId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save messages
    final messagesJson = messages.map((msg) => msg.toJson()).toList();
    await prefs.setString('$_sessionPrefix$sessionId', json.encode(messagesJson));
    
    // Update session metadata
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    // Find and update the session
    for (int i = 0; i < sessionsList.length; i++) {
      if (sessionsList[i]['sessionId'] == sessionId) {
        sessionsList[i]['lastUpdated'] = DateTime.now().toIso8601String();
        sessionsList[i]['messageCount'] = messages.length;
        
        // Update title if it's still the default and we have user messages
        if (sessionsList[i]['title'] == _getDefaultTitle(sessionsList[i]['personality'])) {
          final userMessages = messages.where((m) => m.isUser).toList();
          if (userMessages.isNotEmpty) {
            sessionsList[i]['title'] = _truncateTitle(userMessages.first.content);
          }
        }
        break;
      }
    }
    
    await prefs.setString(_sessionListKey, json.encode(sessionsList));
  }
  
  // Send message and get AI response
  static Future<String> sendMessage(String sessionId, String message, String personality, {String? userId}) async {
    // Load current session
    final messages = await loadSession(sessionId);
    
    // Add user message
    final userMessage = ChatMessage(
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);
    
    // Get AI response
    final chatService = ChatService();
    final aiResponse = await chatService.sendMessage(
      message,
      personality,
      messages.where((m) => !m.isUser).length == 0, // isFirstMessage
      conversationHistory: messages,
      userId: userId,
    );
    
    // Add AI message
    final aiMessage = ChatMessage(
      content: aiResponse,
      isUser: false,
      timestamp: DateTime.now(),
    );
    messages.add(aiMessage);
    
    // Save updated session
    await saveSession(sessionId, messages);
    
    return aiResponse;
  }
  
  // Delete a session
  static Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove session messages
    await prefs.remove('$_sessionPrefix$sessionId');
    
    // Remove from sessions list
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    sessionsList.removeWhere((session) => session['sessionId'] == sessionId);
    
    await prefs.setString(_sessionListKey, json.encode(sessionsList));
    
    LoggingService.logInfo('Deleted Nautical Nyx session: $sessionId');
  }

  // Save a chat forever to Resident Records
  static Future<bool> saveChatForever(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load session messages
      final messages = await loadSession(sessionId);
      if (messages.isEmpty) return false;
      
      // Load session metadata
      final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
      final List<dynamic> sessionsList = json.decode(sessionsJson);
      
      Map<String, dynamic>? sessionMeta;
      for (final session in sessionsList) {
        if (session['sessionId'] == sessionId) {
          sessionMeta = session;
          break;
        }
      }
      
      if (sessionMeta == null) return false;
      
      // Create permanent record
      final permanentId = '${sessionId}_saved_${DateTime.now().millisecondsSinceEpoch}';
      const savedForeverPrefix = 'saved_forever_';
      const residentRecordsPrefix = 'resident_records_';
      
      // Create resident record
      final residentRecord = {
        'originalSessionId': sessionId,
        'sessionData': messages.map((m) => m.toJson()).toList(),
        'metadata': sessionMeta,
        'savedAt': DateTime.now().toIso8601String(),
        'recordType': 'saved_forever',
        'source': 'nautical_nyx',
      };
      
      // Save to resident records
      await prefs.setString('$residentRecordsPrefix$permanentId', json.encode(residentRecord));
      
      // Save to saved forever collection
      await prefs.setString('$savedForeverPrefix$sessionId', json.encode({
        'residentRecordId': permanentId,
        'savedAt': DateTime.now().toIso8601String(),
        'customName': sessionMeta['title'],
        'source': 'nautical_nyx',
      }));
      
      LoggingService.logInfo('Nautical Nyx chat saved forever: $sessionId as $permanentId');
      return true;
      
    } catch (e) {
      LoggingService.logError('Failed to save Nautical Nyx chat forever: $e');
      return false;
    }
  }

  // Rename a session
  static Future<void> renameSession(String sessionId, String newTitle) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update session metadata
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    // Find and update the session
    for (int i = 0; i < sessionsList.length; i++) {
      if (sessionsList[i]['sessionId'] == sessionId) {
        sessionsList[i]['title'] = newTitle;
        sessionsList[i]['lastUpdated'] = DateTime.now().toIso8601String();
        break;
      }
    }
    
    await prefs.setString(_sessionListKey, json.encode(sessionsList));
    
    LoggingService.logInfo('Renamed Nautical Nyx session: $sessionId to "$newTitle"');
  }
  
  static String _getDefaultTitle(String personality) {
    switch (personality) {
      case 'default':
        return 'Chat with Nyx';
      case 'ride_or_die':
        return 'Ride or Die Chat';
      case 'dream_analyst':
        return 'Dream Analysis';
      case 'debate_master':
        return 'Debate Session';
      case 'adhd_nyx':
        return 'ADHD Nyx Chat';
      case 'autistic_nyx':
        return 'Autistic Nyx Chat';
      case 'autistic_adhd':
        return 'AuDHD Nyx Chat';
      default:
        return 'Nyx Chat';
    }
  }
  
  static String _truncateTitle(String content) {
    if (content.length <= 30) return content;
    return '${content.substring(0, 30)}...';
  }

  // Update message reaction
  static Future<void> updateMessageReaction(String sessionId, String messageId, String reaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_sessionPrefix$sessionId';
      
      final messagesJson = prefs.getString(key) ?? '[]';
      final List<dynamic> messagesList = json.decode(messagesJson);
      
      // Find and update the message
      for (int i = 0; i < messagesList.length; i++) {
        if (messagesList[i]['id'] == messageId) {
          messagesList[i]['reaction'] = reaction;
          break;
        }
      }
      
      // Save updated messages
      await prefs.setString(key, json.encode(messagesList));
      
      LoggingService.logInfo('Updated reaction for message $messageId: $reaction');
    } catch (e) {
      LoggingService.logError('Error updating message reaction: $e');
    }
  }

  // Send thumbs down response
  static Future<String> sendThumbsDownResponse(String originalMessage, String personality, String sessionId, {String? userId}) async {
    try {
      final chatService = ChatService();
      final response = await chatService.getThumbsDownResponse(
        originalMessage: originalMessage,
        mode: personality,
        userId: userId,
      );
      
      if (response == null) {
        throw Exception('Failed to get thumbs down response');
      }
      
      // Save the response as a new message
      final responseMessage = ChatMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      
      await _addMessageToSession(sessionId, responseMessage);
      
      LoggingService.logInfo('Sent thumbs down response for session $sessionId');
      return response;
    } catch (e) {
      LoggingService.logError('Error sending thumbs down response: $e');
      throw Exception('Failed to send thumbs down response');
    }
  }

  // Helper method to add a message to session
  static Future<void> _addMessageToSession(String sessionId, ChatMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_sessionPrefix$sessionId';
      
      final messagesJson = prefs.getString(key) ?? '[]';
      final List<dynamic> messagesList = json.decode(messagesJson);
      
      messagesList.add(message.toJson());
      await prefs.setString(key, json.encode(messagesList));
    } catch (e) {
      LoggingService.logError('Error adding message to session: $e');
    }
  }

  // Create a memory summary from a session before deleting
  static Future<void> createMemoryFromSession(String sessionId, String userId, String personality) async {
    try {
      // Load session messages and metadata
      final messages = await loadSession(sessionId);
      if (messages.isEmpty) return;
      
      // Find session metadata
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
      final List<dynamic> sessionsList = json.decode(sessionsJson);
      
      Map<String, dynamic>? sessionMeta;
      for (var session in sessionsList) {
        if (session['sessionId'] == sessionId) {
          sessionMeta = session;
          break;
        }
      }
      
      if (sessionMeta != null && messages.length > 2) { // Only create memory if there's actual conversation
        await ConversationMemoryService.createMemoryFromSession(
          userId,
          personality,
          messages,
          sessionMeta['title'] ?? 'Nautical Nyx Session',
        );
        LoggingService.logInfo('Created memory from Nautical Nyx session: $sessionId');
      }
    } catch (e) {
      LoggingService.logError('Error creating memory from session: $e');
      // Don't throw - this is a background operation
    }
  }
}