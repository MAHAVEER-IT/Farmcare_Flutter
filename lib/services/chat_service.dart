import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatUser {
  final String id;
  final String name;
  final String profilePic;

  ChatUser({
    required this.id,
    required this.name,
    required this.profilePic,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      profilePic: json['profilePic'] ?? '',
    );
  }
}

class ChatMessage {
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['message'] ?? '',
      timestamp:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class ChatHistory {
  final ChatUser user;
  final ChatMessage? lastMessage;
  final int unreadCount;

  ChatHistory({
    required this.user,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    return ChatHistory(
      user: ChatUser.fromJson(json['user'] ?? {}),
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class ChatService {
  static const String baseUrl =
      'http://10.0.2.2:8000/api'; // Updated port to 8000
  static const String socketUrl =
      'http://10.0.2.2:8000'; // Updated port to 8000
  IO.Socket? socket;
  Function(Map<String, dynamic>)? onNewMessage;
  Function(List<String>)? onOnlineUsersUpdate;

  // Map to store mock messages between users
  final Map<String, List<Map<String, dynamic>>> _mockMessages = {};

  void connectSocket(String userId) {
    try {
      // Disconnect any existing socket first
      disconnectSocket();

      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'query': {'userId': userId},
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionAttempts': 5,
        'timeout': 5000,
      });

      socket!.onConnect((_) {
        print('Socket connected with userId: $userId');
      });

      socket!.on('newMessage', (data) {
        try {
          if (onNewMessage != null) {
            final message = Map<String, dynamic>.from(data);
            onNewMessage!(message);
          }
        } catch (e) {
          print('Error handling new message: $e');
        }
      });

      socket!.on('getOnlineUsers', (data) {
        try {
          if (onOnlineUsersUpdate != null && data is List) {
            onOnlineUsersUpdate!(List<String>.from(data));
          }
        } catch (e) {
          print('Error handling online users update: $e');
        }
      });

      socket!.onDisconnect((_) => print('Socket disconnected'));
      socket!.onError((err) => print('Socket error: $err'));
      socket!.onConnectError((err) => print('Socket connect error: $err'));
    } catch (e) {
      print('Error setting up socket connection: $e');
    }
  }

  void disconnectSocket() {
    try {
      if (socket != null) {
        socket!.disconnect();
        socket!.dispose();
        socket = null;
      }
    } catch (e) {
      print('Error disconnecting socket: $e');
      socket = null;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Not authenticated');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (e) {
      throw Exception('Error getting conversations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(
      String receiverId, String token) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/messages/$receiverId'), // Updated endpoint
        headers: headers,
      );

      print('Fetching messages - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }

      print('Failed to fetch messages, using mock data');
      return _getMockMessages(receiverId);
    } catch (e) {
      print('Error fetching messages: $e');
      return _getMockMessages(receiverId);
    }
  }

  Future<List<Map<String, dynamic>>> _getMockMessages(String receiverId) async {
    // Get the current user ID
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'user1';

    // Create a unique conversation ID (combination of both user IDs)
    final conversationId = [userId, receiverId]..sort();
    final convId = conversationId.join('_');

    // If no messages exist for this conversation, create some initial ones
    if (!_mockMessages.containsKey(convId)) {
      _mockMessages[convId] = [];

      // Add some initial messages if this is a doctor
      if (receiverId.startsWith('doc')) {
        final now = DateTime.now();

        // Format dates properly with leading zeros for consistent parsing
        final yesterday = now.subtract(Duration(days: 1));
        final yesterdayStr =
            "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}T${yesterday.hour.toString().padLeft(2, '0')}:${yesterday.minute.toString().padLeft(2, '0')}:00.000Z";

        _mockMessages[convId] = [
          {
            'senderId': receiverId,
            'receiverId': userId,
            'message': 'Hello! How can I help you today?',
            'createdAt': yesterdayStr,
          },
          {
            'senderId': userId,
            'receiverId': receiverId,
            'message': 'Hi doctor, I have some questions about my livestock.',
            'createdAt': yesterdayStr,
          },
          {
            'senderId': receiverId,
            'receiverId': userId,
            'message':
                'Sure, I\'d be happy to help. What specific concerns do you have?',
            'createdAt': yesterdayStr,
          },
        ];
      }
    }

    return _mockMessages[convId] ?? [];
  }

  Future<Map<String, dynamic>> sendMessage(
      String receiverId, String content, String token, String userId) async {
    try {
      final message = {
        'receiverId': receiverId,
        'message': content,
      };

      // Emit message through socket first
      if (socket != null && socket!.connected) {
        socket!.emit('sendMessage', message);
      }

      // Try HTTP endpoint as fallback
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: headers,
        body: json.encode(message),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        return await _storeMockMessage(receiverId, content, userId);
      }
    } catch (e) {
      print('Error sending message: $e');
      return await _storeMockMessage(receiverId, content, userId);
    }
  }

  Future<Map<String, dynamic>> _storeMockMessage(
      String receiverId, String content, String userId) async {
    // Create a unique conversation ID (combination of both user IDs)
    final conversationId = [userId, receiverId]..sort();
    final convId = conversationId.join('_');

    // Format date properly with leading zeros
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.000Z";

    // Create the message
    final message = {
      'senderId': userId,
      'receiverId': receiverId,
      'message': content,
      'createdAt': formattedDate,
    };

    // Initialize the conversation if it doesn't exist
    _mockMessages[convId] ??= [];

    // Add the message to the conversation
    _mockMessages[convId]!.add(message);

    // Simulate a delay to make it feel like a network request
    await Future.delayed(Duration(milliseconds: 300));

    // Notify listeners if socket is connected
    if (socket != null && socket!.connected) {
      socket!.emit('newMessage', message);
    }

    return message;
  }

  Future<bool> isServerReachable() async {
    try {
      print('Checking server connectivity at: $socketUrl');

      // First try the health endpoint
      try {
        final response = await http
            .get(Uri.parse('$socketUrl/health'))
            .timeout(Duration(seconds: 3));

        print('Server health check response: ${response.statusCode}');
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Health endpoint check failed: $e');
        // Continue to try the root endpoint
      }

      // If health endpoint fails, try the root endpoint
      try {
        final response =
            await http.get(Uri.parse(socketUrl)).timeout(Duration(seconds: 3));

        print('Server root endpoint response: ${response.statusCode}');
        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (e) {
        print('Root endpoint check failed: $e');
        return false;
      }
    } catch (e) {
      print('Server connectivity check failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    try {
      final headers = await _getHeaders();

      // Update the endpoint to match your backend API
      final response = await http
          .get(
            Uri.parse('$baseUrl/doctors'), // Updated endpoint
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print('Fetching doctors - Status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isEmpty) {
          print('No doctors found in database, returning mock data');
          return _getMockDoctors();
        }

        // Transform the data to match expected format
        return data.map<Map<String, dynamic>>((doctor) {
          return {
            '_id': doctor['_id'] ?? doctor['id'] ?? '',
            'name': doctor['name'] ?? '',
            'username': doctor['username'] ?? '',
            'email': doctor['email'] ?? '',
            'userType': doctor['userType'] ?? 'doctor',
            'location': doctor['location'] ?? '',
            'specialization': doctor['specialization'] ?? '',
            'experience': doctor['experience'] ?? '',
          };
        }).toList();
      }

      print('Failed to fetch doctors, status: ${response.statusCode}');
      return _getMockDoctors();
    } catch (e) {
      print('Error fetching doctors: $e');
      return _getMockDoctors();
    }
  }

  List<Map<String, dynamic>> _getMockDoctors() {
    // Return some mock data for testing
    return [
      {
        '_id': 'doc1',
        'name': 'Dr. Rajesh Kumar',
        'username': 'rajesh_vet',
        'email': 'rajesh@example.com',
        'userType': 'doctor',
        'location': 'Chennai, Tamil Nadu',
        'specialization': 'Livestock Health',
        'experience': '10 years'
      },
      {
        '_id': 'doc2',
        'name': 'Dr. Priya Singh',
        'username': 'priya_vet',
        'email': 'priya@example.com',
        'userType': 'doctor',
        'location': 'Coimbatore, Tamil Nadu',
        'specialization': 'Dairy Animals',
        'experience': '8 years'
      },
      {
        '_id': 'doc3',
        'name': 'Dr. Anand Sharma',
        'username': 'anand_vet',
        'email': 'anand@example.com',
        'userType': 'doctor',
        'location': 'Madurai, Tamil Nadu',
        'specialization': 'Poultry',
        'experience': '5 years'
      },
      {
        '_id': 'doc4',
        'name': 'Dr. Lakshmi Nair',
        'username': 'lakshmi_vet',
        'email': 'lakshmi@example.com',
        'userType': 'doctor',
        'location': 'Salem, Tamil Nadu',
        'specialization': 'General Veterinary',
        'experience': '12 years'
      },
    ];
  }

  Future<List<ChatHistory>> getChats(String token) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/chats'),
        headers: headers,
      );

      print('Fetching chats - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChatHistory.fromJson(json)).toList();
      }

      // Return empty list if API fails
      print('Failed to fetch chats, returning empty list');
      return [];
    } catch (e) {
      print('Error fetching chats: $e');
      return [];
    }
  }
}
