import 'package:flutter/material.dart';
import 'package:farmcare/services/share_service.dart';

enum ShareType {
  post,
  message,
  channel,
}

class ShareButton extends StatelessWidget {
  final ShareType type;
  final String id;
  final String title;
  final String content;
  final String? description;
  final double? size;
  final Color? color;

  const ShareButton({
    Key? key,
    required this.type,
    required this.id,
    required this.title,
    required this.content,
    this.description,
    this.size,
    this.color,
  }) : super(key: key);

  Future<void> _handleShare(BuildContext context) async {
    try {
      final shareService = ShareService();

      switch (type) {
        case ShareType.post:
          await shareService.sharePost(id, title, content);
          break;
        case ShareType.message:
          await shareService.shareMessage(id, content);
          break;
        case ShareType.channel:
          await shareService.shareChannel(id, title, description ?? '');
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share ${type.toString().split('.').last}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.share,
        size: size ?? 20,
        color: color ?? Colors.green.shade800,
      ),
      onPressed: () => _handleShare(context),
    );
  }
}
