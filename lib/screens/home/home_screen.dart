  import 'dart:ui';

import 'package:flutter/material.dart';
  import 'package:travelcompanion/config/theme.dart';
  import 'package:travelcompanion/screens/chat/chat_list_screen.dart';
  import 'package:travelcompanion/screens/home/dashboard_screen.dart';
  import 'package:travelcompanion/screens/home/map_screen.dart';
  import 'package:travelcompanion/screens/home/profile_screen.dart';
  import 'package:travelcompanion/services/firestore_service.dart';


  class HomeScreen extends StatefulWidget {
    @override
    _HomeScreenState createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    int _currentIndex = 0;
    final FirestoreService _firestoreService = FirestoreService();
    bool _isUserActive = false;
    
    final List<Widget> _screens = [
      DashboardScreen(),
      MapScreen(),
      ChatListScreen(),
      ProfileScreen(),
    ];
    
    @override
    void initState() {
      super.initState();
      _loadUserStatus();
    }
    
    Future<void> _loadUserStatus() async {
      try {
        final userData = await _firestoreService.getCurrentUserData();
        if (userData != null) {
          setState(() {
            _isUserActive = userData.isActive;
          });
        }
      } catch (e) {
        print('Error loading user status: $e');
      }
    }
    
    Future<void> _toggleUserStatus() async {
      try {
        final newStatus = !_isUserActive;
        await _firestoreService.updateCurrentUserData({
          'isActive': newStatus,
        });
        
        setState(() {
          _isUserActive = newStatus;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus 
                ? 'You are now visible to other travelers' 
                : 'You are now hidden from other travelers'),
            backgroundColor: newStatus ? AppTheme.accentColor : Colors.grey,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(10),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.all(10),
          ),
        );
      }
    }
    
    @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        _screens[_currentIndex],
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavBarItem(Icons.dashboard, 'Home', 0),
                      _buildNavBarItem(Icons.map, 'Map', 1),
                      _buildNavBarItem(Icons.chat_bubble_outline, 'Chats', 2),
                      _buildNavBarItem(Icons.person_outline, 'Profile', 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildNavBarItem(IconData icon, String label, int index) {
  final isSelected = _currentIndex == index;
  return GestureDetector(
    onTap: () {
      setState(() {
        _currentIndex = index;
      });
    },
    child: AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

  }