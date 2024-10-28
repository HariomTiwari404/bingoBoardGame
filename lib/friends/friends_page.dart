// lib/friends/friends_page.dart

import 'package:bingo/friends/friend_service.dart';
import 'package:bingo/push_notifications/push_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendService _friendService = FriendService();
  final TextEditingController _friendEmailController = TextEditingController();
  int _currentTabIndex = 0;
  bool _isLoading = false; // Loading state
  String? _processingRequestId; // State to track processing request
  bool _hasPendingRequests = false; // Track pending requests

  @override
  void initState() {
    super.initState();
    _listenForPendingFriendRequests();
  }

  // Real-time listener to track pending friend requests
  void _listenForPendingFriendRequests() {
    FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasPendingRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final screenWidth = MediaQuery.of(context).size.width;

    // Define a scaling factor based on the screen width
    final double scaleFactor =
        screenWidth < 350 ? 0.8 : (screenWidth < 450 ? 0.9 : 1.0);

    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      appBar: _buildAppBar(context, scaleFactor),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1c1c1c), Color(0xFF3a3a3a)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0 * scaleFactor),
            child: Column(
              children: [
                _buildSendFriendRequestSection(context, scaleFactor),
                SizedBox(height: 16 * scaleFactor),
                _buildTabBar(scaleFactor),
                SizedBox(height: 16 * scaleFactor),
                Expanded(
                  child: _buildCurrentTabContent(
                      scaleFactor, currentUserId, firestore),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeFriendship(String userId1, String userId2) async {
    try {
      // Query for both possible friendship documents (user1-user2 or user2-user1).
      var querySnapshot = await FirebaseFirestore.instance
          .collection('friends')
          .where('user1', whereIn: [userId1, userId2]).where('user2',
              whereIn: [userId1, userId2]).get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete(); // Delete the friendship document.
      }
      _showSnackBar(
          context, 'Friend removed successfully!', Colors.greenAccent);
    } catch (e) {
      _showSnackBar(context, 'Error: $e', Colors.redAccent);
    }
  }

  Widget _buildSendFriendRequestSection(
      BuildContext context, double scaleFactor) {
    return Card(
      color: Colors.grey.shade900
          .withOpacity(0.8), // Semi-transparent dark background
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(16.0 * scaleFactor),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _friendEmailController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.person, color: Colors.tealAccent),
                  labelText: 'Friend\'s Email or Username',
                  labelStyle: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  contentPadding: EdgeInsets.symmetric(
                      vertical: 18 * scaleFactor, horizontal: 16 * scaleFactor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Colors.tealAccent,
                      width: 2,
                    ),
                  ),
                  hintText: 'Enter username or email',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14 * scaleFactor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12 * scaleFactor),
            _isLoading
                ? SizedBox(
                    width: 24 * scaleFactor,
                    height: 24 * scaleFactor,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16 * scaleFactor),
                      elevation: 5,
                      shadowColor: Colors.tealAccent.shade200,
                    ),
                    onPressed: () async {
                      String input = _friendEmailController.text.trim();
                      if (input.isEmpty) {
                        _showSnackBar(context,
                            'Please enter a username or email.', Colors.orange);
                        return;
                      }

                      setState(() => _isLoading = true); // Start loading

                      try {
                        String recipientId =
                            await _friendService.sendFriendRequest(input);

                        await _notifyUser(
                          recipientId,
                          '📩 New Friend Request!',
                          'You have a new friend request from ${FirebaseAuth.instance.currentUser?.email}.',
                        );

                        _showSnackBar(context, 'Friend request sent!',
                            Colors.greenAccent);
                        _friendEmailController.clear();
                      } catch (e) {
                        _showSnackBar(context, 'Error: $e', Colors.redAccent);
                      } finally {
                        setState(() => _isLoading = false); // Stop loading
                      }
                    },
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
          ],
        ),
      ),
    );
  }

  // TabBar with indicator
  Widget _buildTabBar(double scaleFactor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabButton('Friends', 0, scaleFactor),
        _buildTabButton('Sent Requests', 1, scaleFactor),
        _buildTabButton(
            _hasPendingRequests ? 'Received Requests ★' : 'Received Requests',
            2,
            scaleFactor),
      ],
    );
  }

  // Tab button builder
  Widget _buildTabButton(String title, int index, double scaleFactor) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12 * scaleFactor),
          margin: EdgeInsets.symmetric(horizontal: 4 * scaleFactor),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _currentTabIndex == index
                ? LinearGradient(
                    colors: [
                      Colors.tealAccent.shade700,
                      Colors.tealAccent.shade400
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Colors.grey, Colors.black54],
                  ),
            boxShadow: _currentTabIndex == index
                ? [
                    BoxShadow(
                      color: Colors.tealAccent.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: _currentTabIndex == index
                    ? Colors.white
                    : Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16 * scaleFactor,
                shadows: _currentTabIndex == index
                    ? [
                        const Shadow(
                          blurRadius: 2.0,
                          color: Colors.black26,
                          offset: Offset(1, 1),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent(
      double scaleFactor, String currentUserId, FirebaseFirestore firestore) {
    switch (_currentTabIndex) {
      case 0:
        return _buildFriendsList(scaleFactor, currentUserId, firestore);
      case 1:
        return _buildSentRequestsList(scaleFactor);
      case 2:
        return _buildPendingRequestsList(scaleFactor);
      default:
        return const SizedBox();
    }
  }

  Widget _buildFriendsList(
      double scaleFactor, String currentUserId, FirebaseFirestore firestore) {
    return StreamBuilder(
      stream: firestore
          .collection('friends')
          .where('user1', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(
              child: Text(
            'Error loading friends.',
            style: TextStyle(color: Colors.white),
          ));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data?.docs ?? [];

        if (friends.isEmpty) {
          return const Center(
            child: Text(
              'You have no friends.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          padding: EdgeInsets.symmetric(
              vertical: 12 * scaleFactor, horizontal: 8 * scaleFactor),
          itemBuilder: (context, index) {
            var friend = friends[index];
            String friendId = friend['user2'];

            return FutureBuilder<Map<String, dynamic>?>(
              future: _friendService.getUserDetails(friendId),
              builder:
                  (context, AsyncSnapshot<Map<String, dynamic>?> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: CircularProgressIndicator(),
                  );
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const ListTile(
                    title: Text(
                      'User not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final userData = userSnapshot.data!;
                final username = userData['username'] ?? 'Unknown';
                final email = userData['email'] ?? 'No Email Provided';

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: EdgeInsets.symmetric(
                      vertical: 10 * scaleFactor, horizontal: 16 * scaleFactor),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade700,
                          Colors.deepPurple.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.all(16 * scaleFactor),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28 * scaleFactor,
                          backgroundColor: Colors.tealAccent.shade700,
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 24),
                          ),
                        ),
                        SizedBox(width: 16 * scaleFactor),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: GoogleFonts.robotoMono(
                                  textStyle: TextStyle(
                                    fontSize: 18 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.tealAccent,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4 * scaleFactor),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14 * scaleFactor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            await _removeFriendship(currentUserId, friendId);
                          },
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
    );
  }

  Widget _buildSentRequestsList(double scaleFactor) {
    return StreamBuilder(
      stream: _friendService.getSentFriendRequests(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(
              child: Text(
            'Error loading sent requests.',
            style: TextStyle(color: Colors.white),
          ));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No sent friend requests.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          padding: EdgeInsets.symmetric(
              vertical: 12 * scaleFactor, horizontal: 8 * scaleFactor),
          itemBuilder: (context, index) {
            var request = requests[index];
            String toUserId = request['to'];

            return FutureBuilder<Map<String, dynamic>?>(
              future: _friendService.getUserDetails(toUserId),
              builder:
                  (context, AsyncSnapshot<Map<String, dynamic>?> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: CircularProgressIndicator(),
                  );
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const ListTile(
                    title: Text(
                      'User not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final user = userSnapshot.data!;
                final username = user['username'] ?? 'Unknown';
                final email = user['email'] ?? 'Unknown';

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: EdgeInsets.symmetric(
                      vertical: 10 * scaleFactor, horizontal: 16 * scaleFactor),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade700,
                          Colors.deepPurple.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.all(16 * scaleFactor),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28 * scaleFactor,
                          backgroundColor: Colors.tealAccent.shade700,
                          child: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16 * scaleFactor),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request sent to: $username',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4 * scaleFactor),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14 * scaleFactor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8 * scaleFactor),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingRequestsList(double scaleFactor) {
    return StreamBuilder(
      stream: _friendService.getReceivedFriendRequests(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(
              child: Text(
            'Error loading requests.',
            style: TextStyle(color: Colors.white),
          ));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No pending requests.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          padding: EdgeInsets.symmetric(
              vertical: 12 * scaleFactor, horizontal: 8 * scaleFactor),
          itemBuilder: (context, index) {
            var request = requests[index];
            String requestId = request.id;
            String fromUserId = request['from'];

            return FutureBuilder<Map<String, dynamic>?>(
              future: _friendService.getUserDetails(fromUserId),
              builder:
                  (context, AsyncSnapshot<Map<String, dynamic>?> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: CircularProgressIndicator(),
                  );
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const ListTile(
                    title: Text(
                      'User not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final user = userSnapshot.data!;
                final username = user['username'] ?? 'Unknown';
                final email = user['email'] ?? 'Unknown';

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: EdgeInsets.symmetric(
                      vertical: 10 * scaleFactor, horizontal: 16 * scaleFactor),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade700,
                          Colors.deepPurple.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.all(16 * scaleFactor),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28 * scaleFactor,
                          backgroundColor: Colors.tealAccent.shade700,
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24),
                          ),
                        ),
                        SizedBox(width: 16 * scaleFactor),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request from: $username',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4 * scaleFactor),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14 * scaleFactor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8 * scaleFactor),
                        _buildActionButtons(
                            context, requestId, fromUserId, scaleFactor),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildActionButtons(BuildContext context, String requestId,
      String fromUserId, double scaleFactor) {
    final isProcessing = _processingRequestId == requestId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isProcessing
            ? SizedBox(
                width: 24 * scaleFactor,
                height: 24 * scaleFactor,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: () async {
                  await _handleRequest(
                    requestId,
                    fromUserId,
                    isAccept: true,
                  );
                },
              ),
        SizedBox(width: 8 * scaleFactor),
        isProcessing
            ? SizedBox(
                width: 24 * scaleFactor,
                height: 24 * scaleFactor,
              ) // Placeholder to maintain alignment
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () async {
                  await _handleRequest(
                    requestId,
                    fromUserId,
                    isAccept: false,
                  );
                },
              ),
      ],
    );
  }

  Future<void> _handleRequest(String requestId, String fromUserId,
      {required bool isAccept}) async {
    setState(() => _processingRequestId = requestId); // Start processing

    try {
      if (isAccept) {
        await _friendService.acceptFriendRequest(requestId, fromUserId);
        await _notifyUser(
          fromUserId,
          '✅ Friend Request Accepted!',
          'Your friend request was accepted!',
        );
        _showSnackBar(context, 'Friend request accepted!', Colors.greenAccent);
      } else {
        await _friendService.rejectFriendRequest(requestId, fromUserId);
        await _notifyUser(
          fromUserId,
          '❌ Friend Request Rejected',
          'Your friend request was rejected.',
        );
        _showSnackBar(context, 'Request rejected.', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar(context, 'Error: $e', Colors.redAccent);
    } finally {
      setState(() => _processingRequestId = null); // Stop processing
    }
  }

  Future<void> _notifyUser(String userId, String title, String body) async {
    try {
      QuerySnapshot tokensSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .get();

      List<String> tokens =
          tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

      for (String token in tokens) {
        await PushNotificationService.sendNotificationToUser(
            token, title, body);
      }

      print('📲 Notification sent to user: $userId');
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  AppBar _buildAppBar(BuildContext context, double scaleFactor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        'Friends',
        style: GoogleFonts.oswald(
          textStyle: TextStyle(
            fontSize: 28 * scaleFactor,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            setState(() {});
          },
        ),
      ],
      centerTitle: true,
    );
  }
}
