import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/logging_service.dart';

class NyxQueriesSessionService {
  static const String _sessionPrefix = 'nyx_queries_session_';
  static const String _sessionListKey = 'nyx_queries_sessions_list';
  
  // Create a new query session with unique session ID
  static Future<String> createNewSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate new session ID with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sessionId = 'query_$timestamp';
    
    // Get current sessions list
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    // Add new session to list
    final sessionData = {
      'sessionId': sessionId,
      'createdAt': DateTime.now().toIso8601String(),
      'lastUpdated': DateTime.now().toIso8601String(),
      'messageCount': 0,
      'title': 'New Query',
    };
    
    sessionsList.insert(0, sessionData); // Add to beginning
    
    // Save updated sessions list
    await prefs.setString(_sessionListKey, json.encode(sessionsList));
    
    // Initialize empty messages for the session
    await prefs.setString('$_sessionPrefix$sessionId', json.encode([]));
    
    LoggingService.logInfo('Created new Nyx Queries session: $sessionId');
    return sessionId;
  }
  
  // Get all query sessions
  static Future<List<Map<String, dynamic>>> getAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    return sessionsList.cast<Map<String, dynamic>>().toList();
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
        if (sessionsList[i]['title'] == 'New Query') {
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
  
  // Send question and get AI response
  static Future<String> sendQuestion(String sessionId, String question, {String? userId}) async {
    // Load current session
    final messages = await loadSession(sessionId);
    
    // Add user question
    final userMessage = ChatMessage(
      content: question,
      isUser: true,
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);
    
    // Get AI response using 'queries' mode for enhanced search and knowledge
    final chatService = ChatService();
    final aiResponse = await chatService.sendMessage(
      question,
      'queries', // Special mode for Nyx Queries
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
    
    LoggingService.logInfo('Deleted Nyx Queries session: $sessionId');
  }

  // Save a query forever to Resident Records (but keep it in Queries too)
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
      
      // Create resident record - mark as nyx_queries type
      final residentRecord = {
        'originalSessionId': sessionId,
        'sessionData': messages.map((m) => m.toJson()).toList(),
        'metadata': {
          ...sessionMeta,
          'mode': 'queries', // Mark as queries mode
        },
        'savedAt': DateTime.now().toIso8601String(),
        'recordType': 'saved_forever',
        'source': 'nyx_queries',
      };
      
      // Save to resident records
      await prefs.setString('$residentRecordsPrefix$permanentId', json.encode(residentRecord));
      
      // Save to saved forever collection
      await prefs.setString('$savedForeverPrefix$sessionId', json.encode({
        'residentRecordId': permanentId,
        'savedAt': DateTime.now().toIso8601String(),
        'customName': sessionMeta['title'],
        'source': 'nyx_queries',
      }));
      
      // NOTE: Unlike other chat types, we DON'T delete the query from Nyx Queries
      // It should remain accessible in both places
      
      LoggingService.logInfo('Nyx Queries session saved forever: $sessionId as $permanentId (kept in Queries)');
      return true;
      
    } catch (e) {
      LoggingService.logError('Failed to save Nyx Queries session forever: $e');
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
    
    LoggingService.logInfo('Renamed Nyx Queries session: $sessionId to "$newTitle"');
  }
  
  static String _truncateTitle(String content) {
    if (content.length <= 40) return content;
    return '${content.substring(0, 40)}...';
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
  static Future<String> sendThumbsDownResponse(String originalMessage, String sessionId) async {
    try {
      final chatService = ChatService();
      final response = await chatService.getThumbsDownResponse(
        originalMessage: originalMessage,
        mode: 'queries',
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
}