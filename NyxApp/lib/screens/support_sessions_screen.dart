import 'package:flutter/material.dart';
import '../services/support_chat_service.dart';
import 'support_chat_screen.dart';

class SupportSessionsScreen extends StatefulWidget {
  final String supportType;
  final String title;

  const SupportSessionsScreen({
    super.key,
    required this.supportType,
    required this.title,
  });

  @override
  State<SupportSessionsScreen> createState() => _SupportSessionsScreenState();
}

class _SupportSessionsScreenState extends State<SupportSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    
    final sessions = await SupportChatService.getSessionsForSupportType(widget.supportType);
    
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _startNewChat() async {
    final sessionId = await SupportChatService.createNewSession(widget.supportType);
    
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupportChatScreen(
          sessionId: sessionId,
          supportType: widget.supportType,
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
        builder: (context) => SupportChatScreen(
          sessionId: sessionId,
          supportType: widget.supportType,
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
      await SupportChatService.deleteSession(sessionId);
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
        await SupportChatService.renameSession(session['sessionId'], newName);
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
                    label: const Text('Start a New Support Session'),
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
                                Icons.favorite_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No support sessions yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start a new session when you need support',
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
                                  session['title'] ?? 'Untitled Session',
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
                                  backgroundColor: _getSupportColor(widget.supportType),
                                  child: Icon(
                                    _getSupportIcon(widget.supportType),
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

  IconData _getSupportIcon(String supportType) {
    switch (supportType) {
      case 'crisis_support':
        return Icons.emergency;
      case 'anxiety_support':
        return Icons.psychology_alt;
      case 'depression_support':
        return Icons.healing;
      case 'anger_management':
        return Icons.sentiment_very_dissatisfied;
      case 'recovery_support':
        return Icons.trending_up;
      case 'general_comfort':
        return Icons.favorite;
      case 'introspection':
        return Icons.self_improvement;
      case 'shadow_work':
        return Icons.dark_mode;
      case 'values_clarification':
        return Icons.compass_calibration;
      case 'trauma_patterns':
        return Icons.healing;
      case 'attachment_styles':
        return Icons.link;
      case 'existential_exploration':
        return Icons.psychology;
      case 'rage_room':
        return Icons.sports_mma;
      case 'mental_space':
        return Icons.spa;
      case 'confession_booth':
        return Icons.lock_open;
      default:
        return Icons.support_agent;
    }
  }

  Color _getSupportColor(String supportType) {
    switch (supportType) {
      case 'crisis_support':
        return Colors.red[700]!;
      case 'anxiety_support':
        return Colors.orange[700]!;
      case 'depression_support':
        return Colors.blue[700]!;
      case 'anger_management':
        return Colors.deepOrange[700]!;
      case 'recovery_support':
        return Colors.green[700]!;
      case 'general_comfort':
        return Colors.pink[600]!;
      case 'introspection':
        return Colors.purple[600]!;
      case 'shadow_work':
        return Colors.grey[800]!;
      case 'values_clarification':
        return Colors.indigo[600]!;
      case 'trauma_patterns':
        return Colors.teal[600]!;
      case 'attachment_styles':
        return Colors.cyan[600]!;
      case 'existential_exploration':
        return Colors.deepPurple[600]!;
      case 'rage_room':
        return Colors.red[800]!;
      case 'mental_space':
        return Colors.lightGreen[600]!;
      case 'confession_booth':
        return Colors.blueGrey[600]!;
      default:
        return Colors.blue[600]!;
    }
  }
}