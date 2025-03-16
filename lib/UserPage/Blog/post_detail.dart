import 'package:flutter/material.dart';
import 'package:farmcare/UserPage/Blog/Blog_UI.dart';
import 'package:farmcare/UserPage/Blog/Widgets/comment_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Blog_services.dart';

class PostDetailPage extends StatefulWidget {
  final BlogPost post;

  const PostDetailPage({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final BlogService _blogService = BlogService();
  late BlogPost post;
  String? userId;

  @override
  void initState() {
    super.initState();
    post = widget.post;
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _handleLike() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to like posts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        if (post.likeUsers.contains(userId)) {
          post.likeUsers.remove(userId);
          post.likeCount--;
        } else {
          post.likeUsers.add(userId!);
          post.likeCount++;
        }
      });

      await _blogService.updateLike(post.postId, userId!);
    } catch (e) {
      // Revert on error
      setState(() {
        if (post.likeUsers.contains(userId)) {
          post.likeUsers.remove(userId);
          post.likeCount--;
        } else {
          post.likeUsers.add(userId!);
          post.likeCount++;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        title: const Text('Post Detail'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.images.isNotEmpty)
              Image.network(
                post.images.first,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error_outline),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(post.authorName.replaceAll(' ', '+'))}",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            post.createdAt.toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    post.content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          post.likeUsers.contains(userId)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: post.likeUsers.contains(userId)
                              ? Colors.red
                              : null,
                        ),
                        onPressed: _handleLike,
                      ),
                      Text('${post.likeCount}'),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.comment_outlined),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CommentDialog(
                              postId: post.postId,
                              onCommentAdded: () {
                                setState(() {
                                  post.commentCount++;
                                });
                              },
                            ),
                          );
                        },
                      ),
                      Text('${post.commentCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
