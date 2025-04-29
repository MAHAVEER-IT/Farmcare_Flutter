class Channel {
  final String id;
  final String name;
  final String? description;
  final List<String> members;

  Channel({
    required this.id,
    required this.name,
    this.description,
    required this.members,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      members: List<String>.from(json['members'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'members': members,
    };
  }
}
