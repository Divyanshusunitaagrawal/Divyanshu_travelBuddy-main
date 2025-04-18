import 'package:flutter/material.dart';
import 'package:travelcompanion/models/user_model.dart';
import 'package:travelcompanion/screens/auth/login_screen.dart';
import 'package:travelcompanion/screens/auth/register_screen.dart';
import 'package:travelcompanion/screens/chat/chat_list_screen.dart';
import 'package:travelcompanion/screens/chat/chat_screen.dart';
import 'package:travelcompanion/screens/home/dashboard_screen.dart';
import 'package:travelcompanion/screens/home/home_screen.dart';
import 'package:travelcompanion/screens/home/map_screen.dart';
import 'package:travelcompanion/screens/home/profile_screen.dart';


class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
    // '/': (context) => HomeScreen(), 
    '/login': (context) => LoginScreen(),
    '/register': (context) => RegisterScreen(),
    '/home': (context) => HomeScreen(),
    '/dashboard': (context) => DashboardScreen(),
    '/map': (context) => MapScreen(),
    '/profile': (context) => ProfileScreen(),
    'chat_list': (context) => ChatListScreen(),
    '/chat': (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      
      if (args == null) {
        return Center(child: Text('No chat data provided'));
      }
      
      final user = args['user'] as UserModel;
      final chatId = args['chatId'] as String;
      
      return ChatScreen(user: user, chatId: chatId);
    },
  };
  
  // Use this for named routes that require parameters
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/chat':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => ChatScreen(
            user: args['user'],
            chatId: args['chatId'],
          ),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}