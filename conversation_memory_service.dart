import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import 'chat_service.dart';
import 'logging_service.dart';

class ConversationMemoryService {
  static const String _memoriesPrefix = 'conversation_memories_';
  static const String _memoryCounterPrefix = 'memory_counter_';
  
  // Create a memory summary from a conversation session
  static Future<void> createMemoryFromSession(
    String userId,
    String mode,
    List<ChatMessage> messages,
    String sessionTitle,
  ) async {
    if (messages.isEmpty) return;
    
    try {
      // Filter out timestamp messages for summarization
      final contentMessages = messages.where((m) => m.isTimestamp != true).toList();
      if (contentMessages.isEmpty) return;
      
      // Create a conversation context for summarization
      final conversationContext = contentMessages
          .map((m) => '${m.isUser ? "User" : "Nyx"}: ${m.content}')
          .join('\n');
      
      // Generate summary using ChatService
      final summaryPrompt = '''
Please create a concise memory summary of this conversation that captures:
- Key emotional states or mental health themes discussed
- Important personal information shared by the user
- Coping strategies or insights that were helpful
- Any goals, preferences, or important context Nyx should remember

Keep it under 200 words and focus on what would be most useful for future conversations.

Conversation:
$conversationContext''';
      
      final summary = await ChatService().sendMessage(
        summaryPrompt,
        'queries', // Use queries mode for analytical summarization
        false,
      );
      
      // Create memory object
      final memory = {
        'id': _generateMemoryId(),
        'user_id': userId,
        'mode': mode,
        'summary': summary,
        'session_title': sessionTitle,
        'message_count': contentMessages.length,
        'created_at': DateTime.now().toIso8601String(),
        'importance': _determineImportance(contentMessages, summary),
        'context_type': _determineContextType(mode, summary),
      };
      
      // Save memory
      await _saveMemory(userId, memory);
      
    } catch (e) {
      // Silently fail - don't disrupt the user experience
      LoggingService.logError('Failed to create memory from session: $e');
    }
  }
  
  // Get all memories for a user
  static Future<List<Map<String, dynamic>>> getUserMemories(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final memoriesJson = prefs.getString('${_memoriesPrefix}$userId');
    
    if (memoriesJson == null) return [];
    
    try {
      final List<dynamic> memoriesList = json.decode(memoriesJson);
      return memoriesList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  
  // Delete a specific memory
  static Future<void> deleteMemory(String userId, String memoryId) async {
    final memories = await getUserMemories(userId);
    final updatedMemories = memories.where((m) => m['id'] != memoryId).toList();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_memoriesPrefix}$userId', json.encode(updatedMemories));
  }
  
  // Get memory context for chat (recent relevant memories)
  static Future<String> getMemoryContext(String userId, String currentMode, {bool isExplicitRequest = false}) async {
    final memories = await getUserMemories(userId);
    if (memories.isEmpty) return '';
    
    // Sort by relevance and recency
    memories.sort((a, b) {
      // Prefer same mode and higher importance
      int scoreA = _calculateRelevanceScore(a, currentMode);
      int scoreB = _calculateRelevanceScore(b, currentMode);
      
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      
      // Then by recency
      final dateA = DateTime.parse(a['created_at']);
      final dateB = DateTime.parse(b['created_at']);
      return dateB.compareTo(dateA);
    });
    
    // For explicit requests (when user says "remember"), provide more detailed context
    if (isExplicitRequest) {
      final relevantMemories = memories.take(5).toList();
      if (relevantMemories.isEmpty) return '';
      
      final contextParts = relevantMemories.map((memory) {
        final date = DateTime.parse(memory['created_at']);
        final timeAgo = _formatTimeAgo(date);
        return 'Previous conversation ($timeAgo): ${memory['summary']}';
      }).toList();
      
      return 'Context from previous conversations:\n${contextParts.join('\n\n')}';
    }
    
    // For background context (always included), provide subtle context
    final topMemories = memories.take(3).toList();
    if (topMemories.isEmpty) return '';
    
    // Create natural background context that informs Nyx's responses
    final contextParts = topMemories.map((memory) {
      return memory['summary'];
    }).toList();
    
    return 'Previous conversation context: ${contextParts.join(' | ')}';
  }
  
  // Get subtle background context that's always included (doesn't overwhelm the conversation)
  static Future<String> getBackgroundMemoryContext(String userId, String currentMode) async {
    final memories = await getUserMemories(userId);
    if (memories.isEmpty) return '';
    
    // Filter for most relevant and recent memories
    final filteredMemories = memories.where((memory) {
      final importance = memory['importance'] ?? 'low';
      final daysSince = DateTime.now().difference(DateTime.parse(memory['created_at'])).inDays;
      
      // Only include high importance or recent medium importance memories for background
      return (importance == 'high') || 
             (importance == 'medium' && daysSince <= 14) ||
             (daysSince <= 3); // Always include very recent conversations
    }).toList();
    
    if (filteredMemories.isEmpty) return '';
    
    // Sort by relevance
    filteredMemories.sort((a, b) {
      int scoreA = _calculateRelevanceScore(a, currentMode);
      int scoreB = _calculateRelevanceScore(b, currentMode);
      return scoreB.compareTo(scoreA);
    });
    
    // Take top 2 most relevant for background context
    final topMemories = filteredMemories.take(2).toList();
    if (topMemories.isEmpty) return '';
    
    final contextParts = topMemories.map((memory) => memory['summary']).toList();
    return 'Background context: ${contextParts.join(' | ')}';
  }
  
  // Check if user said "remember" or similar
  static bool shouldIncludeMemoryContext(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('remember') ||
           lowerMessage.contains('recall') ||
           lowerMessage.contains('mentioned before') ||
           lowerMessage.contains('talked about') ||
           lowerMessage.contains('discussed');
  }
  
  // Private helper methods
  static Future<void> _saveMemory(String userId, Map<String, dynamic> memory) async {
    final memories = await getUserMemories(userId);
    memories.add(memory);
    
    // Keep only last 50 memories to prevent excessive storage
    if (memories.length > 50) {
      memories.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
      memories.removeRange(50, memories.length);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_memoriesPrefix}$userId', json.encode(memories));
  }
  
  static String _generateMemoryId() {
    return 'memory_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  static String _determineImportance(List<ChatMessage> messages, String summary) {
    final summaryLower = summary.toLowerCase();
    final messageContent = messages.map((m) => m.content.toLowerCase()).join(' ');
    
    // High importance indicators
    if (summaryLower.contains('crisis') ||
        summaryLower.contains('suicidal') ||
        summaryLower.contains('emergency') ||
        messageContent.contains('help') ||
        messages.length > 20) {
      return 'high';
    }
    
    // Medium importance indicators
    if (summaryLower.contains('goal') ||
        summaryLower.contains('strategy') ||
        summaryLower.contains('important') ||
        summaryLower.contains('breakthrough') ||
        messages.length > 10) {
      return 'medium';
    }
    
    return 'low';
  }
  
  static String _determineContextType(String mode, String summary) {
    final summaryLower = summary.toLowerCase();
    
    if (mode == 'suicide' || summaryLower.contains('crisis')) return 'crisis';
    if (mode == 'anxiety') return 'anxiety';
    if (mode == 'depression') return 'depression';
    if (mode == 'anger') return 'anger';
    if (mode == 'addiction') return 'addiction';
    if (mode == 'comfort') return 'comfort';
    
    // Detect themes from summary
    if (summaryLower.contains('trigger')) return 'trigger';
    if (summaryLower.contains('goal')) return 'goal';
    if (summaryLower.contains('preference')) return 'preference';
    if (summaryLower.contains('coping')) return 'coping_strategy';
    if (summaryLower.contains('emotion')) return 'emotion';
    
    return 'general';
  }
  
  static int _calculateRelevanceScore(Map<String, dynamic> memory, String currentMode) {
    int score = 0;
    
    // Same mode gets bonus
    if (memory['mode'] == currentMode) score += 3;
    
    // Enhanced context type matching
    final contextType = memory['context_type'];
    
    // Mental health mode matching
    if (currentMode == 'anxiety' && contextType == 'anxiety') score += 3;
    if (currentMode == 'depression' && contextType == 'depression') score += 3;
    if (currentMode == 'anger' && contextType == 'anger') score += 3;
    if (currentMode == 'addiction' && contextType == 'addiction') score += 3;
    if (currentMode == 'suicide' && contextType == 'crisis') score += 4; // Higher priority for crisis
    
    // Comfort mode is flexible and matches emotional contexts
    if (currentMode == 'comfort' && (contextType == 'emotion' || contextType == 'comfort' || contextType == 'general')) score += 2;
    
    // Specialized tool matching
    if (currentMode == 'guided_introspection' && (contextType == 'goal' || contextType == 'preference')) score += 2;
    if (currentMode == 'childhood_trauma' && contextType == 'trigger') score += 3;
    if (currentMode == 'attachment_patterns' && contextType == 'emotion') score += 2;
    
    // Cross-mode relevance for related contexts
    if ((currentMode == 'anxiety' || currentMode == 'depression') && contextType == 'coping_strategy') score += 2;
    if (currentMode == 'anger' && (contextType == 'trigger' || contextType == 'emotion')) score += 2;
    
    // Importance weighting (enhanced)
    switch (memory['importance']) {
      case 'high': score += 4; break;
      case 'medium': score += 2; break;
      case 'low': score += 1; break;
    }
    
    // Enhanced recency scoring
    final date = DateTime.parse(memory['created_at']);
    final daysSince = DateTime.now().difference(date).inDays;
    if (daysSince <= 1) score += 3; // Very recent
    else if (daysSince <= 7) score += 2; // Recent
    else if (daysSince <= 30) score += 1; // Somewhat recent
    
    // Message count bonus (longer conversations are often more important)
    final messageCount = memory['message_count'] ?? 0;
    if (messageCount > 20) score += 2;
    else if (messageCount > 10) score += 1;
    
    return score;
  }
  
  static String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }
}