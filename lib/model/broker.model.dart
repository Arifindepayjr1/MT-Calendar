class Broker {
  final String id;
  final String name;
  String? website;
  final DateTime createdAt;

  Broker({
    required this.id,
    required this.name,
    this.website,
    required this.createdAt,
  });

  factory Broker.fromJson(Map<String, dynamic> json) {
    return Broker(
      id: json['id'] as String,
      name: json['name'] as String,
      website: json['website'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'website': website,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
