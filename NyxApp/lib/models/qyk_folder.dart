class QykFolder {
  final String id;
  final String name;
  final DateTime createdAt;

  QykFolder({
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

  factory QykFolder.fromJson(Map<String, dynamic> json) {
    return QykFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QykFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}