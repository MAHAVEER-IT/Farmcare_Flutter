import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  // Share blog post
  Future<void> sharePost(String postId, String title, String content) async {
    final String shareUrl =
        'https://farmcare-backend-new.onrender.com/api/v1/posts/share/$postId';
    final String shareText = '''
$title

$content

Check out this post: $shareUrl
''';
    await Share.share(shareText, subject: title);
  }

  // Share chat message
  Future<void> shareMessage(String messageId, String content) async {
    final String shareUrl =
        'https://farmcare-backend-new.onrender.com/api/v1/message/share/$messageId';
    final String shareText = '''
$content

View shared message: $shareUrl
''';
    await Share.share(shareText);
  }

  // Share channel
  Future<void> shareChannel(
      String channelId, String channelName, String description) async {
    final String shareUrl =
        'https://farmcare-backend-new.onrender.com/api/v1/channels/share/$channelId';
    final String shareText = '''
Join the channel "$channelName"
$description

Join now: $shareUrl
''';
    await Share.share(shareText);
  }

  // Open shared link
  Future<void> openSharedLink(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}
