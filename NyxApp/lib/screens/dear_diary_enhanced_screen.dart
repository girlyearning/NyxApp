import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../models/journal_folder.dart';
import '../services/journal_service.dart';
import 'journal_entry_screen.dart';
import 'package:intl/intl.dart';

class DearDiaryEnhancedScreen extends StatefulWidget {
  const DearDiaryEnhancedScreen({super.key});

  @override
  State<DearDiaryEnhancedScreen> createState() => _DearDiaryEnhancedScreenState();
}

class _DearDiaryEnhancedScreenState extends State<DearDiaryEnhancedScreen> {
  List<JournalEntry> _entries = [];
  List<JournalFolder> _folders = [];
  String _selectedFolderId = 'all'; // 'all', 'none', or folder ID
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final entries = await JournalService.getAllEntries();
    final folders = await JournalService.getAllFolders();
    
    setState(() {
      _entries = entries;
      _folders = folders;
      _isLoading = false;
    });
  }

  List<JournalEntry> get _filteredEntries {
    if (_selectedFolderId == 'all') {
      return _entries;
    } else if (_selectedFolderId == 'none') {
      return _entries.where((entry) => entry.folderId == null).toList();
    } else {
      return _entries.where((entry) => entry.folderId == _selectedFolderId).toList();
    }
  }

  Future<void> _createNewEntry() async {
    final now = DateTime.now();
    final entryId = now.millisecondsSinceEpoch.toString();
    final defaultTitle = JournalService.generateDefaultTitle();
    
    // Determine folder to save to
    String? folderId;
    if (_selectedFolderId != 'all' && _selectedFolderId != 'none') {
      folderId = _selectedFolderId;
    }
    
    final newEntry = JournalEntry(
      id: entryId,
      title: defaultTitle,
      content: '',
      createdAt: now,
      lastModified: now,
      folderId: folderId,
    );

    // Navigate to edit screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryScreen(entry: newEntry, isNew: true),
      ),
    );

    if (result == true) {
      await _loadData();
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

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You can create up to ${JournalService.maxFolders} folders.'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                hintText: 'Enter folder name',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
              autofocus: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        final success = await JournalService.createFolder(name);
        if (success) {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Folder "$name" created!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create folder (check limit and duplicates)'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
    nameController.dispose();
  }

  Future<void> _renameFolder(JournalFolder folder) async {
    final nameController = TextEditingController(text: folder.name);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty && newName != folder.name) {
        final success = await JournalService.renameFolder(folder.id, newName);
        if (success) {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Folder renamed to "$newName"'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to rename folder (check duplicates)'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
    nameController.dispose();
  }

  Future<void> _deleteFolder(JournalFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "${folder.name}"? Entries in this folder will be moved to "No Folder".'),
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
      final success = await JournalService.deleteFolder(folder.id);
      if (success) {
        setState(() {
          if (_selectedFolderId == folder.id) {
            _selectedFolderId = 'all';
          }
        });
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "${folder.name}" deleted'),
              backgroundColor: Colors.orange,
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
                  if (entry.folderId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _folders.firstWhere((f) => f.id == entry.folderId, 
                            orElse: () => JournalFolder(id: '', name: 'Unknown', createdAt: DateTime.now())).name,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteEntry(entry);
                      } else if (value == 'move') {
                        _moveEntryToFolder(entry);
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

  Widget _buildFolderChip(String title, String folderId, int count, {JournalFolder? folder}) {
    final isSelected = _selectedFolderId == folderId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFolderId = folderId;
        });
      },
      onLongPress: folder != null ? () => _showFolderOptions(folder) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              folder != null ? Icons.folder : Icons.home,
              size: 16,
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '$title ($count)',
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderOptions(JournalFolder folder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Folder'),
              onTap: () {
                Navigator.pop(context);
                _renameFolder(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Folder', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder(folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Journal'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            onPressed: _folders.length < JournalService.maxFolders ? _createFolder : null,
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Create Folder',
          ),
          IconButton(
            onPressed: _createNewEntry,
            icon: const Icon(Icons.add),
            tooltip: 'New Entry',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Folder Navigation
                if (_folders.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFolderChip('All', 'all', _entries.length),
                        const SizedBox(width: 8),
                        _buildFolderChip('No Folder', 'none', _entries.where((e) => e.folderId == null).length),
                        const SizedBox(width: 8),
                        ..._folders.map((folder) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFolderChip(
                            folder.name, 
                            folder.id, 
                            _entries.where((e) => e.folderId == folder.id).length,
                            folder: folder,
                          ),
                        )),
                      ],
                    ),
                  ),
                
                // Entries List
                Expanded(
                  child: filteredEntries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            itemCount: filteredEntries.length,
                            itemBuilder: (context, index) {
                              return _buildEntryCard(filteredEntries[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEntry,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFolderId == 'all' 
                ? 'Your Diary Awaits' 
                : 'No entries in this ${_selectedFolderId == 'none' ? 'folder' : 'category'}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFolderId == 'all'
                ? 'Start your first journal entry to capture your thoughts, feelings, and daily experiences.'
                : 'Create a new entry to add to this folder.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewEntry,
              icon: const Icon(Icons.add),
              label: Text(_selectedFolderId == 'all' ? 'Create First Entry' : 'Create Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}