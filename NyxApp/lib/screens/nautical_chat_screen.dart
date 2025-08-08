import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/nautical_nyx_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/optimized_chat_input.dart';
import '../providers/user_provider.dart';
import '../utils/personality_colors.dart';
import '../screens/report_content_screen.dart';

class NauticalChatScreen extends StatefulWidget {
  final String sessionId;
  final String personality;
  final String title;

  const NauticalChatScreen({
    super.key,
    required this.sessionId,
    required this.personality,
    required this.title,
  });

  @override
  State<NauticalChatScreen> createState() => _NauticalChatScreenState();
}

class _NauticalChatScreenState extends State<NauticalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _createMemoryIfNeeded();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _createMemoryIfNeeded() async {
    if (_messages.length > 4) { // Only create memory if there's meaningful conversation
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await NauticalNyxService.createMemoryFromSession(
          widget.sessionId,
          userProvider.currentUserId,
          widget.personality,
        );
      } catch (e) {
        // Silently fail - don't interrupt user experience
      }
    }
  }

  Future<void> _handleReaction(String messageId, String reaction) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    setState(() {
      _messages[messageIndex] = _messages[messageIndex].copyWith(reaction: reaction);
    });

    await NauticalNyxService.updateMessageReaction(widget.sessionId, messageId, reaction);

    if (reaction == 'thumbs_down' && !_messages[messageIndex].isUser) {
      final reactedMessage = _messages[messageIndex];
      try {
        setState(() {
          _isLoading = true;
        });

        final response = await NauticalNyxService.sendThumbsDownResponse(
          reactedMessage.content,
          widget.personality,
          widget.sessionId,
        );

        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
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

  Future<void> _loadSession() async {
    final messages = await NauticalNyxService.loadSession(widget.sessionId);
    
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
    });
    
    // Add welcome message if this is a new session
    if (_messages.isEmpty) {
      final welcomeMessage = _getWelcomeMessage();
      if (welcomeMessage.isNotEmpty) {
        final message = ChatMessage(
          content: welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _messages.add(message);
        });
        
        // Save the welcome message
        await NauticalNyxService.saveSession(widget.sessionId, _messages);
      }
    }
    
    _scrollToBottom();
  }

  String _getWelcomeMessage() {
    switch (widget.personality) {
      case 'default':
        return "Nurse Nyx is here to help. What's on your mind today?";
      case 'ride_or_die':
        return "How's my other half doing?";
      case 'dream_analyst':
        return "Welcome to the realm of dreams and the unconscious mind. I'm here to help you explore the fascinating world of your dreams and psychological patterns. Have any interesting dreams lately?";
      case 'debate_master':
        return "I hope you enjoy being rage-baited. What would you like to debate today?";
      case 'adhd':
      case 'autistic':
      case 'audhd':
        return "Nice of you to pop in. What's up?";
      default:
        return "Hello! I'm Nyx, and I'm here to support you. How are you feeling today?";
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message immediately
    final userMessage = ChatMessage(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Get AI response through the service
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Track chat session (only for the first message)
      if (_messages.length == 1) { // Only user message exists at this point
        await userProvider.incrementChatSessions();
      }
      
      final aiResponse = await NauticalNyxService.sendMessage(
        widget.sessionId,
        text,
        widget.personality,
        userId: userProvider.currentUserId,
      );

      // Add AI message
      final aiMessage = ChatMessage(
        content: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            content: "I'm having trouble connecting right now. Please try again in a moment.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveForever() async {
    try {
      final success = await NauticalNyxService.saveChatForever(widget.sessionId);
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat saved forever! You can find it in Resident Records > Sessions'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save chat. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving chat. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startNewSession() async {
    try {
      final newSessionId = await NauticalNyxService.createNewSession(widget.personality);
      if (!mounted) return;
      
      // Navigate to new session
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => NauticalChatScreen(
            sessionId: newSessionId,
            personality: widget.personality,
            title: widget.title,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error creating new session. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCurrentChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat? This action cannot be undone.'),
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
      try {
        await NauticalNyxService.deleteSession(widget.sessionId);
        if (!mounted) return;
        
        // Navigate back to sessions list
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting chat. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _renameChat() async {
    final TextEditingController controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new chat name',
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
        await NauticalNyxService.renameSession(widget.sessionId, newName);
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat renamed to "$newName"')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error renaming chat. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: _saveForever,
            tooltip: 'Save Chat Forever',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCurrentChat,
            tooltip: 'Delete Chat',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String result) {
              switch (result) {
                case 'new_session':
                  _startNewSession();
                  break;
                case 'rename':
                  _renameChat();
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
                  leading: Icon(Icons.refresh),
                  title: Text('New Session'),
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Rename Chat'),
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
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ChatBubble(
                    message: _messages[index],
                    isLoading: false,
                    onReaction: (reaction) => _handleReaction(_messages[index].id, reaction),
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

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
            ),
            child: OptimizedChatInput(
              controller: _messageController,
              onSend: _sendMessage,
              isLoading: _isLoading,
              hintText: 'Type your message...',
              onTap: () {
                // Scroll to bottom when keyboard opens
                Future.delayed(const Duration(milliseconds: 300), () {
                  _scrollToBottom();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReportContentScreen(
          chatType: 'Nautical Nyx - ${widget.personality}',
          sessionId: widget.sessionId,
          chatHistory: _messages,
        ),
      ),
    );
  }
}