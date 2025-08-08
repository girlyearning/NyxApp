import 'package:flutter/material.dart';
import '../services/session_manager_service.dart';
import '../models/chat_message.dart';
import '../widgets/chat_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SavedSessionsScreen extends StatefulWidget {
  const SavedSessionsScreen({super.key});

  @override
  State<SavedSessionsScreen> createState() => _SavedSessionsScreenState();
}

class _SavedSessionsScreenState extends State<SavedSessionsScreen> {
  List<Map<String, dynamic>> _savedSessions = [];
  Map<String, List<Map<String, dynamic>>> _folders = {};
  Map<String, Map<String, dynamic>> _folderData = {};
  List<Map<String, dynamic>> _unorganizedSessions = [];
  bool _isLoading = true;
  String? _selectedSessionId;
  List<ChatMessage>? _selectedSessionMessages;

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  Future<void> _loadSavedSessions() async {
    try {
      final sessions = await SessionManagerService.getSavedForeverSessions();
      
      if (mounted) {
        setState(() {
          _savedSessions = sessions;
        });
        
        await _loadFolders(); // Load folders after sessions are set
        
        setState(() {
          _organizeSessions();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load saved sessions: $e')),
        );
      }
    }
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('saved_sessions_folders') ?? '{}';
    final folderAssignments = prefs.getString('folder_assignments') ?? '{}';
    
    try {
      final Map<String, dynamic> foldersData = json.decode(foldersJson);
      final Map<String, dynamic> assignments = json.decode(folderAssignments);
      
      _folders.clear();
      _folderData.clear();
      
      for (final entry in foldersData.entries) {
        _folders[entry.key] = <Map<String, dynamic>>[];
        _folderData[entry.key] = entry.value;
      }
      
      // Assign sessions to folders based on assignments
      for (final session in _savedSessions) {
        final sessionId = session['sessionId'];
        final folderId = assignments[sessionId];
        if (folderId != null && _folders.containsKey(folderId)) {
          _folders[folderId]!.add(session);
        }
      }
      
    } catch (e) {
      _folders.clear();
      _folderData.clear();
    }
  }

  void _organizeSessions() {
    _unorganizedSessions.clear();
    
    // Find sessions not in any folder
    final assignedSessions = <String>{};
    for (final folderSessions in _folders.values) {
      for (final session in folderSessions) {
        assignedSessions.add(session['sessionId']);
      }
    }
    
    for (final session in _savedSessions) {
      if (!assignedSessions.contains(session['sessionId'])) {
        _unorganizedSessions.add(session);
      }
    }
  }

  Future<void> _loadSession(String residentRecordId, String sessionId) async {
    setState(() {
      _selectedSessionId = sessionId;
      _selectedSessionMessages = null;
    });

    try {
      final messages = await SessionManagerService.loadSavedSession(residentRecordId);
      if (mounted && messages != null) {
        setState(() {
          _selectedSessionMessages = messages;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load session: $e')),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildSessionsList() {
    if (_savedSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved sessions yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save important conversations to access them here',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Create Folder Button
        if (_folders.length < 3)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _showCreateFolderDialog,
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Create Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),

        // Folders
        ...(_folders.entries.map((entry) => _buildFolderSection(entry.key, entry.value))),
        
        // Unorganized Sessions
        if (_unorganizedSessions.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Unorganized (${_unorganizedSessions.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...(_unorganizedSessions.map((session) => _buildSessionTile(session))),
        ],
      ],
    );
  }

  Widget _buildFolderSection(String folderId, List<Map<String, dynamic>> sessions) {
    final folderName = _getFolderName(folderId);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
        title: Text(
          '$folderName (${sessions.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                _showRenameFolderDialog(folderId);
                break;
              case 'delete':
                _showDeleteFolderDialog(folderId);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename Folder'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Folder'),
                dense: true,
              ),
            ),
          ],
        ),
        children: [
          ...sessions.map((session) => _buildSessionTile(session, folderId: folderId)),
        ],
      ),
    );
  }

  // Folder management methods
  Future<void> _showCreateFolderDialog() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Folder name',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      await _createFolder(result);
    }
  }

  Future<void> _createFolder(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final folderId = 'folder_${DateTime.now().millisecondsSinceEpoch}';
    
    final foldersJson = prefs.getString('saved_sessions_folders') ?? '{}';
    final Map<String, dynamic> folders = json.decode(foldersJson);
    
    folders[folderId] = {
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
      'id': folderId,
    };
    
    await prefs.setString('saved_sessions_folders', json.encode(folders));
    
    setState(() {
      _folders[folderId] = [];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$name" created')),
    );
  }

  Future<void> _showRenameFolderDialog(String folderId) async {
    final currentName = _getFolderName(folderId);
    final TextEditingController controller = TextEditingController(text: currentName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Folder name',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      await _renameFolder(folderId, result);
    }
  }

  Future<void> _renameFolder(String folderId, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getString('saved_sessions_folders') ?? '{}';
    final Map<String, dynamic> folders = json.decode(foldersJson);
    
    if (folders.containsKey(folderId)) {
      folders[folderId]['name'] = newName;
      await prefs.setString('saved_sessions_folders', json.encode(folders));
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder renamed to "$newName"')),
      );
    }
  }

  Future<void> _showDeleteFolderDialog(String folderId) async {
    final folderName = _getFolderName(folderId);
    final sessionsInFolder = _folders[folderId]?.length ?? 0;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: Text(
            sessionsInFolder > 0
                ? 'Are you sure you want to delete "$folderName"? The $sessionsInFolder session(s) inside will be moved to Unorganized.'
                : 'Are you sure you want to delete "$folderName"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
    
    if (result == true) {
      await _deleteFolder(folderId);
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove folder from folders list
    final foldersJson = prefs.getString('saved_sessions_folders') ?? '{}';
    final Map<String, dynamic> folders = json.decode(foldersJson);
    final folderName = folders[folderId]?['name'] ?? 'Unknown';
    folders.remove(folderId);
    await prefs.setString('saved_sessions_folders', json.encode(folders));
    
    // Remove assignments to this folder
    final assignmentsJson = prefs.getString('folder_assignments') ?? '{}';
    final Map<String, dynamic> assignments = json.decode(assignmentsJson);
    assignments.removeWhere((key, value) => value == folderId);
    await prefs.setString('folder_assignments', json.encode(assignments));
    
    // Update UI
    setState(() {
      _folders.remove(folderId);
      _organizeSessions();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$folderName" deleted')),
    );
  }

  Future<void> _showMoveChatDialog(Map<String, dynamic> session) async {
    final availableFolders = _folders.entries
        .map((e) => MapEntry(e.key, _getFolderName(e.key)))
        .toList();
    
    if (availableFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No folders available. Create a folder first.')),
      );
      return;
    }
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Move "${session['customName']}" to folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Unorganized'),
                onTap: () => Navigator.of(context).pop('unorganized'),
              ),
              const Divider(),
              ...availableFolders.map((folder) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.value),
                onTap: () => Navigator.of(context).pop(folder.key),
              )),
            ],
          ),
        );
      },
    );
    
    if (result != null) {
      if (result == 'unorganized') {
        await _removeFromAllFolders(session['sessionId']);
      } else {
        await _moveToFolder(session['sessionId'], result);
      }
    }
  }

  Future<void> _moveToFolder(String sessionId, String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('folder_assignments') ?? '{}';
    final Map<String, dynamic> assignments = json.decode(assignmentsJson);
    
    assignments[sessionId] = folderId;
    await prefs.setString('folder_assignments', json.encode(assignments));
    
    await _loadSavedSessions();
    
    final folderName = _getFolderName(folderId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat moved to "$folderName"')),
    );
  }

  Future<void> _removeFromFolder(String sessionId, String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('folder_assignments') ?? '{}';
    final Map<String, dynamic> assignments = json.decode(assignmentsJson);
    
    assignments.remove(sessionId);
    await prefs.setString('folder_assignments', json.encode(assignments));
    
    await _loadSavedSessions();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat removed from folder')),
    );
  }

  Future<void> _removeFromAllFolders(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('folder_assignments') ?? '{}';
    final Map<String, dynamic> assignments = json.decode(assignmentsJson);
    
    assignments.remove(sessionId);
    await prefs.setString('folder_assignments', json.encode(assignments));
    
    await _loadSavedSessions();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat moved to Unorganized')),
    );
  }

  String _getFolderName(String folderId) {
    return _folderData[folderId]?['name'] ?? 'Unknown Folder';
  }

  Future<void> _showDeleteChatDialog(Map<String, dynamic> session) async {
    final customName = session['customName'] ?? 'this chat';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: Text(
            'Are you sure you want to permanently delete "$customName"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
    
    if (result == true) {
      await _deleteChat(session);
    }
  }

  Future<void> _deleteChat(Map<String, dynamic> session) async {
    final sessionId = session['sessionId'];
    final residentRecordId = session['residentRecordId'];
    final customName = session['customName'] ?? 'Chat';
    
    try {
      final success = await SessionManagerService.deleteSavedForeverSession(sessionId, residentRecordId);
      
      if (success) {
        // Clear selected session if it was the deleted one
        if (_selectedSessionId == sessionId) {
          setState(() {
            _selectedSessionId = null;
            _selectedSessionMessages = null;
          });
        }
        
        // Reload the sessions list
        await _loadSavedSessions();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "$customName"')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete chat')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
        );
      }
    }
  }

  Widget _buildSessionTile(Map<String, dynamic> session, {String? folderId}) {
    final isSelected = _selectedSessionId == session['sessionId'];
    final metadata = session['metadata'] ?? {};
    final mode = metadata['mode'] ?? 'unknown';
    final customName = session['customName'] ?? 'Session';
    final savedAt = session['savedAt'] ?? '';
    final messageCount = session['messageCount'] ?? 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        radius: 16,
        child: Icon(
          _getIconForMode(mode),
          color: Theme.of(context).colorScheme.onPrimary,
          size: 16,
        ),
      ),
      title: Text(
        customName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$messageCount messages • ${_formatDate(savedAt)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'move':
              _showMoveChatDialog(session);
              break;
            case 'remove_from_folder':
              if (folderId != null) {
                _removeFromFolder(session['sessionId'], folderId);
              }
              break;
            case 'delete':
              _showDeleteChatDialog(session);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'move',
            child: ListTile(
              leading: Icon(Icons.drive_file_move),
              title: Text('Move to Folder'),
              dense: true,
            ),
          ),
          if (folderId != null)
            const PopupMenuItem(
              value: 'remove_from_folder',
              child: ListTile(
                leading: Icon(Icons.remove_circle_outline),
                title: Text('Remove from Folder'),
                dense: true,
              ),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Chat', style: TextStyle(color: Colors.red)),
              dense: true,
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      onTap: () {
        _loadSession(session['residentRecordId'], session['sessionId']);
      },
    );
  }

  IconData _getIconForMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'comfort':
        return Icons.favorite;
      case 'asylum':
        return Icons.psychology;
      case 'chat':
        return Icons.chat;
      case 'general':
        return Icons.message;
      default:
        return Icons.folder;
    }
  }

  Widget _buildSessionContent() {
    if (_selectedSessionMessages == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a session to view',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedSessionMessages!.isEmpty) {
      return const Center(
        child: Text('This session has no messages'),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Viewing saved session',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedSessionMessages!.length} messages',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _selectedSessionMessages!.length,
            itemBuilder: (context, index) {
              final message = _selectedSessionMessages![index];
              return ChatBubble(
                message: message,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Forever Chats'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isTablet
              ? Row(
                  children: [
                    // Sessions list on the left
                    SizedBox(
                      width: 350,
                      child: _buildSessionsList(),
                    ),
                    const VerticalDivider(width: 1),
                    // Session content on the right
                    Expanded(
                      child: _buildSessionContent(),
                    ),
                  ],
                )
              : _selectedSessionId == null
                  ? _buildSessionsList()
                  : Column(
                      children: [
                        // Back button to return to list
                        Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: ListTile(
                            leading: const Icon(Icons.arrow_back),
                            title: const Text('Back to sessions'),
                            onTap: () {
                              setState(() {
                                _selectedSessionId = null;
                                _selectedSessionMessages = null;
                              });
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _buildSessionContent(),
                        ),
                      ],
                    ),
    );
  }
}