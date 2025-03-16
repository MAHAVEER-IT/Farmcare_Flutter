import 'dart:async';

import 'package:farmcare/services/chat_service.dart';
import 'package:farmcare/utils/app_localizations.dart';
import 'package:farmcare/utils/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String currentUserId;
  final String token;

  const ChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.currentUserId,
    required this.token,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  String? _userId;
  List<String> _onlineUsers = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _userId = widget.currentUserId;
    });

    await _loadMessages();
    _setupSocketListeners();

    // Connect to socket with user ID
    _chatService.connectSocket(_userId!);
  }

  void _setupSocketListeners() {
    _chatService.onNewMessage = (message) {
      if (mounted) {
        // Check if message belongs to this chat
        if (message['senderId'] == widget.receiverId ||
            message['receiverId'] == widget.receiverId) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
        }
      }
    };

    _chatService.onOnlineUsersUpdate = (onlineUsers) {
      if (mounted) {
        setState(() {
          _onlineUsers = onlineUsers;
        });
      }
    };
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final messages =
          await _chatService.getMessages(widget.receiverId, widget.token);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        if (_messages.isNotEmpty) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text;
    _messageController.clear();

    try {
      final tempMessage = {
        'message': message,
        'senderId': _userId,
        'receiverId': widget.receiverId,
        'createdAt': DateTime.now().toIso8601String(),
      };

      setState(() {
        _messages.add(tempMessage);
      });
      _scrollToBottom();

      await _chatService.sendMessage(
        widget.receiverId,
        message,
        widget.token,
        widget.currentUserId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool isUserOnline() {
    return _onlineUsers.contains(widget.receiverId);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isUserOnline() ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  isUserOnline()
                      ? AppLocalizations.translate('online', currentLanguage)
                      : AppLocalizations.translate('offline', currentLanguage),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.green.shade50,
        ),
        child: Column(
          children: [
            Expanded(
              child: _buildMessageList(currentLanguage),
            ),
            _buildMessageInput(currentLanguage),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(String currentLanguage) {
    if (_isLoading && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade800),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.translate('loading', currentLanguage),
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(_error!),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMessages,
              icon: Icon(Icons.refresh),
              label: Text(
                AppLocalizations.translate('retry', currentLanguage),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.translate('noMessages', currentLanguage),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Group messages by date
    final groupedMessages = <String, List<Map<String, dynamic>>>{};

    for (final message in _messages) {
      try {
        final dateTimeStr = message['createdAt'].toString();
        DateTime dateTime;

        try {
          dateTime = DateTime.parse(dateTimeStr);
        } catch (e) {
          // Fallback if parsing fails
          print('Error parsing message date: $dateTimeStr, error: $e');
          dateTime = DateTime.now();
        }

        // Use only the date part for grouping
        final date = '${dateTime.year}-${dateTime.month}-${dateTime.day}';

        if (!groupedMessages.containsKey(date)) {
          groupedMessages[date] = [];
        }

        groupedMessages[date]!.add(message);
      } catch (e) {
        print('Error processing message: $message, error: $e');
        // Skip this message if there's an error
      }
    }

    // Sort dates
    final sortedDates = groupedMessages.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final messages = groupedMessages[date]!;

        return Column(
          children: [
            _buildDateDivider(date),
            ...messages.map((message) => _buildMessageBubble(message)),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(String date) {
    final now = DateTime.now();
    DateTime messageDate;

    try {
      // Ensure proper date format with padding
      final parts = date.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        messageDate = DateTime(year, month, day);
      } else {
        // Fallback if date format is unexpected
        messageDate = now;
      }
    } catch (e) {
      print('Error parsing date: $date, error: $e');
      // Fallback to current date if parsing fails
      messageDate = now;
    }

    String dateText;
    if (messageDate.year == now.year &&
        messageDate.month == now.month &&
        messageDate.day == now.day) {
      dateText = 'Today';
    } else if (messageDate.year == now.year &&
        messageDate.month == now.month &&
        messageDate.day == now.day - 1) {
      dateText = 'Yesterday';
    } else {
      dateText =
          '${messageDate.day.toString().padLeft(2, '0')}/${messageDate.month.toString().padLeft(2, '0')}/${messageDate.year}';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == _userId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isMe ? 64 : 0,
          right: isMe ? 0 : 64,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade800 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 16 : 4),
            topRight: Radius.circular(isMe ? 4 : 16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['message'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['createdAt']),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp.toString());
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting time: $timestamp, error: $e');
      // Return current time as fallback
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageInput(String currentLanguage) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: AppLocalizations.translate(
                  'typeMessage',
                  currentLanguage,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                prefixIcon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: Colors.grey.shade600,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.disconnectSocket();
    super.dispose();
  }
}
