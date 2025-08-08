import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/logging_service.dart';
import '../services/conversation_memory_service.dart';

class SupportChatService {
  static const String _sessionPrefix = 'support_session_';
  static const String _sessionListKey = 'support_sessions_list';
  
  // Create a new chat session with unique session ID
  static Future<String> createNewSession(String supportType) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate new session ID with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sessionId = '${supportType}_$timestamp';
    
    // Get current sessions list
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    // Add new session to list
    final sessionData = {
      'sessionId': sessionId,
      'supportType': supportType,
      'createdAt': DateTime.now().toIso8601String(),
      'lastUpdated': DateTime.now().toIso8601String(),
      'messageCount': 0,
      'title': _getDefaultTitle(supportType),
    };
    
    sessionsList.insert(0, sessionData); // Add to beginning
    
    // Save updated sessions list
    await prefs.setString(_sessionListKey, json.encode(sessionsList));
    
    // Initialize empty messages for the session
    await prefs.setString('$_sessionPrefix$sessionId', json.encode([]));
    
    LoggingService.logInfo('Created new Support chat session: $sessionId');
    return sessionId;
  }
  
  // Get all sessions for a specific support type
  static Future<List<Map<String, dynamic>>> getSessionsForSupportType(String supportType) async {
    final prefs = await SharedPreferences.getInstance();
    
    final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    
    return sessionsList
        .where((session) => session['supportType'] == supportType)
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
        if (sessionsList[i]['title'] == _getDefaultTitle(sessionsList[i]['supportType'])) {
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
  
  // Send message and get AI response - returns multiple messages for lengthy modes
  static Future<List<String>> sendMessage(String sessionId, String message, String supportType, {String? userId}) async {
    // Load current session
    final messages = await loadSession(sessionId);
    
    // Add user message
    final userMessage = ChatMessage(
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);
    
    // Get AI response(s)
    final chatService = ChatService();
    
    // Support modes that should return multiple messages
    final multiMessageModes = [
      'crisis_support', 'anxiety_support', 'depression_support', 
      'anger_management', 'recovery_support', 'general_comfort',
      'introspection', 'shadow_work', 'values_clarification', 
      'trauma_patterns', 'attachment_styles', 'existential_exploration',
      'self_discovery', 'specialized_tools'
    ];
    
    List<String> aiResponses;
    
    if (multiMessageModes.contains(supportType)) {
      // Use the multiple messages method for detailed support modes
      aiResponses = await chatService.sendMultipleMessages(
        message,
        _mapSupportTypeToMode(supportType),
        messages.where((m) => !m.isUser).isEmpty, // isFirstMessage
        conversationHistory: messages,
        userId: userId,
      );
    } else {
      // Single message for other modes
      final singleResponse = await chatService.sendMessage(
        message,
        _mapSupportTypeToMode(supportType),
        messages.where((m) => !m.isUser).isEmpty, // isFirstMessage
        conversationHistory: messages,
        userId: userId,
      );
      aiResponses = [singleResponse];
    }
    
    // Add AI messages
    for (final response in aiResponses) {
      final aiMessage = ChatMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      messages.add(aiMessage);
    }
    
    // Save updated session
    await saveSession(sessionId, messages);
    
    return aiResponses;
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
    
    LoggingService.logInfo('Deleted Support chat session: $sessionId');
  }
  
  // Create a memory summary from a session before deleting
  static Future<void> createMemoryFromSession(String sessionId, String userId) async {
    try {
      // Load session messages and metadata
      final messages = await loadSession(sessionId);
      if (messages.isEmpty) return;
      
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString(_sessionListKey) ?? '[]';
      final List<dynamic> sessionsList = json.decode(sessionsJson);
      
      Map<String, dynamic>? sessionMeta;
      for (final session in sessionsList) {
        if (session['sessionId'] == sessionId) {
          sessionMeta = session;
          break;
        }
      }
      
      if (sessionMeta != null && messages.length > 2) { // Only create memory if there's actual conversation
        await ConversationMemoryService.createMemoryFromSession(
          userId,
          _mapSupportTypeToMode(sessionMeta['supportType']),
          messages,
          sessionMeta['title'] ?? 'Support Session',
        );
      }
    } catch (e) {
      LoggingService.logError('Failed to create memory from session $sessionId: $e');
    }
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
        'source': 'support_chat',
      };
      
      // Save to resident records
      await prefs.setString('$residentRecordsPrefix$permanentId', json.encode(residentRecord));
      
      // Save to saved forever collection
      await prefs.setString('$savedForeverPrefix$sessionId', json.encode({
        'residentRecordId': permanentId,
        'savedAt': DateTime.now().toIso8601String(),
        'customName': sessionMeta['title'],
        'source': 'support_chat',
      }));
      
      LoggingService.logInfo('Support chat saved forever: $sessionId as $permanentId');
      return true;
      
    } catch (e) {
      LoggingService.logError('Failed to save Support chat forever: $e');
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
    
    LoggingService.logInfo('Renamed Support chat session: $sessionId to "$newTitle"');
  }
  
  static String _getDefaultTitle(String supportType) {
    switch (supportType) {
      case 'crisis_support':
        return 'Crisis Support';
      case 'anxiety_support':
        return 'Anxiety Support';
      case 'depression_support':
        return 'Depression Support';
      case 'anger_management':
        return 'Anger Management';
      case 'recovery_support':
        return 'Recovery Support';
      case 'general_comfort':
        return 'General Comfort';
      case 'introspection':
        return 'Self Reflection';
      case 'shadow_work':
        return 'Shadow Work';
      case 'values_clarification':
        return 'Values Exploration';
      case 'trauma_patterns':
        return 'Trauma Understanding';
      case 'attachment_styles':
        return 'Attachment Exploration';
      case 'existential_exploration':
        return 'Life Questions';
      case 'rage_room':
        return 'Rage Expression';
      case 'mental_space':
        return 'Mental Clarity';
      case 'confession_booth':
        return 'Safe Confession';
      default:
        return 'Support Chat';
    }
  }
  
  static String _truncateTitle(String content) {
    if (content.length <= 30) return content;
    return '${content.substring(0, 30)}...';
  }
  
  // Map support types to chat service modes
  static String _mapSupportTypeToMode(String supportType) {
    switch (supportType) {
      case 'crisis_support':
        return 'suicide'; // Uses existing crisis mode
      case 'anxiety_support':
        return 'anxiety';
      case 'depression_support':
        return 'depression';
      case 'anger_management':
        return 'anger';
      case 'recovery_support':
        return 'addiction';
      case 'general_comfort':
        return 'comfort';
      case 'introspection':
        return 'introspection';
      case 'shadow_work':
        return 'shadow_work';
      case 'values_clarification':
        return 'values';
      case 'trauma_patterns':
        return 'trauma_patterns';
      case 'attachment_styles':
        return 'attachment';
      case 'existential_exploration':
        return 'existential';
      case 'rage_room':
        return 'rage_room';
      case 'mental_space':
        return 'mental_space';
      case 'confession_booth':
        return 'confession';
      default:
        return 'comfort'; // Default to comfort mode
    }
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
  static Future<String> sendThumbsDownResponse(String originalMessage, String supportType, String sessionId) async {
    try {
      final mode = _mapSupportTypeToMode(supportType);
      final chatService = ChatService();
      final response = await chatService.getThumbsDownResponse(
        originalMessage: originalMessage,
        mode: mode,
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