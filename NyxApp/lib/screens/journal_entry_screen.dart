import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import '../services/prompt_service.dart';
import '../providers/user_provider.dart';

class JournalEntryScreen extends StatefulWidget {
  final JournalEntry entry;
  final bool isNew;

  const JournalEntryScreen({
    super.key,
    required this.entry,
    required this.isNew,
  });

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _contentController = TextEditingController(text: widget.entry.content);
    
    // Listen for changes
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your entry'),
          backgroundColor: const Color(0xFFADCF86),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedEntry = widget.entry.copyWith(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      lastModified: DateTime.now(),
    );

    final success = await JournalService.saveEntry(updatedEntry);

    // Check if this entry contains a prompt response and save it separately
    if (success && widget.isNew) {
      await _savePromptResponseIfApplicable(updatedEntry);
    }

    setState(() {
      _isSaving = false;
    });

    if (success) {
      setState(() {
        _hasChanges = false;
      });
      
      // Track journal entry creation for achievements (only for new entries)
      if (widget.isNew && mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.incrementJournalEntries();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isNew ? 'Entry created!' : 'Entry saved!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save entry. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePromptResponseIfApplicable(JournalEntry entry) async {
    // Check if the entry content contains a prompt (generated prompts start with "Prompt:")
    final content = entry.content.trim();
    if (content.startsWith('Prompt: ') && content.contains('\n\nResponse: ')) {
      try {
        final parts = content.split('\n\nResponse: ');
        if (parts.length == 2) {
          final prompt = parts[0].substring('Prompt: '.length).trim();
          final response = parts[1].trim();
          
          if (prompt.isNotEmpty && response.isNotEmpty) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            
            // Determine prompt type based on content keywords (simple heuristic)
            String promptType = 'general';
            final promptLower = prompt.toLowerCase();
            if (promptLower.contains('feel') || promptLower.contains('emotion') || 
                promptLower.contains('yourself') || promptLower.contains('reflect') ||
                promptLower.contains('inner') || promptLower.contains('personal')) {
              promptType = 'introspective';
            }
            
            await PromptService.savePromptResponse(
              prompt: prompt,
              response: response,
              promptType: promptType,
              userId: userProvider.currentUserId,
            );
          }
        }
      } catch (e) {
        // Silently fail - don't disrupt the user's journal entry saving
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(widget.isNew ? 'New Entry' : 'Edit Entry'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _hasChanges ? _saveEntry : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _hasChanges ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title input
              TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Entry title...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
              ),
              
              const SizedBox(height: 8),
              
              // Date/time info
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isNew 
                        ? 'Creating...' 
                        : 'Last modified: ${_formatDateTime(widget.entry.lastModified)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Content input
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind today?\n\nThis is your safe space to express your thoughts, feelings, and experiences...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your thoughts are private and stored securely on your device',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              if (_hasChanges && !_isSaving)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFADCF86).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Unsaved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B8E5A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // Today
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today at $displayHour:${minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Older
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}