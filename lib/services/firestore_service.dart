import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travelcompanion/models/user_model.dart';


class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Get user data
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }
  
  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    if (currentUserId == null) return null;
    return getUserData(currentUserId!);
  }
  
  // Update user data
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      rethrow;
    }
  }
  
  // Update current user data
  Future<void> updateCurrentUserData(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    return updateUserData(currentUserId!, data);
  }
  
  // Get all users
  Stream<List<UserModel>> getUsers({String? searchQuery, bool? activeOnly}) {
    Query query = _firestore.collection('users');
    
    if (activeOnly == true) {
      query = query.where('isActive', isEqualTo: true);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((user) {
            // Filter by search query if provided
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final name = user.name?.toLowerCase() ?? '';
              final interest = user.interest?.toLowerCase() ?? '';
              final query = searchQuery.toLowerCase();
              
              return name.contains(query) || interest.contains(query);
            }
            
            return true;
          })
          .where((user) => user.id != currentUserId) // Exclude current user
          .toList();
    });
  }
  
  // Get chat messages
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
  
  // Send chat message
 // In firestore_service.dart
// In firestore_service.dart
// In firestore_service.dart
Future<void> sendChatMessage(String chatId, String message) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  if (currentUserId == null) return;
  
  try {
    // Extract other user ID from chat ID
    String otherUserId = '';
    final chatIdParts = chatId.split('_');
    
    if (chatIdParts.length == 2) {
      otherUserId = chatIdParts[0] == currentUserId ? chatIdParts[1] : chatIdParts[0];
      print("Extracted other user ID from chat ID: $otherUserId");
    } else {
      print("Invalid chat ID format. Using empty participant list.");
      // Continue anyway to not break existing functionality
    }
    
    // Add message
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'text': message,
          'senderId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
        });
    
    // Prepare participants list
    List<String> participants = [currentUserId];
    if (otherUserId.isNotEmpty) {
      participants.add(otherUserId);
    }
    
    // Update chat metadata
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': participants, // Include both participants when possible
    }, SetOptions(merge: true));
  } catch (e) {
    print("Error sending message: $e");
    rethrow;
  }
}

Future<void> deleteChatMessage(String chatId, String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }
  
  // Get user chats
 // In firestore_service.dart
// In firestore_service.dart
// In firestore_service.dart
// In firestore_service.dart
Stream<QuerySnapshot> getUserChats() {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  print("GetUserChats called - Current user ID: $currentUserId");
  
  if (currentUserId == null) {
    print("No user logged in, returning empty stream");
    // Return an empty stream
    return Stream.empty();
  }
  
  print("Fetching chats for user: $currentUserId");
  
  // Simple query without any ordering (which would require an index)
  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: currentUserId)
      .snapshots();
}
  
  // Update user location
  Future<void> updateUserLocation(double latitude, double longitude) async {
    if (currentUserId == null) return;
    
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
  
  // Get users near location
  Future<List<UserModel>> getUsersNearLocation(
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    try {
      // Get all users (in a real app, you'd use a geospatial query)
      final snapshot = await _firestore.collection('users').get();
      
      final List<UserModel> nearbyUsers = [];
      
      for (var doc in snapshot.docs) {
        final userData = doc.data();
        
        // Skip users without location data
        if (userData['latitude'] == null || userData['longitude'] == null) {
          continue;
        }
        
        // Calculate distance
        final double userLat = userData['latitude'];
        final double userLng = userData['longitude'];
        
        final distance = _calculateDistance(
          latitude, longitude, userLat, userLng);
        
        // Add users within the radius
        if (distance <= radiusInKm && doc.id != currentUserId) {
          final user = UserModel.fromMap(userData, doc.id);
          user.distance = distance;
          nearbyUsers.add(user);
        }
      }
      
      // Sort by distance
      nearbyUsers.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      
      return nearbyUsers;
    } catch (e) {
      rethrow;
    }
  }
  
  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = (
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2)
    );
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}