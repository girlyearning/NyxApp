import 'package:flutter/material.dart';
import '../services/nautical_nyx_service.dart';
import 'nautical_chat_screen.dart';

class NauticalSessionsScreen extends StatefulWidget {
  final String personality;
  final String title;

  const NauticalSessionsScreen({
    super.key,
    required this.personality,
    required this.title,
  });

  @override
  State<NauticalSessionsScreen> createState() => _NauticalSessionsScreenState();
}

class _NauticalSessionsScreenState extends State<NauticalSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    final sessions = await NauticalNyxService.getSessionsForPersonality(widget.personality);
    
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _startNewChat() async {
    final sessionId = await NauticalNyxService.createNewSession(widget.personality);
    
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NauticalChatScreen(
          sessionId: sessionId,
          personality: widget.personality,
          title: widget.title,
        ),
      ),
    );
    
    // Refresh sessions when returning
    _loadSessions();
  }

  Future<void> _openExistingChat(String sessionId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NauticalChatScreen(
          sessionId: sessionId,
          personality: widget.personality,
          title: widget.title,
        ),
      ),
    );
    
    // Refresh sessions when returning
    _loadSessions();
  }

  Future<void> _deleteSession(String sessionId) async {
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
      await NauticalNyxService.deleteSession(sessionId);
      _loadSessions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    }
  }

  Future<void> _renameSession(Map<String, dynamic> session) async {
    final TextEditingController controller = TextEditingController(
      text: session['title'] ?? 'Untitled Chat',
    );
    
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
        await NauticalNyxService.renameSession(session['sessionId'], newName);
        _loadSessions();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat renamed to "$newName"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error renaming chat. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatTimestamp(String isoString) {
    final dateTime = DateTime.parse(isoString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today at $displayHour:${minute.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Start New Chat Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _startNewChat,
                    icon: const Icon(Icons.add),
                    label: const Text('Start a New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                // Sessions List
                Expanded(
                  child: _sessions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No chat sessions yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start a new chat to begin!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  session['title'] ?? 'Untitled Chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatTimestamp(session['lastUpdated']),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    if ((session['messageCount'] ?? 0) > 0)
                                      Text(
                                        '${session['messageCount']} messages',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(
                                    _getPersonalityIcon(widget.personality),
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'delete':
                                        _deleteSession(session['sessionId']);
                                        break;
                                      case 'rename':
                                        _renameSession(session);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Rename'),
                                        dense: true,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete, color: Colors.red),
                                        title: Text('Delete'),
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _openExistingChat(session['sessionId']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  IconData _getPersonalityIcon(String personality) {
    switch (personality) {
      case 'default':
        return Icons.person;
      case 'ride_or_die':
        return Icons.favorite;
      case 'dream_analyst':
        return Icons.psychology;
      case 'debate_master':
        return Icons.gavel;
      case 'adhd_nyx':
        return Icons.flash_on;
      case 'autistic_nyx':
        return Icons.grid_view;
      case 'autistic_adhd':
        return Icons.auto_awesome;
      default:
        return Icons.chat;
    }
  }
}