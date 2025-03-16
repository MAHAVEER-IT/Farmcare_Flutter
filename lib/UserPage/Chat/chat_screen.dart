import 'dart:async';
import 'dart:convert';

import 'package:farmcare/services/chat_service.dart';
import 'package:farmcare/utils/app_localizations.dart';
import 'package:farmcare/utils/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

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
  List<String> _onlineUsers = [];
  final Set<String> _processedMessageIds = {};
  late IO.Socket socket;
  bool _isConnected = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _loadMessages();

    // Set up periodic connection check
    Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) {
        if (!_isConnected) {
          print('Periodic reconnection check - reconnecting socket');
          socket.connect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _initSocket() {
    try {
      print('========== INITIALIZING SOCKET ==========');
      print('Initializing socket for userId: ${widget.currentUserId}');

      // Initialize socket with proper options
      socket =
          IO.io('https://farmcare-backend-new.onrender.com', <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'forceNew': true,
        'query': {
          'userId': widget.currentUserId,
          'token': widget.token,
          'chatWith': widget.receiverId
        },
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionAttempts': 10,
        'timeout': 10000,
      });

      socket.onConnect((_) {
        print('Socket connected successfully');
        setState(() => _isConnected = true);

        // Join rooms for this chat
        _joinChatRooms();

        // Also connect the ChatService socket to ensure both are connected
        _chatService.connectSocket(widget.currentUserId);

        // Request server to send any pending messages
        socket.emit('request_pending_messages',
            {'userId': widget.currentUserId, 'receiverId': widget.receiverId});

        // Notify server about active chat
        socket.emit('active_chat',
            {'userId': widget.currentUserId, 'receiverId': widget.receiverId});
      });

      socket.onDisconnect((_) {
        print('Socket disconnected');
        setState(() => _isConnected = false);
      });

      socket
          .onConnectError((error) => print('Socket connection error: $error'));
      socket.onError((error) => print('Socket error: $error'));

      // Listen for all possible message events
      _setupSocketListeners();

      // Connect the socket
      print('Connecting socket...');
      socket.connect();

      // Start periodic connection check
      _startSocketCheck();

      print('========== FINISHED INITIALIZING SOCKET ==========');
    } catch (e) {
      print('Error initializing socket: $e');
      print(e.toString());
    }
  }

  void _joinChatRooms() {
    try {
      print('========== JOINING CHAT ROOMS ==========');

      // Join user's own room
      print('Joining own room: ${widget.currentUserId}');
      socket.emit('join', {'userId': widget.currentUserId});
      socket.emit('join', widget.currentUserId);

      // Join receiver's room
      print('Joining receiver room: ${widget.receiverId}');
      socket.emit('join', {'userId': widget.receiverId});
      socket.emit('join', widget.receiverId);

      // Create room IDs for different formats
      final directRoom = '${widget.currentUserId}-${widget.receiverId}';
      final reverseRoom = '${widget.receiverId}-${widget.currentUserId}';
      final combinedRoom = [widget.currentUserId, widget.receiverId]..sort();
      final sortedRoom = combinedRoom.join('-');

      // Also create underscore versions
      final directRoomUnderscore = directRoom.replaceAll('-', '_');
      final reverseRoomUnderscore = reverseRoom.replaceAll('-', '_');
      final sortedRoomUnderscore = sortedRoom.replaceAll('-', '_');

      // Join direct room
      print('Joining direct room: $directRoom');
      socket.emit('join_room', {'room': directRoom});
      socket.emit('join_chat', {'room': directRoom});
      socket.emit('join_chat', directRoom);
      socket.emit('join', directRoom);

      // Join reverse room
      print('Joining reverse room: $reverseRoom');
      socket.emit('join_room', {'room': reverseRoom});
      socket.emit('join_chat', {'room': reverseRoom});
      socket.emit('join_chat', reverseRoom);
      socket.emit('join', reverseRoom);

      // Join sorted room
      print('Joining sorted room: $sortedRoom');
      socket.emit('join_room', {'room': sortedRoom});
      socket.emit('join_chat', {'room': sortedRoom});
      socket.emit('join_chat', sortedRoom);
      socket.emit('join', sortedRoom);

      // Join underscore versions
      print('Joining underscore rooms');
      socket.emit('join_room', {'room': directRoomUnderscore});
      socket.emit('join_room', {'room': reverseRoomUnderscore});
      socket.emit('join_room', {'room': sortedRoomUnderscore});
      socket.emit('join', directRoomUnderscore);
      socket.emit('join', reverseRoomUnderscore);
      socket.emit('join', sortedRoomUnderscore);

      // Join private chat room
      print('Joining private chat room');
      socket.emit('join_private_chat',
          {'userId': widget.currentUserId, 'receiverId': widget.receiverId});

      // Request acknowledgment
      socket.emit('check_rooms', (rooms) {
        print('Rooms joined: $rooms');
      });

      print('========== FINISHED JOINING CHAT ROOMS ==========');
    } catch (e) {
      print('Error joining chat rooms: $e');
      print(e.toString());
    }
  }

  void _setupSocketListeners() {
    try {
      print('========== SETTING UP SOCKET LISTENERS ==========');

      // Listen for all possible message event names
      socket.on('receive_message', (data) {
        print('Received receive_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('newMessage', (data) {
        print('Received newMessage event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('message', (data) {
        print('Received message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('private_message', (data) {
        print('Received private_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('direct_message', (data) {
        print('Received direct_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('room_message', (data) {
        print('Received room_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('chat_message', (data) {
        print('Received chat_message event: $data');
        _handleIncomingMessage(data);
      });

      // Listen for online users updates
      socket.on('getOnlineUsers', (data) {
        print('Received online users update: $data');
        if (mounted && data is List) {
          setState(() {
            _onlineUsers = List<String>.from(data);
          });
        }
      });

      print('========== FINISHED SETTING UP SOCKET LISTENERS ==========');
    } catch (e) {
      print('Error setting up socket listeners: $e');
      print(e.toString());
    }
  }

  void _handleIncomingMessage(dynamic data) {
    try {
      print('========== HANDLING INCOMING MESSAGE ==========');
      print('Received message data type: ${data.runtimeType}');
      print('Received message data: $data');

      Map<String, dynamic> message;

      // Handle different message formats
      if (data is Map) {
        message = Map<String, dynamic>.from(data);
        print('Message is a Map, converted to: $message');
      } else if (data is String) {
        // Try to parse string as JSON
        try {
          message = json.decode(data);
          print('Message is a String, parsed JSON: $message');
        } catch (e) {
          print('Error parsing string message: $e');
          message = {
            'content': data,
            'timestamp': DateTime.now().toIso8601String(),
            'senderId': widget.receiverId, // Assume it's from the receiver
            'receiverId': widget.currentUserId, // Assume it's to the sender
          };
          print('Created fallback message: $message');
        }
      } else {
        print('Unhandled message format: ${data.runtimeType}');
        print('========== END HANDLING INCOMING MESSAGE (ERROR) ==========');
        return;
      }

      // Check if this is a private message wrapper
      if (message.containsKey('message') && message['message'] is Map) {
        print('Unwrapping nested message from: $message');
        message = Map<String, dynamic>.from(message['message']);
        print('Unwrapped to: $message');
      }

      // Check if this is a room message
      if (message.containsKey('room') &&
          message.containsKey('message') &&
          message['message'] is Map) {
        print('Unwrapping room message from: $message');
        message = Map<String, dynamic>.from(message['message']);
        print('Unwrapped room message to: $message');
      }

      // Check if this is a 'to/from' format
      if (message.containsKey('to') && message.containsKey('from')) {
        print('Found to/from format message: $message');
        // Create a standard format message
        final content = message['content'] ?? message['message'] ?? '';
        final timestamp =
            message['timestamp'] ?? DateTime.now().toIso8601String();
        message = {
          'senderId': message['from'],
          'receiverId': message['to'],
          'content': content,
          'timestamp': timestamp,
        };
        print('Converted to standard format: $message');
      }

      // Ensure we have sender and receiver IDs
      final senderId = message['senderId'] ?? '';
      final receiverId = message['receiverId'] ?? '';

      print('Message senderId: $senderId, receiverId: $receiverId');
      print(
          'Current chat: currentUserId: ${widget.currentUserId}, receiverId: ${widget.receiverId}');

      // Check if this message is for the current chat
      bool isForCurrentChat = false;

      // Check if the message is between the current sender and receiver
      if ((senderId == widget.receiverId &&
              receiverId == widget.currentUserId) ||
          (senderId == widget.currentUserId &&
              receiverId == widget.receiverId)) {
        isForCurrentChat = true;
        print('Message is for current chat');
      } else {
        print('Message is NOT for current chat, ignoring');
        print('Sender ID match: ${senderId == widget.receiverId}');
        print('Receiver ID match: ${receiverId == widget.currentUserId}');
        print('Reverse sender match: ${senderId == widget.currentUserId}');
        print('Reverse receiver match: ${receiverId == widget.receiverId}');
        print('========== END HANDLING INCOMING MESSAGE (IGNORED) ==========');
        return;
      }

      // Check for content
      final content = message['content'] ?? message['message'] ?? '';
      if (content.isEmpty) {
        print('Message has no content, ignoring');
        print(
            '========== END HANDLING INCOMING MESSAGE (NO CONTENT) ==========');
        return;
      }
      print('Message content: $content');

      // Ensure the message has an ID to prevent duplicates
      if (!message.containsKey('_id')) {
        message['_id'] =
            '${message['senderId'] ?? ''}_${message['content'] ?? message['message'] ?? ''}_${DateTime.now().millisecondsSinceEpoch}';
        print('Generated message ID: ${message['_id']}');
      }

      // Check if we've already processed this message
      final messageId = message['_id'];
      if (_processedMessageIds.contains(messageId)) {
        print('Message with ID $messageId already processed, ignoring');
        print(
            '========== END HANDLING INCOMING MESSAGE (DUPLICATE) ==========');
        return;
      }

      // Add to processed IDs to prevent duplicates
      _processedMessageIds.add(messageId);
      print('Added message ID to processed list: $messageId');

      // Add the message to the UI
      setState(() {
        _messages.add(message);
        print(
            'Added message to UI: ${message['content'] ?? message['message']}');

        // If this was a message we were sending, mark sending as complete
        if (senderId == widget.currentUserId) {
          _isSending = false;
        }
      });

      // Scroll to the bottom
      _scrollToBottom();
      print('Scrolled to bottom after adding message');

      print('========== END HANDLING INCOMING MESSAGE ==========');
    } catch (e) {
      print('Error handling incoming message: $e');
      print(e.toString());
      print('========== END HANDLING INCOMING MESSAGE (ERROR) ==========');
    }
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
          // Process each message and add to the processed IDs set
          _messages = [];
          _processedMessageIds.clear();

          for (final message in messages) {
            final messageId = message['_id'] ??
                '${message['senderId']}_${message['content'] ?? message['message']}_${message['timestamp'] ?? message['createdAt']}';
            _processedMessageIds.add(messageId);
            _messages.add(message);
          }

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

  void _startSocketCheck() {
    // Check both sockets every 5 seconds
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _checkSocketConnections();
    });
  }

  void _checkSocketConnections() {
    // Check direct socket
    if (!socket.connected) {
      print('Direct socket disconnected, reconnecting...');
      socket.connect();
    }

    // Check ChatService socket
    if (_chatService.socket == null || !_chatService.socket!.connected) {
      print('ChatService socket disconnected, reconnecting...');
      _chatService.connectSocket(widget.currentUserId);
    }
  }

  Future<void> _sendMessage() async {
    try {
      print('========== SENDING MESSAGE ==========');

      // Get the message content
      final messageContent = _messageController.text.trim();

      // Check if the message is empty
      if (messageContent.isEmpty) {
        print('Message is empty, not sending');
        print('========== FINISHED SENDING MESSAGE (EMPTY) ==========');
        return;
      }

      print('Sending message: $messageContent');
      print('From: ${widget.currentUserId} to: ${widget.receiverId}');

      // Clear the text field
      _messageController.clear();

      // Check socket connections before sending
      _checkSocketConnections();

      // Show reconnection message if socket is not connected
      if (!_isConnected) {
        print('Socket not connected, showing reconnection message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Connection lost. Trying to reconnect...')),
        );
        socket.connect();
        _chatService.connectSocket(widget.currentUserId);

        // Wait a moment for connection to establish
        await Future.delayed(Duration(milliseconds: 300));
      }

      // Create a temporary message ID
      final tempMessageId =
          '${widget.currentUserId}_${messageContent}_${DateTime.now().millisecondsSinceEpoch}';

      // Create a message object
      final message = {
        '_id': tempMessageId,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'content': messageContent,
        'timestamp': DateTime.now().toIso8601String(),
        'isSending': true, // Mark as sending for UI
      };

      print('Created message object: $message');

      // Add the message to the UI immediately
      setState(() {
        _messages.add(message);
        _processedMessageIds.add(tempMessageId);
        _isSending = true;
      });

      // Scroll to the bottom
      _scrollToBottom();
      print('Added message to UI and scrolled to bottom');

      // Try joining the room again before sending
      _joinChatRooms();

      // Try multiple message formats to ensure delivery
      print('Emitting message through socket with multiple formats');

      // Format 1: Basic message
      socket.emit('send_message', message);
      print('Emitted with send_message event');

      // Format 2: Alternative event name
      socket.emit('sendMessage', message);
      print('Emitted with sendMessage event');

      // Format 3: Generic message event
      socket.emit('message', message);
      print('Emitted with message event');

      // Format 4: Private message format
      socket.emit(
          'private_message', {'to': widget.receiverId, 'message': message});
      print('Emitted with private_message event');

      // Format 5: Direct message format
      socket.emit('direct_message', {
        'to': widget.receiverId,
        'from': widget.currentUserId,
        'message': message
      });
      print('Emitted with direct_message event');

      // Format 6: Room message format
      final directRoom = '${widget.currentUserId}-${widget.receiverId}';
      final reverseRoom = '${widget.receiverId}-${widget.currentUserId}';
      final combinedRoom = [widget.currentUserId, widget.receiverId]..sort();
      final sortedRoom = combinedRoom.join('-');

      socket.emit('room_message', {'room': directRoom, 'message': message});
      print('Emitted room_message to room: $directRoom');

      socket.emit('room_message', {'room': reverseRoom, 'message': message});
      print('Emitted room_message to room: $reverseRoom');

      socket.emit('room_message', {'room': sortedRoom, 'message': message});
      print('Emitted room_message to room: $sortedRoom');

      // Also try with underscores
      socket.emit('room_message',
          {'room': directRoom.replaceAll('-', '_'), 'message': message});
      socket.emit('room_message',
          {'room': reverseRoom.replaceAll('-', '_'), 'message': message});
      socket.emit('room_message',
          {'room': sortedRoom.replaceAll('-', '_'), 'message': message});

      // Format 7: Chat message format
      socket.emit('chat_message', {
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'message': messageContent,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('Emitted with chat_message event');

      // Format 8: Simple text message
      socket.emit('message_text', messageContent);
      print('Emitted simple text message');

      // Format 9: JSON string message
      socket.emit('message_json', json.encode(message));
      print('Emitted JSON string message');

      print('Finished emitting message via socket');

      // Ensure ChatService socket is connected before sending
      if (_chatService.socket == null || !_chatService.socket!.connected) {
        print('ChatService socket not connected, reconnecting...');
        _chatService.connectSocket(widget.currentUserId);

        // Wait a moment for connection to establish
        await Future.delayed(Duration(milliseconds: 300));
      }

      // Also send via HTTP as fallback
      print('Sending message via HTTP as fallback');
      _chatService
          .sendMessage(
        widget.receiverId,
        messageContent,
        widget.token,
        widget.currentUserId,
      )
          .then((result) {
        print('HTTP message send successful, result: $result');

        // If we got a real ID back from the server, update our message
        if (result != null && result['_id'] != null) {
          // Add the server ID to processed IDs
          _processedMessageIds.add(result['_id']);
          print('Added server message ID to processed IDs: ${result['_id']}');

          // Update the message in the UI with the server ID
          setState(() {
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i]['_id'] == tempMessageId) {
                _messages[i]['_id'] = result['_id'];
                _messages[i]['isSending'] = false;
                break;
              }
            }
          });
        }

        // Clear sending state after a delay
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isSending = false;

              // Update all messages that are still marked as sending
              for (int i = 0; i < _messages.length; i++) {
                if (_messages[i]['isSending'] == true) {
                  _messages[i]['isSending'] = false;
                }
              }
            });
          }
        });
      }).catchError((error) {
        print('HTTP message send failed: $error');

        // Clear sending state on error
        setState(() {
          _isSending = false;
        });
      });

      print('========== FINISHED SENDING MESSAGE ==========');
    } catch (e) {
      print('Error sending message: $e');
      print(e.toString());

      // Clear sending state on error
      setState(() {
        _isSending = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
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
                    color: _isConnected ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  _isConnected
                      ? AppLocalizations.translate('online', currentLanguage)
                      : 'Socket Offline',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_isConnected)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                socket.connect();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reconnecting socket...')),
                );
              },
            ),
        ],
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
        final dateTimeStr = message['timestamp'] ?? message['createdAt'] ?? '';
        DateTime dateTime;

        try {
          dateTime = DateTime.parse(dateTimeStr.toString());
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
    final isMe = message['senderId'] == widget.currentUserId;
    final isSending = isMe && _isSending && !message.containsKey('_id');

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
              message['content'] ?? message['message'] ?? '',
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
                  _formatTime(message['timestamp'] ?? message['createdAt']),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: 4),
                  isSending
                      ? SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      : Icon(
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
            child: _isSending
                ? Container(
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
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
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }
}
