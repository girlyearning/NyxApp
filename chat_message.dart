class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? reaction; // 'heart' or 'thumbs_down'
  final String id; // Unique identifier for the message
  final bool isTimestamp; // Whether this is a timestamp separator message

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.reaction,
    this.isTimestamp = false,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'reaction': reaction,
      'isTimestamp': isTimestamp,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      reaction: json['reaction'],
      isTimestamp: json['isTimestamp'] ?? false,
    );
  }
  
  ChatMessage copyWith({String? reaction}) {
    return ChatMessage(
      id: id,
      content: content,
      isUser: isUser,
      timestamp: timestamp,
      reaction: reaction,
      isTimestamp: isTimestamp,
    );
  }
}