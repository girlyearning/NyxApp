class JournalFolder {
  final String id;
  final String name;
  final DateTime createdAt;

  JournalFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory JournalFolder.fromJson(Map<String, dynamic> json) {
    return JournalFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}