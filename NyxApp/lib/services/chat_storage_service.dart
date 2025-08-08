import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ChatStorageService {
  static const String _chatHistoryPrefix = 'chat_history_';
  static const String _chatTimestampPrefix = 'chat_timestamp_';
  static const String _savedForeverPrefix = 'chat_saved_forever_';
  static const Duration _defaultRetentionPeriod = Duration(days: 3);

  // Save chat messages for a specific session (limit to last 150 messages)
  static Future<void> saveChatHistory(String sessionId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Limit to last 150 messages for context management
    final limitedMessages = messages.length > 150 ? messages.sublist(messages.length - 150) : messages;
    final messagesJson = limitedMessages.map((m) => m.toJson()).toList();
    
    await prefs.setString('${_chatHistoryPrefix}${sessionId}', json.encode(messagesJson));
    await prefs.setInt('${_chatTimestampPrefix}${sessionId}', DateTime.now().millisecondsSinceEpoch);
  }

  // Load chat messages for a specific session
  static Future<List<ChatMessage>> loadChatHistory(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if chat is saved forever
    final isSavedForever = prefs.getBool('${_savedForeverPrefix}${sessionId}') ?? false;
    
    // Check if chat has expired (only if not saved forever)
    if (!isSavedForever) {
      final timestamp = prefs.getInt('${_chatTimestampPrefix}${sessionId}');
      if (timestamp != null) {
        final chatDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        if (now.difference(chatDate) > _defaultRetentionPeriod) {
          // Chat has expired, remove it
          await deleteChatHistory(sessionId);
          return [];
        }
      }
    }

    final messagesString = prefs.getString('${_chatHistoryPrefix}${sessionId}');
    if (messagesString == null) return [];

    try {
      final List<dynamic> messagesJson = json.decode(messagesString);
      return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  // Delete chat history for a specific session
  static Future<void> deleteChatHistory(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_chatHistoryPrefix}${sessionId}');
    await prefs.remove('${_chatTimestampPrefix}${sessionId}');
    await prefs.remove('${_savedForeverPrefix}${sessionId}');
  }

  // Mark a chat to be saved forever
  static Future<void> saveChatForever(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_savedForeverPrefix}${sessionId}', true);
  }

  // Create a permanent copy of a chat (for folder storage)
  static Future<String> createPermanentCopy(String originalSessionId) async {
    // Load the original chat messages
    final originalMessages = await loadChatHistory(originalSessionId);
    if (originalMessages.isEmpty) return originalSessionId;
    
    // Create a new permanent session ID
    final permanentSessionId = '${originalSessionId}_permanent_${DateTime.now().millisecondsSinceEpoch}';
    
    // Save the messages to the new permanent session
    await saveChatHistory(permanentSessionId, originalMessages);
    await saveChatForever(permanentSessionId);
    
    return permanentSessionId;
  }

  // Remove forever save status (chat will expire in 3 days from now)
  static Future<void> removeSaveForever(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_savedForeverPrefix}${sessionId}');
    // Update timestamp to current time so it expires 3 days from now
    await prefs.setInt('${_chatTimestampPrefix}${sessionId}', DateTime.now().millisecondsSinceEpoch);
  }

  // Check if a chat is saved forever
  static Future<bool> isChatSavedForever(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_savedForeverPrefix}${sessionId}') ?? false;
  }

  // Delete a chat saved forever (removes the forever status)
  static Future<void> deleteSavedForeverChat(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_savedForeverPrefix}${sessionId}');
  }

  // Get all available chat sessions (not expired)
  static Future<List<String>> getAvailableSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final sessionInfoList = <Map<String, dynamic>>[];

    for (final key in keys) {
      if (key.startsWith(_chatHistoryPrefix)) {
        final sessionId = key.substring(_chatHistoryPrefix.length);
        
        // Check if session is saved forever
        final isSavedForever = prefs.getBool('${_savedForeverPrefix}${sessionId}') ?? false;
        
        // Get timestamp
        final timestamp = prefs.getInt('${_chatTimestampPrefix}${sessionId}');
        if (timestamp == null) continue;
        
        final chatDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        
        if (isSavedForever || now.difference(chatDate) <= _defaultRetentionPeriod) {
          sessionInfoList.add({
            'sessionId': sessionId,
            'timestamp': timestamp,
          });
        } else {
          // Remove expired session
          await deleteChatHistory(sessionId);
        }
      }
    }

    // Sort by timestamp descending (most recent first)
    sessionInfoList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    
    return sessionInfoList.map((info) => info['sessionId'] as String).toList();
  }

  // Clean up all expired chats
  static Future<void> cleanupExpiredChats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_chatHistoryPrefix)) {
        final sessionId = key.substring(_chatHistoryPrefix.length);
        
        // Skip chats saved forever
        final isSavedForever = prefs.getBool('${_savedForeverPrefix}${sessionId}') ?? false;
        if (isSavedForever) continue;

        // Check if chat has expired
        final timestamp = prefs.getInt('${_chatTimestampPrefix}${sessionId}');
        if (timestamp != null) {
          final chatDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          if (now.difference(chatDate) > _defaultRetentionPeriod) {
            await deleteChatHistory(sessionId);
          }
        }
      }
    }
  }

  // Generate a unique session ID
  static String generateSessionId(String mode) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${mode}_${timestamp}';
  }

  // Check if we need to add a timestamp message for conversation gap (3+ hours)
  static bool shouldAddTimestamp(List<ChatMessage> messages) {
    if (messages.isEmpty) return false;
    
    final lastMessage = messages.last;
    final now = DateTime.now();
    final timeSinceLastMessage = now.difference(lastMessage.timestamp);
    
    return timeSinceLastMessage.inHours >= 3;
  }

  // Create a timestamp message
  static ChatMessage createTimestampMessage() {
    final now = DateTime.now();
    return ChatMessage(
      content: '--- ${_formatTimestamp(now)} ---',
      isUser: false,
      timestamp: now,
      isTimestamp: true,
    );
  }

  // Format timestamp for display
  static String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today at $displayHour:${minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Older - show date
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  // Add message with automatic timestamp if needed
  static Future<void> addMessageWithTimestamp(String sessionId, List<ChatMessage> currentMessages, ChatMessage newMessage) async {
    final updatedMessages = List<ChatMessage>.from(currentMessages);
    
    // Add timestamp if there's a 3+ hour gap
    if (shouldAddTimestamp(currentMessages)) {
      updatedMessages.add(createTimestampMessage());
    }
    
    // Add the new message
    updatedMessages.add(newMessage);
    
    // Save with context limit
    await saveChatHistory(sessionId, updatedMessages);
  }
}