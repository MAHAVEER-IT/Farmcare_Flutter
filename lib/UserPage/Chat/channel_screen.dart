import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../services/channel_service.dart';
import 'channel_chat_screen.dart';

class ChannelScreen extends StatefulWidget {
  final String currentUserId;
  final String token;

  const ChannelScreen({
    Key? key,
    required this.currentUserId,
    required this.token,
  }) : super(key: key);

  @override
  _ChannelScreenState createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final ChannelService _channelService = ChannelService();
  List<Channel> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await _channelService.getAllChannels(widget.token);
      if (mounted) {
        setState(() {
          _channels = channels;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading channels: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load channels: $e')),
        );
      }
    }
  }

  Future<void> _joinChannel(Channel channel) async {
    try {
      await _channelService.joinChannel(channel.id, widget.token);
      await _loadChannels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully joined ${channel.name}')),
        );
      }
    } catch (e) {
      print('Error joining channel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join channel: $e')),
        );
      }
    }
  }

  Future<void> _leaveChannel(Channel channel) async {
    try {
      await _channelService.leaveChannel(channel.id, widget.token);
      await _loadChannels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully left ${channel.name}')),
        );
      }
    } catch (e) {
      print('Error leaving channel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave channel: $e')),
        );
      }
    }
  }

  void _onChannelTap(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChannelChatScreen(
          channelId: channel.id,
          channelName: channel.name,
          currentUserId: widget.currentUserId,
          token: widget.token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadChannels,
        color: Colors.green.shade300,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Colors.green.shade300,
                ),
              )
            : _channels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No channels available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join or create a channel to start chatting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Joined Channels Section
                      if (_channels.any((channel) =>
                          channel.members.contains(widget.currentUserId))) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.group,
                                size: 20,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Joined Channels',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._channels
                            .where((channel) =>
                                channel.members.contains(widget.currentUserId))
                            .map((channel) => _buildChannelCard(channel, true))
                            .toList(),
                        const SizedBox(height: 24),
                      ],

                      // Available Channels Section
                      if (_channels.any((channel) =>
                          !channel.members.contains(widget.currentUserId))) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.group_add,
                                size: 20,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Available Channels',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._channels
                            .where((channel) =>
                                !channel.members.contains(widget.currentUserId))
                            .map((channel) => _buildChannelCard(channel, false))
                            .toList(),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _buildChannelCard(Channel channel, bool isMember) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: isMember ? () => _onChannelTap(channel) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isMember ? Colors.green.shade50 : Colors.orange.shade50,
                child: Icon(
                  Icons.group,
                  color:
                      isMember ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${channel.members.length} members',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isMember)
                TextButton(
                  onPressed: () => _joinChannel(channel),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Join'),
                )
              else
                TextButton(
                  onPressed: () => _leaveChannel(channel),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Leave'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateChannelDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create Channel',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Channel Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _channelService.createChannel(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    widget.token,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _loadChannels();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Channel created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create channel: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
