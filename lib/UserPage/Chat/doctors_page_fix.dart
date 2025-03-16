import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/channel_service.dart';
import '../../services/doctor_service.dart' as doc_service;
import '../../services/chat_service.dart' as chat_service;
import 'channel_screen.dart';
import 'chat_screen.dart';

// This is a helper function to fix the _openChat method
void openChat(
    BuildContext context, dynamic user, String currentUserId, String token) {
  // Extract the user ID and validate it
  String receiverId = '';
  String receiverName = 'Unknown User';

  if (user is doc_service.Doctor) {
    receiverId = user.id;
    receiverName = user.name;
  } else if (user != null) {
    receiverId = user.id ?? '';
    receiverName = user.name ?? 'Unknown User';
  }

  print(
      'Opening chat with receiverId: $receiverId, receiverName: $receiverName');

  // Validate that we have a non-empty receiverId
  if (receiverId.isEmpty) {
    print('ERROR: Attempted to open chat with empty receiverId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot open chat: Invalid user ID')),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChatScreen(
        receiverId: receiverId,
        receiverName: receiverName,
        currentUserId: currentUserId,
        token: token,
      ),
    ),
  );
}
