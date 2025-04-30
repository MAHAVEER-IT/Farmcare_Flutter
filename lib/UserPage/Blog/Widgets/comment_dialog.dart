import 'dart:async';
import 'package:flutter/material.dart';
import '../Models/comment.dart';
import '../Blog_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final Function onCommentAdded;

  const CommentBottomSheet({
    Key? key,
    required this.postId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  _CommentBottomSheetState createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _commentController = TextEditingController();
  final _blogService = BlogService();
  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _error;
  String? _replyingToId; // ID of the comment being replied to
  String _replyingToAuthor = ''; // Author name of the comment being replied to

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  void _showReplyField(Comment comment) {
    setState(() {
      _replyingToId = comment.id;
      _replyingToAuthor = comment.authorName;
      _commentController.text = '';
    });
    // Focus the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToAuthor = '';
      _commentController.text = '';
    });
  }

  Future<void> _submitReply() async {
    if (_replyingToId == null) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final reply = await _blogService.addReply(_replyingToId!, content);

      if (!mounted) return;

      // Find the parent comment and add the reply
      setState(() {
        final parentIndex = _comments.indexWhere((c) => c.id == _replyingToId);
        if (parentIndex != -1) {
          final updatedComment = Comment(
            id: _comments[parentIndex].id,
            postId: _comments[parentIndex].postId,
            userId: _comments[parentIndex].userId,
            authorName: _comments[parentIndex].authorName,
            content: _comments[parentIndex].content,
            createdAt: _comments[parentIndex].createdAt,
            replies: [..._comments[parentIndex].replies, reply],
            replyCount: _comments[parentIndex].replyCount + 1,
            likes: _comments[parentIndex].likes,
            likeCount: _comments[parentIndex].likeCount,
          );
          _comments[parentIndex] = updatedComment;
        }
        _commentController.clear();
        _replyingToId = null;
        _replyingToAuthor = '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error adding reply: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add reply. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildReplyBar() {
    if (_replyingToId == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Replying to ${_replyingToAuthor}',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: _cancelReply,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(
                        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(comment.authorName.replaceAll(' ', '+'))}",
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.authorName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(comment.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(comment.content),
                SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.reply, size: 16),
                      label: Text('Reply'),
                      onPressed: () => _showReplyField(comment),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Replies section
          if (comment.replies.isNotEmpty)
            Container(
              margin: EdgeInsets.only(left: 32),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.grey[300]!,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: comment.replies.map((reply) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(
                                "https://ui-avatars.com/api/?name=${Uri.encodeComponent(reply.authorName.replaceAll(' ', '+'))}",
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reply.authorName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(reply.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          reply.content,
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadComments,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(child: Text('No comments yet'))
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) =>
                                _buildCommentItem(_comments[index]),
                          ),
          ),
          _buildReplyBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _replyingToId == null
                          ? 'Add a comment...'
                          : 'Add your reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_replyingToId != null) {
                            _submitReply();
                          } else {
                            _addComment();
                          }
                        },
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }
}
