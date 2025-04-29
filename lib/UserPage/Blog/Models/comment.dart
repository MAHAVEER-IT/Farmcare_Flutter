class Comment {
  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String content;
  final String createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    print('Parsing comment JSON: $json');

    // Handle different ID formats
    final String id = json['_id']?.toString() ??
        json['id']?.toString() ??
        json['commentId']?.toString() ??
        '';

    // Handle different date formats
    String createdAt = DateTime.now().toIso8601String();
    if (json['createdAt'] != null) {
      try {
        if (json['createdAt'] is String) {
          createdAt = json['createdAt'];
        } else if (json['createdAt'] is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
              .toIso8601String();
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
      }
    }

    return Comment(
      id: id,
      postId: json['postId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Anonymous',
      content: json['content']?.toString() ?? '',
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'Comment{id: $id, postId: $postId, userId: $userId, authorName: $authorName, content: $content, createdAt: $createdAt}';
  }
}
