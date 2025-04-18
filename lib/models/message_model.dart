import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final String status; // sent, delivered, read
  
  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.status = 'sent',
  });
  
  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      status: map['status'] ?? 'sent',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp,
      'status': status,
    };
  }
}