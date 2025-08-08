import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/qyk_note.dart';
import '../models/qyk_folder.dart';
import '../services/qyknotes_service.dart';
import '../providers/user_provider.dart';

class QykFolderViewScreen extends StatefulWidget {
  final QykFolder? folder;  // null for "No Folder"
  final String folderName;

  const QykFolderViewScreen({
    super.key,
    this.folder,
    required this.folderName,
  });

  @override
  State<QykFolderViewScreen> createState() => _QykFolderViewScreenState();
}

class _QykFolderViewScreenState extends State<QykFolderViewScreen> {
  List<QykNote> _notes = [];
  List<QykFolder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notes = await QykNotesService.getNotesByFolder(widget.folder?.id);
      final folders = await QykNotesService.getAllFolders();
      
      setState(() {
        _notes = notes;
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveNoteToFolder(QykNote note) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Note to Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('No Folder'),
              onTap: () => Navigator.pop(context, 'none'),
              leading: const Icon(Icons.folder_open),
            ),
            ..._folders.map((folder) => ListTile(
              title: Text(folder.name),
              onTap: () => Navigator.pop(context, folder.id),
              leading: const Icon(Icons.folder),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      final folderId = result == 'none' ? null : result;
      final success = await QykNotesService.moveNoteToFolder(note.id, folderId);
      if (success) {
        await _loadData();
        final folderName = result == 'none' 
            ? 'No Folder' 
            : _folders.firstWhere((f) => f.id == result).name;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Note moved to "$folderName"'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteNote(QykNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Qyk Note'),
        content: const Text('Are you sure you want to delete this Qyk Note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await QykNotesService.deleteNote(note.id);
      if (success) {
        await _loadData();
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshQykNotesCount();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Qyk Note deleted')),
          );
        }
      }
    }
  }

  Widget _buildNoteCard(QykNote note) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userName = userProvider.userName.isNotEmpty 
          ? userProvider.userName 
          : 'You';
        final profileIcon = userProvider.selectedProfileIcon;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showNoteOptions(note),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User header
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: profileIcon.color,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          profileIcon.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              QykNotesService.formatDate(note.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.more_vert,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Note content
                  Text(
                    note.content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Footer with interaction hint
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Qyk Note',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap for options',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNoteOptions(QykNote note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Move to Folder'),
              onTap: () {
                Navigator.pop(context);
                _moveNoteToFolder(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Qyk Notes in this folder',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Move some notes to this folder to see them here.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    return _buildNoteCard(_notes[index]);
                  },
                ),
    );
  }
}