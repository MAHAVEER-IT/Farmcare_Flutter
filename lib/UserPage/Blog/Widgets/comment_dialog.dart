import 'dart:async';

import 'package:flutter/material.dart';
import '../Models/comment.dart';
import '../Blog_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommentDialog extends StatefulWidget {
  final String postId;
  final Function onCommentAdded;

  const CommentDialog({
    Key? key,
    required this.postId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  _CommentDialogState createState() => _CommentDialogState();
}

class _CommentDialogState extends State<CommentDialog> {
  final _commentController = TextEditingController();
  final _blogService = BlogService();
  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Loading comments for post: ${widget.postId}');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('Please login to view comments');
      }

      final comments = await _blogService.getComments(widget.postId);

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _isLoading = false;
      });

      print('Successfully loaded ${comments.length} comments');
    } catch (e) {
      print('Error loading comments: $e');
      if (!mounted) return;

      String errorMessage;
      if (e is TimeoutException) {
        errorMessage =
            'Connection timed out. Please check your internet and try again.';
      } else if (e.toString().contains('Not authenticated') ||
          e.toString().contains('Please login')) {
        errorMessage = 'Please login to view comments';
      } else {
        errorMessage = 'Failed to load comments. Please try again.';
      }

      setState(() {
        _isLoading = false;
        _error = errorMessage;
      });

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (!errorMessage.contains('Please login')) {
                    _loadComments(); // Only retry if not a login error
                  }
                },
                child: Text(
                    errorMessage.contains('Please login') ? 'OK' : 'Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');

      if (userId == null || token == null) {
        throw Exception('Please login to comment');
      }

      print('Adding comment for post: ${widget.postId}');
      final newComment = await _blogService.addComment(
        widget.postId,
        userId,
        comment,
      );

      if (!mounted) return;

      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
        _isLoading = false;
      });

      widget.onCommentAdded();
      print('Comment added successfully');
    } catch (e) {
      print('Error adding comment: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);

      String errorMessage;
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('Please login')) {
        errorMessage = 'Please login to comment';
      } else {
        errorMessage = 'Failed to add comment. Please try again.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadComments,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _comments.isEmpty
                            ? const Center(child: Text('No comments yet'))
                            : ListView.builder(
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final comment = _comments[index];
                                  print(
                                      'Rendering comment: ${comment.content}'); // Debug log
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(comment.authorName.replaceAll(' ', '+'))}",
                                      ),
                                    ),
                                    title: Text(comment.authorName),
                                    subtitle: Text(comment.content),
                                    trailing: Text(
                                      _formatDate(comment.createdAt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _addComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
