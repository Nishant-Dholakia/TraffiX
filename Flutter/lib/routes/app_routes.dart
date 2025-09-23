import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../../chatbot.dart';
import '../../Home.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String chatbot = '/chatbot';

  static final Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    home: (_) => const TrafficApp(),
    chatbot: (_) => const ChatBot(),
  };
}
// TODO Implement this library.