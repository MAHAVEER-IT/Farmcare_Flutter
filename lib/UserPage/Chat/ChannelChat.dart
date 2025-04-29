import 'package:flutter/material.dart';
import 'package:farmcare/widgets/share_button.dart';
import 'package:farmcare/models/message.dart';
import 'package:farmcare/models/channel.dart';
import 'package:farmcare/utils/time_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChannelChatScreen extends StatefulWidget {
  final Channel channel;

  const ChannelChatScreen({
    Key? key,
    required this.channel,
  }) : super(key: key);

  @override
  _ChannelChatScreenState createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  List<Message> messages = [];
  bool isLoading = false;
  String? userId;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadMessages();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      isLoading = true;
    });

    try {
      // TODO: Implement message loading from your backend service
      // For now, using dummy data
      setState(() {
        messages = [
          Message(
            id: '1',
            senderId: 'user1',
            content: 'Hello everyone!',
            timestamp: DateTime.now().subtract(Duration(minutes: 5)),
          ),
          Message(
            id: '2',
            senderId: userId ?? '',
            content: 'Hi there!',
            timestamp: DateTime.now(),
          ),
        ];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final newMessage = Message(
        id: DateTime.now().toString(), // Replace with actual ID from backend
        senderId: userId ?? '',
        content: _messageController.text.trim(),
        timestamp: DateTime.now(),
      );

      setState(() {
        messages.add(newMessage);
        _messageController.clear();
      });

      // TODO: Implement actual message sending to your backend
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.name),
        backgroundColor: Colors.green.shade800,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessage(messages[index]),
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessage(Message message) {
    final isMe = message.senderId == userId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TimeFormatter.format(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 8),
                ShareButton(
                  type: ShareType.message,
                  id: message.id,
                  title: '',
                  content: message.content,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send),
            color: Colors.green.shade800,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
