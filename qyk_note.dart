class QykNote {
  final String id;
  final String content;
  final DateTime createdAt;
  final String? folderId;

  QykNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.folderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'folderId': folderId,
    };
  }

  factory QykNote.fromJson(Map<String, dynamic> json) {
    return QykNote(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      folderId: json['folderId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QykNote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}