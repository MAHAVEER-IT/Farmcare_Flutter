import 'package:flutter/material.dart';
import 'package:farmcare/widgets/share_button.dart';
import 'package:farmcare/UserPage/Chat/ChannelChat.dart';
import 'package:farmcare/models/channel.dart';

class ChannelList extends StatelessWidget {
  final List<Channel> channels;

  const ChannelList({
    Key? key,
    required this.channels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels available',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, index) =>
          _buildChannelCard(context, channels[index]),
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel channel) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChannelChatScreen(channel: channel),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade800,
          child: Text(
            channel.name[0].toUpperCase(),
            style: TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          channel.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel.description ?? 'No description',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${channel.members.length} members',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShareButton(
              type: ShareType.channel,
              id: channel.id,
              title: channel.name,
              content: '',
              description: channel.description,
              size: 20,
              color: Colors.green.shade800,
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
