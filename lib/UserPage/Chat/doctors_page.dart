import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/channel_service.dart';
import '../../services/doctor_service.dart' as doc_service;
import '../../services/chat_service.dart' as chat_service;
import 'channel_screen.dart';
import 'chat_screen.dart';

class DoctorsPage extends StatefulWidget {
  final String currentUserId;
  final String token;
  final bool isDoctor;

  const DoctorsPage({
    Key? key,
    required this.currentUserId,
    required this.token,
    required this.isDoctor,
  }) : super(key: key);

  @override
  _DoctorsPageState createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final doc_service.DoctorService _doctorService = doc_service.DoctorService();
  final chat_service.ChatService _chatService = chat_service.ChatService();
  int _currentIndex = 0;
  List<chat_service.ChatHistory> _chatHistory = [];
  bool _isLoadingChats = true;

  @override
  void initState() {
    super.initState();
    if (widget.isDoctor) {
      _loadChatHistory();
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await _chatService.getChats(widget.token);
      if (mounted) {
        setState(() {
          _chatHistory = history;
          _isLoadingChats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChats = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.isDoctor
              ? (_currentIndex == 0 ? 'Chats' : 'Channels')
              : (_currentIndex == 0 ? 'Doctors' : 'Channels'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_currentIndex == 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateChannelDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade400,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _currentIndex == 0
          ? (widget.isDoctor ? _buildChatHistory() : _buildDoctorsList())
          : _buildChannelsScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(widget.isDoctor ? Icons.chat : Icons.person),
              activeIcon: Icon(
                widget.isDoctor ? Icons.chat : Icons.person,
                size: 28,
              ),
              label: widget.isDoctor ? 'Chats' : 'Doctors',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.group),
              activeIcon: Icon(Icons.group, size: 28),
              label: 'Channels',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistory() {
    if (_isLoadingChats) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.green.shade300,
        ),
      );
    }

    if (_chatHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No chat history yet',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final chat = _chatHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _openChat(chat.user),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.green.shade50,
                      backgroundImage: chat.user.profilePic.isNotEmpty
                          ? NetworkImage(chat.user.profilePic)
                          : null,
                      child: chat.user.profilePic.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.green.shade700,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat.user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (chat.lastMessage != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              chat.lastMessage!.content,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatLastMessageTime(
                                  chat.lastMessage!.timestamp),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (chat.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          chat.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return DateFormat('E').format(time);
    } else {
      return DateFormat('HH:mm').format(time);
    }
  }

  Widget _buildDoctorsList() {
    return FutureBuilder<List<doc_service.Doctor>>(
      future: _doctorService.getDoctors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.green.shade300,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading doctors',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No doctors available',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final doctors = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _openChat(doctor),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.green.shade50,
                          backgroundImage: doctor.profilePic.isNotEmpty
                              ? NetworkImage(doctor.profilePic)
                              : null,
                          child: doctor.profilePic.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.green.shade700,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    doctor.location,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    doctor.phone,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.green.shade700,
                            ),
                            onPressed: () => _openChat(doctor),
                            tooltip: 'Chat with doctor',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChannelsScreen() {
    return ChannelScreen(
      currentUserId: widget.currentUserId,
      token: widget.token,
    );
  }

  void _openChat(dynamic user) {
    // Debug logging
    print('Raw user object: $user');
    if (user is chat_service.Doctor) {
      print('User is a Doctor object with id: ${user.id}');
    } else {
      print('User is not a Doctor object: ${user.runtimeType}');
    }

    // Extract the doctor ID and validate it
    String doctorId = '';
    String doctorName = 'Unknown Doctor';

    if (user is doc_service.Doctor) {
      doctorId = user.id;
      doctorName = user.name;
    } else if (user is chat_service.Doctor) {
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
          currentUserId: widget.currentUserId,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _showCreateChannelDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 8),
            const Text('Create Channel'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Channel Name',
                hintText: 'Enter channel name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.green.shade700,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Enter channel description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.green.shade700,
                    width: 2,
                  ),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  descriptionController.text.isNotEmpty) {
                try {
                  final channelService = ChannelService();
                  await channelService.createChannel(
                    nameController.text,
                    descriptionController.text,
                    widget.token,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Refresh the channels list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating channel: $e'),
                        backgroundColor: Colors.red.shade400,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
