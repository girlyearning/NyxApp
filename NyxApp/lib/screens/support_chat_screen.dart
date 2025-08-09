import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/support_chat_service.dart';
import '../widgets/chat_bubble.dart';
import '../providers/user_provider.dart';

class SupportChatScreen extends StatefulWidget {
  final String sessionId;
  final String supportType;
  final String title;

  const SupportChatScreen({
    super.key,
    required this.sessionId,
    required this.supportType,
    required this.title,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  int _messagesBeingAdded = 0;
  double _previousKeyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSession();
  }

  @override
  void dispose() {
    // Dismiss keyboard when leaving screen
    FocusScope.of(context).unfocus();
    _createMemoryIfNeeded();
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final currentKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // If keyboard state changed, scroll to bottom with optimized timing
    if (currentKeyboardHeight != _previousKeyboardHeight) {
      _previousKeyboardHeight = currentKeyboardHeight;
      
      // Reduce delay and optimize for smoother transitions
      if (currentKeyboardHeight > 0) {
        // Keyboard is opening
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _scrollToBottom();
        });
      } else {
        // Keyboard is closing - immediate scroll
        if (mounted) _scrollToBottom();
      }
    }
  }
  
  Future<void> _handleReaction(String messageId, String reaction) async {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    setState(() {
      _messages[messageIndex] = _messages[messageIndex].copyWith(reaction: reaction);
    });

    await SupportChatService.updateMessageReaction(widget.sessionId, messageId, reaction);

    if (reaction == 'thumbs_down' && !_messages[messageIndex].isUser) {
      final reactedMessage = _messages[messageIndex];
      try {
        setState(() {
          _isLoading = true;
          _messagesBeingAdded++;
        });

        if (!mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final response = await SupportChatService.sendThumbsDownResponse(
          reactedMessage.content,
          widget.supportType,
          widget.sessionId,
          userId: userProvider.currentUserId,
        );

        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              content: response,
              isUser: false,
              timestamp: DateTime.now(),
            ));
            _messagesBeingAdded--;
            _isLoading = _messagesBeingAdded > 0;
          });
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messagesBeingAdded--;
            _isLoading = _messagesBeingAdded > 0;
          });
        }
      }
    }
  }

  Future<void> _createMemoryIfNeeded() async {
    if (_messages.length > 4) { // Only create memory if there's meaningful conversation
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await SupportChatService.createMemoryFromSession(
          widget.sessionId,
          userProvider.currentUserId,
        );
      } catch (e) {
        // Silently fail - don't interrupt user experience
      }
    }
  }

  Future<void> _loadSession() async {
    final messages = await SupportChatService.loadSession(widget.sessionId);
    
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
        await SupportChatService.saveSession(widget.sessionId, _messages);
      }
    }
    
    _scrollToBottom();
  }

  String _getWelcomeMessage() {
    switch (widget.supportType) {
      case 'crisis_support':
        return "I'm here with you right now, and you don't have to face this alone. What's weighing on you today?";
      case 'anxiety_support':
        return "Anxiety can feel so overwhelming, but we can work through this together. What's your anxiety telling you right now?";
      case 'depression_support':
        return "I see you, and I understand how heavy things can feel. What's been the hardest part lately?";
      case 'anger_management':
        return "Sounds like something really got under your skin. I'm here for it - what's got you fired up?";
      case 'recovery_support':
        return "Recovery is tough work, and I'm proud of you for being here. What's on your mind today in your journey?";
      case 'general_comfort':
        return "I'm here with you, honey. Whatever you're going through, you don't have to face it alone. What's on your heart today?";
      case 'introspection':
        return "Ready for some quality self-reflection? Let's dig into that psyche of yours with some actual insight.";
      case 'shadow_work':
        return "Time to meet the parts of yourself you've been avoiding. Don't worry, I've seen worse shadows than yours.";
      case 'values_clarification':
        return "Values aren't what you think you should want - they're what actually drives you. Let's figure out what yours really are.";
      case 'trauma_patterns':
        return "Childhood patterns run deep, but they're not permanent. Let's look at what you learned and what needs updating.";
      case 'attachment_styles':
        return "Attachment patterns shape everything. Let's figure out your relational blueprint and see what needs rewiring.";
      case 'existential_exploration':
        return "Ah, confronting the big questions, are we? Welcome to the human condition - it's messy, absurd, and somehow beautiful.";
      case 'rage_room':
        return "Oh, we're feeling some rage today? Fucking finally. Let's get this out properly instead of letting it eat you alive.";
      case 'confession_booth':
        return "Anonymous confessions, huh? I've heard everything, so don't hold back. What's weighing on you?";
      default:
        return "I'm here to support you through whatever you're experiencing. How can I help you today?";
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
      // Get AI response(s) through the service
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Track chat session (only for the first message)
      if (_messages.length == 1) { // Only user message exists at this point
        await userProvider.incrementChatSessions();
      }
      
      final aiResponses = await SupportChatService.sendMessage(
        widget.sessionId,
        text,
        widget.supportType,
        userId: userProvider.currentUserId,
      );

      if (mounted && aiResponses.isNotEmpty) {
        // Handle multiple messages with delays
        _messagesBeingAdded = aiResponses.length;
        
        for (int i = 0; i < aiResponses.length; i++) {
          // Add delay between messages for better UX
          if (i > 0) {
            await Future.delayed(const Duration(milliseconds: 500)); // Reduced delay
          }
          
          if (!mounted) break;
          
          final aiMessage = ChatMessage(
            content: aiResponses[i],
            isUser: false,
            timestamp: DateTime.now(),
          );

          setState(() {
            _messages.add(aiMessage);
            _messagesBeingAdded--;
          });
        }
        
        // Single scroll at the end instead of multiple
        _scrollToBottom();
        
        setState(() {
          _isLoading = false;
          _messagesBeingAdded = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messagesBeingAdded = 0;
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
    if (!_scrollController.hasClients || !mounted) return;
    
    // Use animateTo with shorter duration for smoother experience
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveForever() async {
    try {
      final success = await SupportChatService.saveChatForever(widget.sessionId);
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
      final newSessionId = await SupportChatService.createNewSession(widget.supportType);
      if (!mounted) return;
      
      // Navigate to new session
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SupportChatScreen(
            sessionId: newSessionId,
            supportType: widget.supportType,
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
        await SupportChatService.deleteSession(widget.sessionId);
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
        await SupportChatService.renameSession(widget.sessionId, newName);
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

  String _getLoadingText() {
    switch (widget.supportType) {
      case 'crisis_support':
        return 'Nyx is here with you...';
      case 'anxiety_support':
        return 'Nyx is understanding your anxiety...';
      case 'depression_support':
        return 'Nyx is holding space for you...';
      case 'anger_management':
        return 'Nyx is processing your anger...';
      case 'recovery_support':
        return 'Nyx is supporting your journey...';
      case 'general_comfort':
        return 'Nyx is sending comfort...';
      default:
        return 'Nyx is thinking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  reverse: false,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                  physics: const AlwaysScrollableScrollPhysics(),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  cacheExtent: 200.0,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ChatBubble(
                        key: ValueKey(_messages[index].id),
                        message: _messages[index],
                        isLoading: false,
                        onReaction: (reaction) => _handleReaction(_messages[index].id, reaction),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Loading indicator
            if (_isLoading || _messagesBeingAdded > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(width: 16),
                    Text(_getLoadingText()),
                    if (_messagesBeingAdded > 0)
                      Text(' ($_messagesBeingAdded more messages coming...)'),
                  ],
                ),
              ),

            // Message input
            Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 56,
                        maxHeight: 160,
                      ),
                      child: Scrollbar(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: null,
                          scrollPhysics: const BouncingScrollPhysics(),
                          textInputAction: TextInputAction.newline,
                          onSubmitted: (_) => _sendMessage(),
                          onTap: () {
                            // Scroll to bottom when keyboard opens
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _scrollToBottom();
                            });
                          },
                          enabled: !_isLoading && _messagesBeingAdded == 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: (_isLoading || _messagesBeingAdded > 0) ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}