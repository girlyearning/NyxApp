import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/nyx_queries_session_service.dart';
import '../providers/user_provider.dart';
import '../models/chat_message.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/optimized_chat_input.dart';
import '../screens/report_content_screen.dart';

class NyxQueriesScreen extends StatefulWidget {
  const NyxQueriesScreen({super.key});

  @override
  State<NyxQueriesScreen> createState() => _NyxQueriesScreenState();
}

class _NyxQueriesScreenState extends State<NyxQueriesScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<Map<String, dynamic>> _sessions = [];
  List<ChatMessage> _currentMessages = [];
  bool _isLoading = false;
  bool _isLoadingSessions = true;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleReaction(String messageId, String reaction) async {
    final messageIndex = _currentMessages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    setState(() {
      _currentMessages[messageIndex] = _currentMessages[messageIndex].copyWith(reaction: reaction);
    });

    if (_currentSessionId != null) {
      await NyxQueriesSessionService.updateMessageReaction(_currentSessionId!, messageId, reaction);

      if (reaction == 'thumbs_down' && !_currentMessages[messageIndex].isUser) {
        final reactedMessage = _currentMessages[messageIndex];
        try {
          setState(() {
            _isLoading = true;
          });

          final response = await NyxQueriesSessionService.sendThumbsDownResponse(
            reactedMessage.content,
            _currentSessionId!,
          );

          if (mounted) {
            setState(() {
              _currentMessages.add(ChatMessage(
                content: response,
                isUser: false,
                timestamp: DateTime.now(),
              ));
              _isLoading = false;
            });
            _scrollToBottom();
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);
    try {
      final sessions = await NyxQueriesSessionService.getAllSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoadingSessions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSessions = false);
      }
    }
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String sessionId;
      
      // Create new session or use current one
      if (_currentSessionId == null) {
        sessionId = await NyxQueriesSessionService.createNewSession();
        setState(() {
          _currentSessionId = sessionId;
        });
        await _loadSessions(); // Refresh session list
      } else {
        sessionId = _currentSessionId!;
      }

      // Add user message to UI immediately
      final userMessage = ChatMessage(
        content: question,
        isUser: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _currentMessages.add(userMessage);
      });

      _questionController.clear();
      _scrollToBottom();

      // Get user provider before async operations
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Track chat session (only for the first message in this session)
      if (_currentMessages.length == 1) { // Only user message exists at this point
        await userProvider.incrementChatSessions();
      }

      // Get response from Nyx using the session service
      final response = await NyxQueriesSessionService.sendQuestion(sessionId, question, userId: userProvider.currentUserId);

      if (response.isNotEmpty) {
        final responseMessage = ChatMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        );

        if (mounted) {
          setState(() {
            _currentMessages.add(responseMessage);
          });

          _scrollToBottom();

          // Award Nyx Notes
          await userProvider.addNyxNotes(10);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question answered! +10 Nyx Notes earned 🪙'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    
    // Use jumpTo for immediate scroll without animation to reduce lag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _loadSession(String sessionId) async {
    final messages = await NyxQueriesSessionService.loadSession(sessionId);
    setState(() {
      _currentSessionId = sessionId;
      _currentMessages = messages;
    });
    _scrollToBottom();
  }

  void _startNewQuery() {
    setState(() {
      _currentSessionId = null;
      _currentMessages = [];
    });
    _focusNode.requestFocus();
  }

  Future<void> _saveForever() async {
    if (_currentSessionId == null) return;
    
    try {
      final success = await NyxQueriesSessionService.saveChatForever(_currentSessionId!);
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Query saved forever! Available in Resident Records > Sessions and stays in Queries'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save query. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving query. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSessionOptions(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Session'),
              onTap: () {
                Navigator.pop(context);
                _deleteSession(session['sessionId']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this query session? This action cannot be undone.'),
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
      await NyxQueriesSessionService.deleteSession(sessionId);
      await _loadSessions();
      
      // If current session was deleted, clear it
      if (_currentSessionId == sessionId) {
        setState(() {
          _currentSessionId = null;
          _currentMessages = [];
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays == 0) {
      final hour = timestamp.hour;
      final minute = timestamp.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today $displayHour:${minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  Future<void> _deleteCurrentQuery() async {
    if (_currentSessionId == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Query'),
        content: const Text('Are you sure you want to delete this query session? This action cannot be undone.'),
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
      await NyxQueriesSessionService.deleteSession(_currentSessionId!);
      await _loadSessions();
      
      setState(() {
        _currentSessionId = null;
        _currentMessages = [];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Query deleted')),
        );
      }
    }
  }

  Future<void> _renameCurrentQuery() async {
    if (_currentSessionId == null) return;
    
    final TextEditingController controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Query'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new query name',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null) {
      try {
        await NyxQueriesSessionService.renameSession(_currentSessionId!, newName);
        await _loadSessions();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Query renamed to "$newName"')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error renaming query. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDialog() {
    if (_currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active session to report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReportContentScreen(
          chatType: 'Nyx Queries',
          sessionId: _currentSessionId,
          chatHistory: _currentMessages,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nyx Queries',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          if (_currentSessionId != null) ...[
            IconButton(
              icon: const Icon(Icons.bookmark),
              onPressed: _saveForever,
              tooltip: 'Save Chat Forever',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCurrentQuery,
              tooltip: 'Delete Chat',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String result) {
                switch (result) {
                  case 'new_session':
                    _startNewQuery();
                    break;
                  case 'rename':
                    _renameCurrentQuery();
                    break;
                  case 'report':
                    _showReportDialog();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'new_session',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('New Query'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Rename Query'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'report',
                  child: ListTile(
                    leading: Icon(Icons.flag, color: Colors.red),
                    title: Text(
                      'Report Content',
                      style: TextStyle(color: Colors.red),
                    ),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoadingSessions
          ? const Center(child: CircularProgressIndicator())
          : _currentSessionId == null
              ? _buildSessionList()
              : _buildQueryChat(),
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No queries yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask Nyx any question to get started!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildQuestionInput(),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Question input at top
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildQuestionInput(),
        ),
        
        // Sessions list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              final createdAt = DateTime.parse(session['createdAt']);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    session['title'] ?? 'New Query',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      if ((session['messageCount'] ?? 0) > 0)
                        Text(
                          '${session['messageCount']} messages',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showSessionOptions(session),
                  ),
                  onTap: () => _loadSession(session['sessionId']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionInput() {
    return OptimizedChatInput(
      controller: _questionController,
      focusNode: _focusNode,
      onSend: _askQuestion,
      isLoading: _isLoading,
      hintText: 'Ask Nyx anything...',
      onTap: () {
        _scrollToBottom();
      },
    );
  }

  Widget _buildQueryChat() {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _currentMessages.length,
            physics: const AlwaysScrollableScrollPhysics(),
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            cacheExtent: 200.0,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ChatBubble(
                  key: ValueKey(_currentMessages[index].id),
                  message: _currentMessages[index],
                  isLoading: false,
                  userBubbleColor: Theme.of(context).colorScheme.primary,
                  onReaction: (reaction) => _handleReaction(_currentMessages[index].id, reaction),
                ),
              );
            },
          ),
        ),
        
        // Loading indicator
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Nyx is thinking...'),
              ],
            ),
          ),

        // Question input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
          ),
          child: _buildQuestionInput(),
        ),
      ],
    );
  }
}