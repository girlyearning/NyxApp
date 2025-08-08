class JournalEntry {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime lastModified;
  final bool isPermanent;
  final String? folderId;

  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.lastModified,
    this.isPermanent = true,  // Changed to permanent by default
    this.folderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'isPermanent': isPermanent,
      'folderId': folderId,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      lastModified: DateTime.parse(json['lastModified']),
      isPermanent: json['isPermanent'] ?? true,  // Default to permanent for existing entries
      folderId: json['folderId'] as String?,
    );
  }

  JournalEntry copyWith({
    String? title,
    String? content,
    DateTime? lastModified,
    bool? isPermanent,
    String? folderId,
  }) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      lastModified: lastModified ?? this.lastModified,
      isPermanent: isPermanent ?? this.isPermanent,
      folderId: folderId ?? this.folderId,
    );
  }
}