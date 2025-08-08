import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLoading;
  final Function(String reaction)? onReaction;
  final Color? userBubbleColor;

  const ChatBubble({
    super.key,
    required this.message,
    this.isLoading = false,
    this.onReaction,
    this.userBubbleColor,
  });

  void _showReactionDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Message Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy option for all messages
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            // Reaction options only for Nyx messages
            if (!message.isUser) ...[
              const Divider(),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                      onReaction?.call('heart');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.reaction == 'heart' 
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.reaction == 'heart' ? Icons.favorite : Icons.favorite_border,
                            size: 24,
                            color: message.reaction == 'heart' 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey[600],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Like',
                            style: TextStyle(
                              fontSize: 12,
                              color: message.reaction == 'heart' 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                      onReaction?.call('thumbs_down');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.reaction == 'thumbs_down' 
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.thumb_down,
                            size: 24,
                            color: message.reaction == 'thumbs_down' 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey[600],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dislike',
                            style: TextStyle(
                              fontSize: 12,
                              color: message.reaction == 'thumbs_down' 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/images/nyx_icon.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75, // Wider bubbles like iOS
                ),
                child: GestureDetector(
                  onLongPress: !isLoading ? () => _showReactionDialog(context) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: message.isUser 
                          ? (userBubbleColor ?? Theme.of(context).colorScheme.secondary)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(22), // Completely rounded for both user and Nyx
                      border: message.isUser 
                          ? null 
                          : Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                message.content,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: message.isUser 
                                  ? Colors.white 
                                  : Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Show existing reaction if present (on Nyx messages that were reacted to)
              if (message.reaction != null && !message.isUser) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    message.reaction == 'heart' ? Icons.favorite : Icons.thumb_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

}