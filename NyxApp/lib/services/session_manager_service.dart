import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/logging_service.dart';

class SessionManagerService {
  static const String _sessionPrefix = 'session_';
  static const String _residentRecordsPrefix = 'resident_records_';
  static const String _savedForeverPrefix = 'saved_forever_';
  static const String _activeSessionKey = 'active_session_';
  static const String _sessionMetadataPrefix = 'session_metadata_';
  static const String _archivedSessionsKey = 'archived_sessions';
  static const String _residentRecordsMetaKey = 'resident_records_metadata';

  // Create a new chat session and archive the current one
  static Future<String> createNewSession(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current active session for this mode
    final currentSessionKey = '$_activeSessionKey$mode';
    final currentSessionId = prefs.getString(currentSessionKey);
    
    // Archive current session if it exists
    if (currentSessionId != null) {
      await _archiveSession(currentSessionId, mode, autoArchive: true);
    }
    
    // Generate new session ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newSessionId = '${mode}_$timestamp';
    
    // Set as active session
    await prefs.setString(currentSessionKey, newSessionId);
    
    // Initialize session metadata
    final metadata = {
      'sessionId': newSessionId,
      'mode': mode,
      'createdAt': DateTime.now().toIso8601String(),
      'lastUpdated': DateTime.now().toIso8601String(),
      'messageCount': 0,
      'isArchived': false,
      'isSavedForever': false,
    };
    
    await prefs.setString('$_sessionMetadataPrefix$newSessionId', json.encode(metadata));
    
    LoggingService.logInfo('Created new session: $newSessionId for mode: $mode');
    return newSessionId;
  }

  // Save the current session forever to Resident Records
  static Future<bool> saveSessionForever(String sessionId, {String? customName}) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Load session data
      final sessionKey = '$_sessionPrefix$sessionId';
      final messagesJson = prefs.getString(sessionKey);
      if (messagesJson == null) {
        LoggingService.logError('Session not found: $sessionId');
        return false;
      }
      
      // Load session metadata
      final metadataKey = '$_sessionMetadataPrefix$sessionId';
      final metadataJson = prefs.getString(metadataKey);
      Map<String, dynamic> metadata = {};
      if (metadataJson != null) {
        metadata = json.decode(metadataJson);
      }
      
      // Update metadata for saved forever
      metadata['isSavedForever'] = true;
      metadata['savedAt'] = DateTime.now().toIso8601String();
      metadata['savedName'] = customName ?? 'Session ${DateTime.now().toLocal()}';
      metadata['savedBy'] = 'user';
      
      // Create Resident Records entry
      final residentRecordId = '${sessionId}_saved_${DateTime.now().millisecondsSinceEpoch}';
      final residentRecordKey = '$_residentRecordsPrefix$residentRecordId';
      
      // Create resident record data
      final residentRecord = {
        'originalSessionId': sessionId,
        'sessionData': json.decode(messagesJson),
        'metadata': metadata,
        'savedAt': DateTime.now().toIso8601String(),
        'recordType': 'saved_forever',
      };
      
      // Save to Resident Records
      await prefs.setString(residentRecordKey, json.encode(residentRecord));
      
      // Save to Saved Forever collection
      final savedForeverKey = '$_savedForeverPrefix$sessionId';
      await prefs.setString(savedForeverKey, json.encode({
        'residentRecordId': residentRecordId,
        'savedAt': DateTime.now().toIso8601String(),
        'customName': customName,
      }));
      
      // Update session metadata
      await prefs.setString(metadataKey, json.encode(metadata));
      
      // Update Resident Records metadata
      await _updateResidentRecordsMetadata(residentRecordId, metadata);
      
      LoggingService.logInfo('Session saved forever: $sessionId as $residentRecordId');
      return true;
      
    } catch (e) {
      LoggingService.logError('Failed to save session forever: $e');
      return false;
    }
  }

  // Archive a session (move to Resident Records)
  static Future<void> _archiveSession(String sessionId, String mode, {bool autoArchive = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Load session data
      final sessionKey = '$_sessionPrefix$sessionId';
      final messagesJson = prefs.getString(sessionKey);
      if (messagesJson == null) return;
      
      // Load metadata
      final metadataKey = '$_sessionMetadataPrefix$sessionId';
      final metadataJson = prefs.getString(metadataKey);
      Map<String, dynamic> metadata = {};
      if (metadataJson != null) {
        metadata = json.decode(metadataJson);
      }
      
      // Check if already archived
      if (metadata['isArchived'] == true) return;
      
      // Update metadata for archiving
      metadata['isArchived'] = true;
      metadata['archivedAt'] = DateTime.now().toIso8601String();
      metadata['autoArchived'] = autoArchive;
      
      // Create archive record
      final archiveId = '${sessionId}_archive_${DateTime.now().millisecondsSinceEpoch}';
      final archiveKey = '$_residentRecordsPrefix$archiveId';
      
      final archiveRecord = {
        'originalSessionId': sessionId,
        'sessionData': json.decode(messagesJson),
        'metadata': metadata,
        'archivedAt': DateTime.now().toIso8601String(),
        'recordType': autoArchive ? 'auto_archive' : 'manual_archive',
      };
      
      // Save to Resident Records
      await prefs.setString(archiveKey, json.encode(archiveRecord));
      
      // Add to archived sessions list
      final archivedSessionsJson = prefs.getString(_archivedSessionsKey);
      List<String> archivedSessions = [];
      if (archivedSessionsJson != null) {
        archivedSessions = List<String>.from(json.decode(archivedSessionsJson));
      }
      archivedSessions.add(archiveId);
      await prefs.setString(_archivedSessionsKey, json.encode(archivedSessions));
      
      // Remove original session data (it's now in Resident Records)
      await prefs.remove(sessionKey);
      
      // Update metadata to reflect archived status
      await prefs.setString(metadataKey, json.encode(metadata));
      
      LoggingService.logInfo('Session archived: $sessionId as $archiveId');
      
    } catch (e) {
      LoggingService.logError('Failed to archive session: $e');
    }
  }

  // Update Resident Records metadata
  static Future<void> _updateResidentRecordsMetadata(String recordId, Map<String, dynamic> sessionMetadata) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Load existing resident records metadata
      final metadataJson = prefs.getString(_residentRecordsMetaKey);
      Map<String, dynamic> residentMeta = {};
      if (metadataJson != null) {
        residentMeta = json.decode(metadataJson);
      }
      
      // Initialize structure if needed
      if (!residentMeta.containsKey('records')) {
        residentMeta['records'] = {};
      }
      if (!residentMeta.containsKey('savedForeverCount')) {
        residentMeta['savedForeverCount'] = 0;
      }
      if (!residentMeta.containsKey('lastUpdated')) {
        residentMeta['lastUpdated'] = DateTime.now().toIso8601String();
      }
      
      // Add this record
      residentMeta['records'][recordId] = {
        'mode': sessionMetadata['mode'],
        'savedAt': sessionMetadata['savedAt'],
        'savedName': sessionMetadata['savedName'],
        'messageCount': sessionMetadata['messageCount'],
      };
      
      // Update counts
      residentMeta['savedForeverCount'] = (residentMeta['savedForeverCount'] as int) + 1;
      residentMeta['lastUpdated'] = DateTime.now().toIso8601String();
      
      // Save updated metadata
      await prefs.setString(_residentRecordsMetaKey, json.encode(residentMeta));
      
    } catch (e) {
      LoggingService.logError('Failed to update resident records metadata: $e');
    }
  }

  // Get all saved forever sessions
  static Future<List<Map<String, dynamic>>> getSavedForeverSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSessions = <Map<String, dynamic>>[];
    
    try {
      // Get all keys
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_savedForeverPrefix)) {
          final savedDataJson = prefs.getString(key);
          if (savedDataJson != null) {
            final savedData = json.decode(savedDataJson);
            final residentRecordId = savedData['residentRecordId'];
            
            // Load the resident record
            final recordKey = '$_residentRecordsPrefix$residentRecordId';
            final recordJson = prefs.getString(recordKey);
            if (recordJson != null) {
              final record = json.decode(recordJson);
              savedSessions.add({
                'sessionId': key.substring(_savedForeverPrefix.length),
                'residentRecordId': residentRecordId,
                'customName': savedData['customName'],
                'savedAt': savedData['savedAt'],
                'metadata': record['metadata'],
                'messageCount': (record['sessionData'] as List).length,
              });
            }
          }
        }
      }
      
      // Sort by saved date (newest first)
      savedSessions.sort((a, b) {
        final aDate = DateTime.parse(a['savedAt']);
        final bDate = DateTime.parse(b['savedAt']);
        return bDate.compareTo(aDate);
      });
      
    } catch (e) {
      LoggingService.logError('Failed to get saved forever sessions: $e');
    }
    
    return savedSessions;
  }

  // Load a saved session from Resident Records
  static Future<List<ChatMessage>?> loadSavedSession(String residentRecordId) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final recordKey = '$_residentRecordsPrefix$residentRecordId';
      final recordJson = prefs.getString(recordKey);
      
      if (recordJson != null) {
        final record = json.decode(recordJson);
        final sessionData = record['sessionData'] as List;
        
        return sessionData.map((json) => ChatMessage.fromJson(json)).toList();
      }
    } catch (e) {
      LoggingService.logError('Failed to load saved session: $e');
    }
    
    return null;
  }

  // Get active session for a mode
  static Future<String?> getActiveSession(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_activeSessionKey$mode');
  }

  // Save messages to current active session
  static Future<void> saveToActiveSession(String mode, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get active session
    final activeSessionId = await getActiveSession(mode);
    if (activeSessionId == null) {
      LoggingService.logError('No active session for mode: $mode');
      return;
    }
    
    // Save messages
    final sessionKey = '$_sessionPrefix$activeSessionId';
    final messagesJson = messages.map((m) => m.toJson()).toList();
    await prefs.setString(sessionKey, json.encode(messagesJson));
    
    // Update metadata
    final metadataKey = '$_sessionMetadataPrefix$activeSessionId';
    final metadataJson = prefs.getString(metadataKey);
    if (metadataJson != null) {
      final metadata = json.decode(metadataJson);
      metadata['lastUpdated'] = DateTime.now().toIso8601String();
      metadata['messageCount'] = messages.length;
      await prefs.setString(metadataKey, json.encode(metadata));
    }
  }

  // Load messages from active session
  static Future<List<ChatMessage>> loadActiveSession(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get active session
    final activeSessionId = await getActiveSession(mode);
    if (activeSessionId == null) {
      // Create new session if none exists
      final newSessionId = await createNewSession(mode);
      return [];
    }
    
    // Load messages
    final sessionKey = '$_sessionPrefix$activeSessionId';
    final messagesJson = prefs.getString(sessionKey);
    
    if (messagesJson == null) return [];
    
    try {
      final List<dynamic> messages = json.decode(messagesJson);
      return messages.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      LoggingService.logError('Failed to load active session: $e');
      return [];
    }
  }

  // Get session metadata
  static Future<Map<String, dynamic>?> getSessionMetadata(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final metadataKey = '$_sessionMetadataPrefix$sessionId';
    final metadataJson = prefs.getString(metadataKey);
    
    if (metadataJson != null) {
      return json.decode(metadataJson);
    }
    return null;
  }

  // Delete a saved forever session
  static Future<bool> deleteSavedForeverSession(String sessionId, String residentRecordId) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Remove from saved forever collection
      final savedForeverKey = '$_savedForeverPrefix$sessionId';
      await prefs.remove(savedForeverKey);
      
      // Remove from resident records
      final recordKey = '$_residentRecordsPrefix$residentRecordId';
      await prefs.remove(recordKey);
      
      // Update resident records metadata
      await _removeFromResidentRecordsMetadata(residentRecordId);
      
      // Remove folder assignment if exists
      await _removeFolderAssignment(sessionId);
      
      LoggingService.logInfo('Deleted saved forever session: $sessionId');
      return true;
      
    } catch (e) {
      LoggingService.logError('Failed to delete saved forever session: $e');
      return false;
    }
  }

  // Remove record from resident records metadata
  static Future<void> _removeFromResidentRecordsMetadata(String recordId) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final metadataJson = prefs.getString(_residentRecordsMetaKey);
      if (metadataJson != null) {
        final residentMeta = json.decode(metadataJson);
        
        // Remove the record
        if (residentMeta['records'] != null) {
          residentMeta['records'].remove(recordId);
        }
        
        // Update count
        if (residentMeta['savedForeverCount'] != null && residentMeta['savedForeverCount'] > 0) {
          residentMeta['savedForeverCount'] = residentMeta['savedForeverCount'] - 1;
        }
        
        residentMeta['lastUpdated'] = DateTime.now().toIso8601String();
        
        await prefs.setString(_residentRecordsMetaKey, json.encode(residentMeta));
      }
    } catch (e) {
      LoggingService.logError('Failed to remove from resident records metadata: $e');
    }
  }

  // Remove folder assignment for a session
  static Future<void> _removeFolderAssignment(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final assignmentsJson = prefs.getString('folder_assignments') ?? '{}';
      final Map<String, dynamic> assignments = json.decode(assignmentsJson);
      
      if (assignments.containsKey(sessionId)) {
        assignments.remove(sessionId);
        await prefs.setString('folder_assignments', json.encode(assignments));
      }
    } catch (e) {
      LoggingService.logError('Failed to remove folder assignment: $e');
    }
  }

  // Get Resident Records statistics
  static Future<Map<String, dynamic>> getResidentRecordsStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    final stats = {
      'totalSavedForever': 0,
      'totalArchived': 0,
      'totalRecords': 0,
      'modes': <String, int>{},
    };
    
    try {
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_residentRecordsPrefix)) {
          stats['totalRecords'] = (stats['totalRecords'] as int) + 1;
          
          final recordJson = prefs.getString(key);
          if (recordJson != null) {
            final record = json.decode(recordJson);
            final recordType = record['recordType'];
            
            if (recordType == 'saved_forever') {
              stats['totalSavedForever'] = (stats['totalSavedForever'] as int) + 1;
            } else if (recordType == 'auto_archive' || recordType == 'manual_archive') {
              stats['totalArchived'] = (stats['totalArchived'] as int) + 1;
            }
            
            // Count by mode
            final metadata = record['metadata'];
            if (metadata != null && metadata['mode'] != null) {
              final mode = metadata['mode'] as String;
              final modes = stats['modes'] as Map<String, int>;
              modes[mode] = (modes[mode] ?? 0) + 1;
            }
          }
        }
      }
    } catch (e) {
      LoggingService.logError('Failed to get resident records stats: $e');
    }
    
    return stats;
  }
}