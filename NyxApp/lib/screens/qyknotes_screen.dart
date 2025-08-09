import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/qyk_note.dart';
import '../models/qyk_folder.dart';
import '../services/qyknotes_service.dart';
import '../providers/user_provider.dart';
import 'folder_management_screen.dart';
import 'qyk_folder_view_screen.dart';

class QykNotesScreen extends StatefulWidget {
  const QykNotesScreen({super.key});

  @override
  State<QykNotesScreen> createState() => _QykNotesScreenState();
}

class _QykNotesScreenState extends State<QykNotesScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _bioFocusNode = FocusNode();
  List<QykNote> _notes = [];
  List<QykFolder> _folders = [];
  String _userBio = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditingBio = false;
  String _errorMessage = '';
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadData();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _bioController.dispose();
    _focusNode.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    setState(() {
      _errorMessage = '';
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final notes = await QykNotesService.getAllNotes();
      final folders = await QykNotesService.getAllFolders();
      final bio = await QykNotesService.getUserBio();
      
      setState(() {
        _notes = notes;
        _folders = folders;
        _userBio = bio;
        _bioController.text = bio;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<QykNote> get _filteredNotes {
    return _notes;
  }

  Future<void> _saveNote() async {
    final content = _noteController.text.trim();
    
    if (content.isEmpty) {
      setState(() => _errorMessage = 'Please enter a Qyk Note');
      return;
    }

    if (!QykNotesService.isValidContent(content)) {
      setState(() => _errorMessage = 'Qyk Note must be 300 characters or less');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final success = await QykNotesService.createNote(content);
      
      if (success) {
        _noteController.clear();
        await _loadData();
        
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.refreshQykNotesCount();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Qyk Note saved!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = 'Failed to save Qyk Note');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error saving Qyk Note');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBio() async {
    final bio = _bioController.text.trim();
    
    try {
      final success = await QykNotesService.saveUserBio(bio);
      
      if (success) {
        setState(() {
          _userBio = bio;
          _isEditingBio = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bio updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bio must be 150 characters or less'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving bio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createFolder() async {
    // Dismiss keyboard to prevent it from appearing during operation
    FocusScope.of(context).unfocus();
    
    final nameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You can create up to ${QykNotesService.maxFolders} folders.'),
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
        final success = await QykNotesService.createFolder(name);
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

  Future<void> _navigateToFolderManagement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FolderManagementScreen(),
      ),
    );
    
    // Reload data after returning from folder management
    if (result != null || mounted) {
      await _loadData();
    }
  }

  Future<void> _showFoldersDialog() async {
    // Dismiss keyboard to prevent it from appearing during operation
    FocusScope.of(context).unfocus();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View Folders'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // No Folder option
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('No Folder'),
                subtitle: Text('${_notes.where((n) => n.folderId == null).length} notes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QykFolderViewScreen(
                        folder: null,
                        folderName: 'No Folder',
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              // Actual folders
              ..._folders.map((folder) {
                final noteCount = _notes.where((n) => n.folderId == folder.id).length;
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  subtitle: Text('$noteCount notes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QykFolderViewScreen(
                          folder: folder,
                          folderName: folder.name,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToFolderManagement();
            },
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFolder(QykFolder folder) async {
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
        final success = await QykNotesService.renameFolder(folder.id, newName);
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

  Future<void> _deleteFolder(QykFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "${folder.name}"? Notes in this folder will be moved to "No Folder".'),
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
      final success = await QykNotesService.deleteFolder(folder.id);
      if (success) {
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

  Future<void> _moveNoteToFolder(QykNote note) async {
    // Dismiss keyboard to prevent it from appearing after operation
    FocusScope.of(context).unfocus();
    
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
    // Dismiss keyboard to prevent it from appearing after operation
    FocusScope.of(context).unfocus();
    
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

  @override
  Widget build(BuildContext context) {
    final remainingChars = QykNotesService.getRemainingCharacters(_noteController.text);
    final isOverLimit = remainingChars < 0;
    final filteredNotes = _filteredNotes;
    
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              final userName = userProvider.userName.isNotEmpty 
                ? userProvider.userName 
                : 'Your';
              return Text(
                '$userName\'s Qyk Notes',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
              );
            },
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'create') {
                  _createFolder();
                } else if (value == 'view') {
                  _showFoldersDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(Icons.create_new_folder),
                      SizedBox(width: 8),
                      Text('Create New Folder'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.folder_open),
                      SizedBox(width: 8),
                      Text('View Folders'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.folder),
              tooltip: 'Folder Options',
            ),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Profile Section - Social Media Style
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      final userName = userProvider.userName.isNotEmpty 
                        ? userProvider.userName 
                        : 'Your Name';
                      final profileIcon = userProvider.selectedProfileIcon;
                      
                      return Column(
                        children: [
                          // Profile Header with Bio
                          Row(
                            children: [
                              // Profile Icon
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: profileIcon.color,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  profileIcon.icon,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name and Stats
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_notes.length} Qyk Notes',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Bio Section - Right Aligned
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isEditingBio)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 200),
                                            child: TextField(
                                              controller: _bioController,
                                              focusNode: _bioFocusNode,
                                              maxLines: 2,
                                              maxLength: 150,
                                              textCapitalization: TextCapitalization.sentences,
                                              textAlign: TextAlign.right,
                                              decoration: const InputDecoration(
                                                hintText: 'Tell us about yourself...',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                counterText: '',
                                              ),
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _isEditingBio = false;
                                                    _bioController.text = _userBio;
                                                  });
                                                },
                                                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                              ),
                                              const SizedBox(width: 4),
                                              ElevatedButton(
                                                onPressed: _saveBio,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                ),
                                                child: const Text('Save', style: TextStyle(fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isEditingBio = true;
                                          });
                                          _bioFocusNode.requestFocus();
                                        },
                                        child: Container(
                                          constraints: const BoxConstraints(maxWidth: 200),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text(
                                            _userBio.isEmpty ? 'Add a bio...' : _userBio,
                                            style: TextStyle(
                                              color: _userBio.isEmpty ? Colors.grey[500] : null,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.right,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),


                // Input Section - Compact
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Qyk Note',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _noteController,
                        focusNode: _focusNode,
                        maxLines: 2,
                        maxLength: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind? (300 chars max)',
                          hintStyle: const TextStyle(fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                          contentPadding: const EdgeInsets.all(10),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveNote(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$remainingChars chars left',
                            style: TextStyle(
                              fontSize: 11,
                              color: isOverLimit 
                                ? Colors.red 
                                : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isSaving || isOverLimit || _noteController.text.trim().isEmpty 
                              ? null 
                              : _saveNote,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(60, 28),
                            ),
                            child: _isSaving 
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Notes List - Social Media Style - Takes up more space now
                Expanded(
                  child: filteredNotes.isEmpty
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
                              'No Qyk Notes yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first Qyk Note above!',
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
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _buildNoteCard(note);
                        },
                      ),
                ),
              ],
            ),
      ),
    );
  }


  void _showFolderOptions(QykFolder folder) {
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

  Widget _buildNoteCard(QykNote note) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userName = userProvider.userName.isNotEmpty 
          ? userProvider.userName 
          : 'You';
        final profileIcon = userProvider.selectedProfileIcon;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showNoteOptions(note),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User header - like social media post
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
                      if (note.folderId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _folders.firstWhere((f) => f.id == note.folderId, 
                                orElse: () => QykFolder(id: '', name: 'Unknown', createdAt: DateTime.now())).name,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNoteOptions(QykNote note) {
    // Dismiss keyboard to prevent it from appearing after operations
    FocusScope.of(context).unfocus();
    
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
}