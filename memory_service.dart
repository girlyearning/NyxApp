import 'api_service.dart';
import 'conversation_memory_service.dart';

class MemoryService {
  static const String _baseUrl = '/memories';

  static Future<Map<String, dynamic>> getUserMemories(String userId) async {
    try {
      // First try to get from local conversation memories
      final localMemories = await ConversationMemoryService.getUserMemories(userId);
      
      if (localMemories.isNotEmpty) {
        return {
          'success': true,
          'message': 'User memories retrieved successfully',
          'data': {
            'memories': localMemories,
            'total_count': localMemories.length
          }
        };
      }
      
      // Fall back to API if no local memories
      final response = await APIService.get('$_baseUrl/$userId');
      return response;
    } catch (e) {
      // If API fails, still return local memories if available
      final localMemories = await ConversationMemoryService.getUserMemories(userId);
      if (localMemories.isNotEmpty) {
        return {
          'success': true,
          'message': 'Local memories retrieved successfully',
          'data': {
            'memories': localMemories,
            'total_count': localMemories.length
          }
        };
      }
      throw Exception('Failed to load memories: $e');
    }
  }

  static Future<Map<String, dynamic>> getMemorySummary(String userId) async {
    try {
      final response = await APIService.get('$_baseUrl/$userId/summary');
      return response;
    } catch (e) {
      throw Exception('Failed to load memory summary: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteMemory(String memoryId, String userId) async {
    try {
      // First try to delete from local conversation memories
      await ConversationMemoryService.deleteMemory(userId, memoryId);
      
      return {
        'success': true,
        'message': 'Memory deleted successfully',
        'data': {'deleted_memory_id': memoryId}
      };
    } catch (e) {
      // Fall back to API deletion
      try {
        final response = await APIService.delete('$_baseUrl/$memoryId?user_id=$userId');
        return response;
      } catch (apiError) {
        throw Exception('Failed to delete memory: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> searchMemories(String userId, {
    String? query,
    String? contextType,
    String? importance,
  }) async {
    try {
      String url = '$_baseUrl/$userId';
      List<String> queryParams = [];
      
      if (query != null && query.isNotEmpty) {
        queryParams.add('q=${Uri.encodeComponent(query)}');
      }
      
      if (contextType != null && contextType != 'all') {
        queryParams.add('type=${Uri.encodeComponent(contextType)}');
      }
      
      if (importance != null && importance != 'all') {
        queryParams.add('importance=${Uri.encodeComponent(importance)}');
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }
      
      final response = await APIService.get(url);
      return response;
    } catch (e) {
      throw Exception('Failed to search memories: $e');
    }
  }

  static List<Map<String, dynamic>> filterMemories(
    List<Map<String, dynamic>> memories, {
    String? searchQuery,
    String? contextType,
    String? importance,
  }) {
    return memories.where((memory) {
      bool matchesSearch = searchQuery == null || 
          searchQuery.isEmpty ||
          memory['content'].toString().toLowerCase().contains(searchQuery.toLowerCase());
          
      bool matchesType = contextType == null || 
          contextType == 'all' ||
          memory['context_type'] == contextType;
          
      bool matchesImportance = importance == null ||
          importance == 'all' ||
          memory['importance'] == importance;
          
      return matchesSearch && matchesType && matchesImportance;
    }).toList();
  }

  static List<Map<String, dynamic>> sortMemories(
    List<Map<String, dynamic>> memories, {
    String sortBy = 'timestamp',
    bool descending = true,
  }) {
    memories.sort((a, b) {
      switch (sortBy) {
        case 'importance':
          final importanceOrder = {'high': 0, 'medium': 1, 'low': 2};
          final aImportance = importanceOrder[a['importance']] ?? 2;
          final bImportance = importanceOrder[b['importance']] ?? 2;
          return descending ? 
              aImportance.compareTo(bImportance) : 
              bImportance.compareTo(aImportance);
              
        case 'timestamp':
        default:
          final aTime = DateTime.parse(a['timestamp']);
          final bTime = DateTime.parse(b['timestamp']);
          return descending ? 
              bTime.compareTo(aTime) : 
              aTime.compareTo(bTime);
      }
    });
    
    return memories;
  }

  static String formatMemoryAge(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  static String getMemoryTypeDisplayName(String contextType) {
    switch (contextType.toLowerCase()) {
      case 'preference':
        return 'Preference';
      case 'emotion':
        return 'Emotion';
      case 'goal':
        return 'Goal';
      case 'trigger':
        return 'Trigger';
      case 'coping_strategy':
        return 'Coping Strategy';
      default:
        return contextType.replaceAll('_', ' ').split(' ')
            .map((word) => word.isNotEmpty ? 
                word[0].toUpperCase() + word.substring(1).toLowerCase() : '')
            .join(' ');
    }
  }
}