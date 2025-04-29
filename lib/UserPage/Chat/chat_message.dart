import 'package:flutter/material.dart';
import 'package:farmcare/services/share_service.dart';

class ChatMessage extends StatelessWidget {
  final String message;
  final String messageId;
  final bool isMe;
  final DateTime timestamp;

  const ChatMessage({
    Key? key,
    required this.message,
    required this.messageId,
    required this.isMe,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 64 : 16,
          right: isMe ? 16 : 64,
          top: 8,
          bottom: 8,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          children: [
            Text(
              message,
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
                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    try {
                      final shareService = ShareService();
                      await shareService.shareMessage(messageId, message);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to share message'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Icon(
                    Icons.share,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
