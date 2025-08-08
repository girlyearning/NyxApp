import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journal_entry.dart';
import '../models/journal_folder.dart';
import '../services/journal_service.dart';
import '../services/prompt_service.dart';
import '../services/qotd_responses_service.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import 'journal_entry_screen.dart';
import 'journal_folder_view_screen.dart';
import 'journal_folder_management_screen.dart';
import 'package:intl/intl.dart';

class DearDiaryScreen extends StatefulWidget {
  const DearDiaryScreen({super.key});

  @override
  State<DearDiaryScreen> createState() => _DearDiaryScreenState();
}

class _DearDiaryScreenState extends State<DearDiaryScreen> {
  List<JournalEntry> _entries = [];
  List<JournalFolder> _folders = [];
  bool _isLoading = true;
  String? _currentPrompt;
  bool _isGeneratingPrompt = false;
  String? _selectedPromptType;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });

    final entries = await JournalService.getAllEntries();
    final folders = await JournalService.getAllFolders();
    
    setState(() {
      _entries = entries;
      _folders = folders;
      _isLoading = false;
    });
  }

  Future<void> _createNewEntry() async {
    final now = DateTime.now();
    final entryId = now.millisecondsSinceEpoch.toString();
    final defaultTitle = JournalService.generateDefaultTitle();
    
    final newEntry = JournalEntry(
      id: entryId,
      title: defaultTitle,
      content: '',
      createdAt: now,
      lastModified: now,
    );

    // Navigate to edit screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryScreen(entry: newEntry, isNew: true),
      ),
    );

    if (result == true) {
      await _loadEntries();
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
      await _loadEntries();
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
        await _loadEntries();
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

  Future<void> _showPromptTypeDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    // Determine background color based on current theme
    Color dialogBackgroundColor;
    Color textColor = Colors.white;
    
    switch (themeProvider.themeMode) {
      case AppThemeMode.green:
        dialogBackgroundColor = const Color(0xFF2e694a);
        break;
      case AppThemeMode.red:
        dialogBackgroundColor = const Color(0xFF750c0c);
        break;
      case AppThemeMode.orange:
        dialogBackgroundColor = const Color(0xFF8B4513); // Dark orange/saddle brown
        break;
      case AppThemeMode.blue:
        dialogBackgroundColor = const Color(0xFF163a7d);
        break;
      case AppThemeMode.purple:
      case AppThemeMode.lightPurple:
        dialogBackgroundColor = const Color(0xFF663191);
        break;
      case AppThemeMode.pink:
        dialogBackgroundColor = const Color(0xFF8B1C62); // Dark pink
        break;
      case AppThemeMode.light:
      case AppThemeMode.dark:
        // Keep default surface color for light and dark modes
        dialogBackgroundColor = Theme.of(context).colorScheme.surface;
        textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
        break;
    }
    
    final selectedType = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Choose Prompt Type',
          style: TextStyle(color: textColor),
        ),
        content: Container(
          width: double.minPositive,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // General option
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'general'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'General',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
              // Mental Health option
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'introspective'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Mental Health',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
              // ADHD option
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'adhd'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7aa5bf),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'For ADHD',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
              // ASD option
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'asd'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8BB96E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'For ASD',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
              // AuDHD option
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'audhd'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9CAE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'For AuDHD',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedType != null) {
      await _generatePrompt(selectedType);
    }
  }

  Future<void> _generatePrompt(String promptType) async {
    setState(() {
      _isGeneratingPrompt = true;
      _selectedPromptType = promptType;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final prompt = await PromptService.generatePrompt(promptType, userProvider.currentUserId);
      
      setState(() {
        _currentPrompt = prompt;
        _isGeneratingPrompt = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingPrompt = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate prompt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPromptResponseDialog() async {
    if (_currentPrompt == null) return;
    
    String responseText = '';
    final TextEditingController controller = TextEditingController();
    
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    // Determine background color based on current theme
    Color dialogBackgroundColor;
    Color textColor = Colors.white;
    
    switch (themeProvider.themeMode) {
      case AppThemeMode.green:
        dialogBackgroundColor = const Color(0xFF2e694a);
        break;
      case AppThemeMode.red:
        dialogBackgroundColor = const Color(0xFF750c0c);
        break;
      case AppThemeMode.orange:
        dialogBackgroundColor = const Color(0xFF8B4513); // Dark orange/saddle brown
        break;
      case AppThemeMode.blue:
        dialogBackgroundColor = const Color(0xFF163a7d);
        break;
      case AppThemeMode.purple:
      case AppThemeMode.lightPurple:
        dialogBackgroundColor = const Color(0xFF663191);
        break;
      case AppThemeMode.pink:
        dialogBackgroundColor = const Color(0xFF8B1C62); // Dark pink
        break;
      case AppThemeMode.light:
      case AppThemeMode.dark:
        // Keep default surface color for light and dark modes
        dialogBackgroundColor = Theme.of(context).colorScheme.surface;
        textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
        break;
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: dialogBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 500,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dialogBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prompt:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (themeProvider.themeMode == AppThemeMode.light || themeProvider.themeMode == AppThemeMode.dark)
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (themeProvider.themeMode == AppThemeMode.light || themeProvider.themeMode == AppThemeMode.dark)
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _currentPrompt!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Response:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 150,
                    maxHeight: 300,
                  ),
                  decoration: BoxDecoration(
                    color: (themeProvider.themeMode == AppThemeMode.light || themeProvider.themeMode == AppThemeMode.dark)
                        ? Theme.of(context).colorScheme.surface
                        : Colors.black.withValues(alpha: 0.2),
                    border: Border.all(
                      color: (themeProvider.themeMode == AppThemeMode.light || themeProvider.themeMode == AppThemeMode.dark)
                          ? Theme.of(context).colorScheme.outline
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Scrollbar(
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) => responseText = value,
                      decoration: InputDecoration(
                        hintText: 'Type your response here...',
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      controller.dispose();
                      Navigator.pop(context);
                    },
                    child: Text('Cancel', style: TextStyle(color: textColor)),
                  ),
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (responseText.trim().isNotEmpty) {
                          await _submitPromptResponse(responseText.trim());
                          controller.dispose();
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'Submit for 20 Nyx Notes',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    controller.dispose();
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
              autofocus: true,
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
          await _loadEntries();
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

  Future<void> _showFoldersDialog() async {
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
                subtitle: Text('${_entries.where((e) => e.folderId == null).length} entries'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JournalFolderViewScreen(
                        folder: null,
                        folderName: 'No Folder',
                      ),
                    ),
                  ).then((_) => _loadEntries());
                },
              ),
              // Actual folders
              ..._folders.map((folder) {
                final entryCount = _entries.where((e) => e.folderId == folder.id).length;
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  subtitle: Text('$entryCount entries'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JournalFolderViewScreen(
                          folder: folder,
                          folderName: folder.name,
                        ),
                      ),
                    ).then((_) => _loadEntries());
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JournalFolderManagementScreen(),
                ),
              ).then((_) => _loadEntries());
            },
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPromptResponse(String responseText) async {
    if (_currentPrompt == null || _selectedPromptType == null) return;
    
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final now = DateTime.now();
      
      // Create journal entry
      final entryId = now.millisecondsSinceEpoch.toString();
      final defaultTitle = 'Prompt Response - ${DateFormat('MMM d, yyyy').format(now)}';
      
      final newEntry = JournalEntry(
        id: entryId,
        title: defaultTitle,
        content: 'Prompt: $_currentPrompt\n\nResponse: $responseText',
        createdAt: now,
        lastModified: now,
      );
      
      // Save to Personal Journal
      await JournalService.saveEntry(newEntry);
      
      // Save to Prompt Responses in Resident Records
      await PromptService.savePromptResponse(
        prompt: _currentPrompt!,
        response: responseText,
        promptType: _selectedPromptType!,
        userId: userProvider.currentUserId,
      );
      
      // Save to QOTD responses service for Resident Records access
      await QotdResponsesService.saveResponse(
        'Prompt: $_currentPrompt',
        responseText,
      );
      
      // Award 20 Nyx Notes
      await userProvider.addNyxNotes(20);
      
      // Reload entries but don't clear prompt
      await _loadEntries();
      // Remove this to prevent prompts from disappearing:
      // setState(() {
      //   _currentPrompt = null;
      //   _selectedPromptType = null;
      // });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response saved! You earned 20 Nyx Notes! 🎉'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save response: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildPromptGenerator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Prompt Generator',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/nyx_icon.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 14,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentPrompt == null && !_isGeneratingPrompt)
            Text(
              'Have Nyx generate a prompt to inspire your journaling!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            )
          else if (_isGeneratingPrompt)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating ${_selectedPromptType} prompt...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            )
          else if (_currentPrompt != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                _currentPrompt!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_currentPrompt == null && !_isGeneratingPrompt)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showPromptTypeDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Generate'),
                  ),
                )
              else if (_currentPrompt != null) ...[
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _showPromptResponseDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Answer Prompt'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Clear prompt and generate new one
                      setState(() {
                        _currentPrompt = null;
                      });
                      _generatePrompt(_selectedPromptType!);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    child: const Text('New Prompt'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
                      if (value == 'delete') {
                        _deleteEntry(entry);
                      }
                    },
                    itemBuilder: (context) => [
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
        title: const Text('Personal Journal'),
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
                _buildPromptGenerator(),
                Expanded(
                  child: _entries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadEntries,
                          child: ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              return _buildEntryCard(_entries[index]);
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
              'Your Diary Awaits',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start your first journal entry to capture your thoughts, feelings, and daily experiences.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewEntry,
              icon: const Icon(Icons.add),
              label: const Text('Create First Entry'),
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