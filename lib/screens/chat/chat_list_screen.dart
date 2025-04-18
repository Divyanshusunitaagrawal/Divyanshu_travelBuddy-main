import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:travelcompanion/config/theme.dart';
import 'package:travelcompanion/models/user_model.dart';
import 'package:travelcompanion/services/auth_service.dart';
import 'package:travelcompanion/services/firestore_service.dart';
import 'package:travelcompanion/utils/date_formatter.dart';
import 'package:travelcompanion/widgets/common/loading_indicator.dart';


class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  
  @override
  bool get wantKeepAlive => true;


  // Create a function to fix your chat document
Future<void> _fixChatDocument() async {
  final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  
  if (currentUserId == null) {
    return;
  }
  
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: LoadingIndicator(message: 'Fixing chat document...')),
  );
  
  try {
    // Get a random user to set as the other participant
    final users = await _firestoreService.getUsers(activeOnly: true).first;
    
    if (users.isEmpty) {
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other users available')),
      );
      return;
    }
    
    // Find a user who isn't the current user
    UserModel? otherUser;
    for (var user in users) {
      if (user.id != currentUserId) {
        otherUser = user;
        break;
      }
    }
    
    if (otherUser == null) {
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other user available')),
      );
      return;
    }
    
    // Get the chat ID from the log
    final chatId = "${currentUserId}_${otherUser.id}";
    
    // Update the chat document to include both participants
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .update({
          'participants': [currentUserId, otherUser.id],
        });
    
    Navigator.pop(context); // Dismiss loading
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat document fixed successfully')),
    );
    
    // Refresh the screen
    setState(() {});
    
  } catch (e) {
    Navigator.pop(context); // Dismiss loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fixing chat: $e')),
    );
  }
}


  Future<void> _debugFirestoreChats() async {
  final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  print("Debugging Firestore Chats - CurrentUser: $currentUserId");
  
  if (currentUserId == null) {
    print("No user logged in");
    return;
  }
  
  try {
    // Direct query without stream
    final querySnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();
    
    print("Raw query returned ${querySnapshot.docs.length} documents");
    
    for (var doc in querySnapshot.docs) {
      print("Chat ID: ${doc.id}");
      print("Chat data: ${doc.data()}");
      
      // Manually check participants
      final data = doc.data();
      final List<dynamic>? participants = data['participants'] as List<dynamic>?;
      print("Participants: $participants");
      
      if (participants != null) {
        print("Is current user in participants: ${participants.contains(currentUserId)}");
        
        // Try to load other users
        for (var participantId in participants) {
          if (participantId != currentUserId) {
            print("Trying to load user data for: $participantId");
            try {
              final userData = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(participantId)
                  .get();
              
              print("User exists: ${userData.exists}");
              if (userData.exists) {
                print("User data: ${userData.data()}");
              }
            } catch (e) {
              print("Error loading user $participantId: $e");
            }
          }
        }
      }
    }
  } catch (e) {
    print("Error debugging chats: $e");
  }
}

  // Add this to your _ChatListScreenState class
Future<void> _createTestChat() async {
  final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
  
  if (currentUserId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You need to be logged in')),
    );
    return;
  }
  
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: LoadingIndicator(message: 'Creating test chat...')),
  );
  
  try {
    // Get a random user to chat with
    final users = await _firestoreService.getUsers(activeOnly: true).first;
    
    if (users.isEmpty || (users.length == 1 && users[0].id == currentUserId)) {
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No other users available to chat with')),
      );
      return;
    }
    
    // Find a user who isn't the current user
    final otherUser = users.firstWhere((user) => user.id != currentUserId, 
                                      orElse: () => users[0]);
    
    // Create chat ID
    final chatId = _getChatId(currentUserId, otherUser.id);
    
    // Create chat document
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({
          'participants': [currentUserId, otherUser.id],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Test conversation',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
    
    // Also create an initial message
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'text': 'Hello, this is a test message!',
          'timestamp': FieldValue.serverTimestamp(),
        });
    
    Navigator.pop(context); // Dismiss loading
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Test chat created successfully')),
    );
    
    // Refresh the screen
    setState(() {});
    
  } catch (e) {
    Navigator.pop(context); // Dismiss loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error creating test chat: $e')),
    );
  }
}

String _getChatId(String userId1, String userId2) {
  final users = [userId1, userId2]..sort();
  return '${users[0]}_${users[1]}';
}


  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUserId = Provider.of<AuthService>(context).currentUser?.uid;

    print("Current user ID: $currentUserId"); 
    
    return Scaffold(
      appBar: AppBar(
        
        title: Text('Conversations'),
        centerTitle: true,
        elevation: 0,
      ),
     
      body: currentUserId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'You need to be logged in',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
            padding: EdgeInsets.only(bottom: 90), // Enough space for the nav bar
            // padding: const EdgeInsets.all(8.0),
            child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getUserChats(),
                builder: (context, snapshot) {
            
                  print("StreamBuilder state: ${snapshot.connectionState}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: LoadingIndicator(message: 'Loading conversations...'));
                  }
                  
                  if (snapshot.hasError) {
            
                    print("StreamBuilder error: ${snapshot.error}");
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Error loading conversations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {});
                            },
                            child: Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                 if (!snapshot.hasData) {
                  print("No data in snapshot");
                  return _buildEmptyState();
                }
            
                final chatDocs = snapshot.data!.docs;
                print("Number of chat docs: ${chatDocs.length}");
            
            if (chatDocs.isEmpty) {
                  print("Empty chat docs list");
                  return _buildEmptyState();
                }
                
                // Sort locally by lastMessageTime (descending)
                chatDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aTimestamp = aData['lastMessageTime'] as Timestamp?;
                  final bTimestamp = bData['lastMessageTime'] as Timestamp?;
                  
                  if (aTimestamp == null && bTimestamp == null) {
                    return 0;
                  } else if (aTimestamp == null) {
                    return 1; // a is "smaller" (null comes last)
                  } else if (bTimestamp == null) {
                    return -1; // b is "smaller" (null comes last)
                  }
                  
                  // Compare timestamps in descending order (newest first)
                  return bTimestamp.compareTo(aTimestamp);
                });
                  
                  return ListView.builder(
                    itemCount: chatDocs.length,
                    itemBuilder: (context, index) {
                      final chatDoc = chatDocs[index];
                      final chatData = chatDoc.data() as Map<String, dynamic>;
                      
                      final lastMessage = chatData['lastMessage'] ?? 'New conversation';
                      final lastMessageTime = chatData['lastMessageTime'] != null
                          ? (chatData['lastMessageTime'] as Timestamp).toDate()
                          : DateTime.now();
                      
                      // Extract other participant IDs
                      final List<dynamic> participants = chatData['participants'] ?? [];
                      final otherParticipantIds = participants
                          .where((id) => id != currentUserId)
                          .toList();
                      
                      if (otherParticipantIds.isEmpty) {
                        return SizedBox(); // Skip chats without other participants
                      }
                      
                      // Get the first other participant (for 1:1 chats)
                      final otherUserId = otherParticipantIds[0];
                      
                      return FutureBuilder<UserModel?>(
                        future: _firestoreService.getUserData(otherUserId),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData || userSnapshot.data == null) {
                            return ListTile(
            leading: userSnapshot.hasData && userSnapshot.data != null
                ? CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: userSnapshot.data!.profilePic != null &&
                          userSnapshot.data!.profilePic!.isNotEmpty &&
                          userSnapshot.data!.profilePic!.startsWith('http')
              ? NetworkImage(userSnapshot.data!.profilePic!)
              : null,
                    child: (userSnapshot.data!.profilePic == null ||
                 userSnapshot.data!.profilePic!.isEmpty ||
                 !userSnapshot.data!.profilePic!.startsWith('http'))
              ? Text(
                  userSnapshot.data!.name != null && userSnapshot.data!.name!.isNotEmpty
                      ? userSnapshot.data!.name!.substring(0, 1).toUpperCase()
                      : 'T',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
                  )
                : CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
            'T',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
                    ),
                  ),
                              title: Text('Loading...'),
                              subtitle: Text(lastMessage),
                              trailing: Text(
                                formatChatTime(lastMessageTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          }
                          
                          final otherUser = userSnapshot.data!;
                          
                          return InkWell(
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete Chat'),
                                  content: Text('Are you sure you want to delete this chat?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.of(context).pop(); // Close the dialog
                                        try {
                                          // Delete the chat document
                                          await FirebaseFirestore.instance
                                              .collection('chats')
                                              .doc(chatDoc.id)
                                              .delete();
            
                                          // Optionally, delete the messages subcollection
                                          final messages = await FirebaseFirestore.instance
                                              .collection('chats')
                                              .doc(chatDoc.id)
                                              .collection('messages')
                                              .get();
                                          for (var message in messages.docs) {
                                            await message.reference.delete();
                                          }
            
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Chat deleted successfully')),
                                          );
            
                                          setState(() {}); // Refresh the UI
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error deleting chat: $e')),
                                          );
                                        }
                                      },
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                '/chat',
                                arguments: {
                                  'user': otherUser,
                                  'chatId': chatDoc.id,
                                },
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Row(
                                children: [
                                  // User Avatar
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppTheme.primaryColor,
                                    backgroundImage: otherUser.profilePic != null
                                        ? NetworkImage(otherUser.profilePic!)
                                        : null,
                                    child: otherUser.profilePic == null
                                        ? Text(
                                            otherUser.name?.substring(0, 1).toUpperCase() ?? 'T',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 16),
                                  
                                  // Chat Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              otherUser.name ?? 'Traveler',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              formatChatTime(lastMessageTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          lastMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
          ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start chatting with travelers to see your conversations here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),

        ],
      ),
    );
  }
}