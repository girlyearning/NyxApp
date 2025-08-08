import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/qyk_note.dart';
import '../models/qyk_folder.dart';

class QykNotesService {
  static const String _storageKey = 'qyk_notes';
  static const String _foldersStorageKey = 'qyk_folders';
  static const String _userBioStorageKey = 'qyk_user_bio';
  static const int maxCharacters = 300;
  static const int maxFolders = 3;

  /// Validates note content length
  static bool isValidContent(String content) {
    return content.trim().isNotEmpty && content.trim().length <= maxCharacters;
  }

  /// Gets remaining character count for content
  static int getRemainingCharacters(String content) {
    return maxCharacters - content.length;
  }

  /// Creates a new QYK note
  static Future<bool> createNote(String content, {String? folderId}) async {
    try {
      final trimmedContent = content.trim();
      
      if (!isValidContent(trimmedContent)) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final note = QykNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: trimmedContent,
        createdAt: DateTime.now(),
        folderId: folderId,
      );

      final existingNotes = await getAllNotes();
      existingNotes.insert(0, note); // Add to beginning for chronological order

      final jsonList = existingNotes.map((note) => note.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets all QYK notes in chronological order (newest first)
  static Future<List<QykNote>> getAllNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => QykNote.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets total count of QYK notes
  static Future<int> getNotesCount() async {
    try {
      final notes = await getAllNotes();
      return notes.length;
    } catch (e) {
      return 0;
    }
  }

  /// Deletes a specific QYK note by ID
  static Future<bool> deleteNote(String noteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingNotes = await getAllNotes();
      
      existingNotes.removeWhere((note) => note.id == noteId);
      
      final jsonList = existingNotes.map((note) => note.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clears all QYK notes
  static Future<bool> clearAllNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets recent notes (up to specified limit)
  static Future<List<QykNote>> getRecentNotes([int limit = 10]) async {
    try {
      final allNotes = await getAllNotes();
      return allNotes.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Formats date for display
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      // Today - show time
      final hour = date.hour;
      final minute = date.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today at $displayHour:${minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // FOLDER MANAGEMENT METHODS

  /// Gets all folders
  static Future<List<QykFolder>> getAllFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_foldersStorageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => QykFolder.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Creates a new folder
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
      final folder = QykFolder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: trimmedName,
        createdAt: DateTime.now(),
      );

      existingFolders.add(folder);

      final jsonList = existingFolders.map((folder) => folder.toJson()).toList();
      await prefs.setString(_foldersStorageKey, json.encode(jsonList));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Renames a folder
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
      final updatedFolder = QykFolder(
        id: existingFolders[folderIndex].id,
        name: trimmedName,
        createdAt: existingFolders[folderIndex].createdAt,
      );

      existingFolders[folderIndex] = updatedFolder;

      final jsonList = existingFolders.map((folder) => folder.toJson()).toList();
      await prefs.setString(_foldersStorageKey, json.encode(jsonList));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a folder and moves its notes to no folder
  static Future<bool> deleteFolder(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingFolders = await getAllFolders();
      
      existingFolders.removeWhere((folder) => folder.id == folderId);
      
      // Move notes from deleted folder to no folder
      final allNotes = await getAllNotes();
      final updatedNotes = allNotes.map((note) {
        if (note.folderId == folderId) {
          return QykNote(
            id: note.id,
            content: note.content,
            createdAt: note.createdAt,
            folderId: null,
          );
        }
        return note;
      }).toList();

      // Save updated folders and notes
      final foldersJsonList = existingFolders.map((folder) => folder.toJson()).toList();
      await prefs.setString(_foldersStorageKey, json.encode(foldersJsonList));

      final notesJsonList = updatedNotes.map((note) => note.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(notesJsonList));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets notes by folder ID (null for no folder)
  static Future<List<QykNote>> getNotesByFolder(String? folderId) async {
    try {
      final allNotes = await getAllNotes();
      return allNotes.where((note) => note.folderId == folderId).toList();
    } catch (e) {
      return [];
    }
  }

  /// Moves a note to a different folder
  static Future<bool> moveNoteToFolder(String noteId, String? folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allNotes = await getAllNotes();
      
      final noteIndex = allNotes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        return false;
      }

      // Create new note with updated folder
      final updatedNote = QykNote(
        id: allNotes[noteIndex].id,
        content: allNotes[noteIndex].content,
        createdAt: allNotes[noteIndex].createdAt,
        folderId: folderId,
      );

      allNotes[noteIndex] = updatedNote;

      final jsonList = allNotes.map((note) => note.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reorders folders based on new arrangement
  static Future<bool> reorderFolders(List<QykFolder> reorderedFolders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reorderedFolders.map((folder) => folder.toJson()).toList();
      await prefs.setString(_foldersStorageKey, json.encode(jsonList));
      return true;
    } catch (e) {
      return false;
    }
  }

  // USER BIO METHODS

  /// Gets user bio
  static Future<String> getUserBio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userBioStorageKey) ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Saves user bio
  static Future<bool> saveUserBio(String bio) async {
    try {
      final trimmedBio = bio.trim();
      
      if (trimmedBio.length > 150) { // Max 150 characters for bio
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userBioStorageKey, trimmedBio);
      
      return true;
    } catch (e) {
      return false;
    }
  }
}