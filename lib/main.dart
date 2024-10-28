import 'package:bingo/authentication/login_page.dart';
import 'package:bingo/authentication/register_page.dart';
import 'package:bingo/dashboard.dart';
import 'package:bingo/firebase_options.dart';
import 'package:bingo/friends/friends_page.dart';
import 'package:bingo/game/boards/boards_page.dart';
import 'package:bingo/game/match_page.dart';
import 'package:bingo/game/match_req.dart';
import 'package:bingo/game/match_service.dart';
import 'package:bingo/game/playwithfrd.dart';
import 'package:bingo/game/presence_service.dart';
import 'package:bingo/globals.dart';
import 'package:bingo/push_notifications/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  MatchService matchService = MatchService();
  await matchService.migrateUsersMatchesWon();
  await matchService.migrateExistingMatchesPlayersArray();

  // Set the background message handler

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  User? _user;
  PushNotificationService? _pushNotificationService;
  PresenceService? _presenceService;

  @override
  void initState() {
    super.initState();
    _checkUserAuthentication();
  }

  /// Listens to authentication state changes
  void _checkUserAuthentication() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      setState(() {
        _user = user;
      });

      if (user != null) {
        // Initialize MatchService with the authenticated user
        MatchService().initialize(user);

        // Initialize Presence Service
        _presenceService = PresenceService();
        // MatchService handles its own listeners internally
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Assign the global navigatorKey
      title: 'Bingo Matchmaking',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Directly check if the user is logged in using FirebaseAuth.instance.currentUser
      initialRoute:
          FirebaseAuth.instance.currentUser != null ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/friends': (context) => const FriendsPage(),
        '/play_with_friend': (context) => const PlayWithFriendPage(),
        '/match_requests': (context) => const MatchRequestsPage(),
        '/match': (context) => const MatchPage(),
        '/my_boards': (context) => const MyBoardsPage(),
      },
    );
  }
}
