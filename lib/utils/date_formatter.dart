import 'package:intl/intl.dart';

String formatChatTime(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final messageDate = DateTime(time.year, time.month, time.day);
  
  if (messageDate == today) {
    return DateFormat('h:mm a').format(time);
  } else if (messageDate == yesterday) {
    return 'Yesterday';
  } else if (now.difference(time).inDays < 7) {
    return DateFormat('EEEE').format(time); // Day of week
  } else {
    return DateFormat('MMM d').format(time); // Month and day
  }
}

String formatMessageTime(DateTime time) {
  return DateFormat('h:mm a').format(time);
}