import 'package:intl/intl.dart';

class TimeFormatter {
  static String format(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      // If more than a day old, show the date
      return DateFormat('MMM d, HH:mm').format(time);
    } else if (difference.inHours > 0) {
      // If hours old, show "X hours ago"
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      // If minutes old, show "X minutes ago"
      return '${difference.inMinutes}m ago';
    } else {
      // If less than a minute old, show "Just now"
      return 'Just now';
    }
  }
}
