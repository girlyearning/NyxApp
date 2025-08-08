import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_entry.dart';
import '../models/journal_folder.dart';
import 'logging_service.dart';

class JournalService {
  static const String _journalKey = 'journal_entries';
  static const String _foldersKey = 'journal_folders';
  static const int maxFolders = 3;
  
  static Future<List<JournalEntry>> getAllEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_journalKey);
      
      if (jsonString == null) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      final entries = jsonList.map((json) => JournalEntry.fromJson(json)).toList();
      
      // Journal entries are now permanent by default like QYK Notes
      // Only clean up entries explicitly marked as temporary and older than 3 days
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final validEntries = entries.where((entry) {
        // Keep entries if they're permanent (default) OR if they're temporary but within 3 days
        return entry.isPermanent || (!entry.isPermanent && entry.createdAt.isAfter(threeDaysAgo));
      }).toList();
      
      // Save cleaned entries back if any were removed
      if (validEntries.length != entries.length) {
        final cleanedJsonString = json.encode(validEntries.map((e) => e.toJson()).toList());
        await prefs.setString(_journalKey, cleanedJsonString);
        LoggingService.logInfo('Cleaned up ${entries.length - validEntries.length} expired temporary journal entries');
      }
      
      return validEntries;
    } catch (e) {
      LoggingService.logError('Error loading journal entries: $e');
      return [];
    }
  }
  
  static Future<bool> saveEntry(JournalEntry entry) async {
    try {
      final entries = await getAllEntries();
      
      // Update existing entry or add new one
      final existingIndex = entries.indexWhere((e) => e.id == entry.id);
      if (existingIndex != -1) {
        entries[existingIndex] = entry;
      } else {
        entries.add(entry);
      }
      
      // Sort by creation date (newest first)
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(entries.map((e) => e.toJson()).toList());
      
      final success = await prefs.setString(_journalKey, jsonString);
      
      if (success) {
        LoggingService.logInfo('Journal entry saved: ${entry.title}');
      } else {
        LoggingService.logError('Failed to save journal entry');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error saving journal entry: $e');
      return false;
    }
  }
  
  static Future<bool> deleteEntry(String entryId) async {
    try {
      final entries = await getAllEntries();
      entries.removeWhere((entry) => entry.id == entryId);
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(entries.map((e) => e.toJson()).toList());
      
      final success = await prefs.setString(_journalKey, jsonString);
      
      if (success) {
        LoggingService.logInfo('Journal entry deleted: $entryId');
      } else {
        LoggingService.logError('Failed to delete journal entry');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error deleting journal entry: $e');
      return false;
    }
  }
  
  static Future<JournalEntry?> getEntry(String entryId) async {
    try {
      final entries = await getAllEntries();
      return entries.firstWhere((entry) => entry.id == entryId);
    } catch (e) {
      LoggingService.logError('Error getting journal entry: $e');
      return null;
    }
  }
  
  static String generateDefaultTitle() {
    final now = DateTime.now();
    final weekday = _getWeekdayName(now.weekday);
    final month = _getMonthName(now.month);
    return '$weekday, ${month} ${now.day}, ${now.year}';
  }
  
  static String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }
  
  static String _getMonthName(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return 'Unknown';
    }
  }

  static Future<bool> markEntryAsPermanent(String entryId) async {
    try {
      final entries = await getAllEntries();
      final entryIndex = entries.indexWhere((entry) => entry.id == entryId);
      
      if (entryIndex == -1) {
        LoggingService.logError('Journal entry not found: $entryId');
        return false;
      }
      
      // Update the entry to be permanent
      entries[entryIndex] = entries[entryIndex].copyWith(isPermanent: true);
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(entries.map((e) => e.toJson()).toList());
      
      final success = await prefs.setString(_journalKey, jsonString);
      
      if (success) {
        LoggingService.logInfo('Journal entry marked as permanent: $entryId');
      } else {
        LoggingService.logError('Failed to mark journal entry as permanent');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error marking journal entry as permanent: $e');
      return false;
    }
  }

  static Future<bool> removeEntryPermanentStatus(String entryId) async {
    try {
      final entries = await getAllEntries();
      final entryIndex = entries.indexWhere((entry) => entry.id == entryId);
      
      if (entryIndex == -1) {
        LoggingService.logError('Journal entry not found: $entryId');
        return false;
      }
      
      // Update the entry to be temporary
      entries[entryIndex] = entries[entryIndex].copyWith(isPermanent: false);
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(entries.map((e) => e.toJson()).toList());
      
      final success = await prefs.setString(_journalKey, jsonString);
      
      if (success) {
        LoggingService.logInfo('Journal entry permanent status removed: $entryId');
      } else {
        LoggingService.logError('Failed to remove journal entry permanent status');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error removing journal entry permanent status: $e');
      return false;
    }
  }

  // JOURNAL FOLDER MANAGEMENT METHODS

  /// Gets all journal folders
  static Future<List<JournalFolder>> getAllFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_foldersKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => JournalFolder.fromJson(json)).toList();
    } catch (e) {
      LoggingService.logError('Error loading journal folders: $e');
      return [];
    }
  }

  /// Creates a new journal folder
  static Future<bool> createFolder(String name) async {
    try {
      final trimmedName = name.trim();
      
      if (trimmedName.isEmpty || trimmedName.length > 50) {
        return false;
      }

      final existingFolders = await getAllFolders();
      
      // Check folder limit
      if (existingFolders.length >= maxFolders) {
        return false;
      }

      // Check for duplicate names
      if (existingFolders.any((folder) => folder.name.toLowerCase() == trimmedName.toLowerCase())) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final folder = JournalFolder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: trimmedName,
        createdAt: DateTime.now(),
      );

      existingFolders.add(folder);

      final jsonList = existingFolders.map((folder) => folder.toJson()).toList();
      final success = await prefs.setString(_foldersKey, json.encode(jsonList));
      
      if (success) {
        LoggingService.logInfo('Journal folder created: $trimmedName');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error creating journal folder: $e');
      return false;
    }
  }

  /// Renames a journal folder
  static Future<bool> renameFolder(String folderId, String newName) async {
    try {
      final trimmedName = newName.trim();
      
      if (trimmedName.isEmpty || trimmedName.length > 50) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final existingFolders = await getAllFolders();
      
      // Find folder to rename
      final folderIndex = existingFolders.indexWhere((folder) => folder.id == folderId);
      if (folderIndex == -1) {
        return false;
      }

      // Check for duplicate names (excluding current folder)
      if (existingFolders.any((folder) => 
          folder.id != folderId && 
          folder.name.toLowerCase() == trimmedName.toLowerCase())) {
        return false;
      }

      // Create new folder with updated name
      final updatedFolder = JournalFolder(
        id: existingFolders[folderIndex].id,
        name: trimmedName,
        createdAt: existingFolders[folderIndex].createdAt,
      );

      existingFolders[folderIndex] = updatedFolder;

      final jsonList = existingFolders.map((folder) => folder.toJson()).toList();
      final success = await prefs.setString(_foldersKey, json.encode(jsonList));
      
      if (success) {
        LoggingService.logInfo('Journal folder renamed to: $trimmedName');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error renaming journal folder: $e');
      return false;
    }
  }

  /// Deletes a journal folder and moves its entries to no folder
  static Future<bool> deleteFolder(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingFolders = await getAllFolders();
      
      existingFolders.removeWhere((folder) => folder.id == folderId);
      
      // Move entries from deleted folder to no folder
      final allEntries = await getAllEntries();
      final updatedEntries = allEntries.map((entry) {
        if (entry.folderId == folderId) {
          return entry.copyWith(folderId: null);
        }
        return entry;
      }).toList();

      // Save updated folders and entries
      final foldersJsonList = existingFolders.map((folder) => folder.toJson()).toList();
      final foldersSuccess = await prefs.setString(_foldersKey, json.encode(foldersJsonList));

      final entriesJsonList = updatedEntries.map((entry) => entry.toJson()).toList();
      final entriesSuccess = await prefs.setString(_journalKey, json.encode(entriesJsonList));
      
      final success = foldersSuccess && entriesSuccess;
      
      if (success) {
        LoggingService.logInfo('Journal folder deleted: $folderId');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error deleting journal folder: $e');
      return false;
    }
  }

  /// Gets entries by folder ID (null for no folder)
  static Future<List<JournalEntry>> getEntriesByFolder(String? folderId) async {
    try {
      final allEntries = await getAllEntries();
      return allEntries.where((entry) => entry.folderId == folderId).toList();
    } catch (e) {
      LoggingService.logError('Error getting entries by folder: $e');
      return [];
    }
  }

  /// Moves an entry to a different folder
  static Future<bool> moveEntryToFolder(String entryId, String? folderId) async {
    try {
      final allEntries = await getAllEntries();
      
      final entryIndex = allEntries.indexWhere((entry) => entry.id == entryId);
      if (entryIndex == -1) {
        return false;
      }

      // Create new entry with updated folder
      allEntries[entryIndex] = allEntries[entryIndex].copyWith(folderId: folderId);

      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(allEntries.map((entry) => entry.toJson()).toList());
      final success = await prefs.setString(_journalKey, jsonString);
      
      if (success) {
        LoggingService.logInfo('Journal entry moved to folder: $entryId -> $folderId');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error moving journal entry to folder: $e');
      return false;
    }
  }
}