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
  // Extract the doctor ID and validate it
  String doctorId = '';
  String doctorName = 'Unknown Doctor';

  if (user is doc_service.Doctor) {
    doctorId = user.id;
    doctorName = user.name;
  } else if (user != null) {
    doctorId = user.id ?? '';
    doctorName = user.name ?? 'Unknown Doctor';
  }

  print('Opening chat with doctorId: $doctorId, doctorName: $doctorName');

  // Validate that we have a non-empty doctorId
  if (doctorId.isEmpty) {
    print('ERROR: Attempted to open chat with empty doctorId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot open chat: Invalid doctor ID')),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChatScreen(
        doctorId: doctorId,
        doctorName: doctorName,
        currentUserId: currentUserId,
        token: token,
      ),
    ),
  );
}
