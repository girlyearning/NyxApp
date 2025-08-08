import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../models/journal_folder.dart';
import '../services/journal_service.dart';
import 'journal_entry_screen.dart';

class JournalFolderViewScreen extends StatefulWidget {
  final JournalFolder? folder;  // null for "No Folder"
  final String folderName;

  const JournalFolderViewScreen({
    super.key,
    this.folder,
    required this.folderName,
  });

  @override
  State<JournalFolderViewScreen> createState() => _JournalFolderViewScreenState();
}

class _JournalFolderViewScreenState extends State<JournalFolderViewScreen> {
  List<JournalEntry> _entries = [];
  List<JournalFolder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final entries = await JournalService.getEntriesByFolder(widget.folder?.id);
      final folders = await JournalService.getAllFolders();
      
      setState(() {
        _entries = entries;
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editEntry(JournalEntry entry) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryScreen(entry: entry, isNew: false),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Are you sure you want to delete "${entry.title}"?'),
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
      final success = await JournalService.deleteEntry(entry.id);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${entry.title}"'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _moveEntryToFolder(JournalEntry entry) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Entry to Folder'),
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
      final success = await JournalService.moveEntryToFolder(entry.id, folderId);
      if (success) {
        await _loadData();
        final folderName = result == 'none' 
            ? 'No Folder' 
            : _folders.firstWhere((f) => f.id == result).name;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Entry moved to "$folderName"'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    }
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final previewText = entry.content.isEmpty 
        ? 'No content yet...' 
        : entry.content.length > 100 
            ? '${entry.content.substring(0, 100)}...' 
            : entry.content;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _editEntry(entry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'move') {
                        _moveEntryToFolder(entry);
                      } else if (value == 'delete') {
                        _deleteEntry(entry);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            Icon(Icons.folder, size: 20),
                            SizedBox(width: 8),
                            Text('Move to Folder'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(entry.lastModified),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                previewText,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No journal entries in this folder',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Move some entries to this folder to see them here.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    return _buildEntryCard(_entries[index]);
                  },
                ),
    );
  }
}