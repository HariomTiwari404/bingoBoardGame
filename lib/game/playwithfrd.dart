// lib/pages/play_with_friend_page.dart

import 'package:bingo/friends/friend_service.dart';
import 'package:bingo/game/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlayWithFriendPage extends StatelessWidget {
  const PlayWithFriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final FriendService friendService = FriendService();
    final MatchService matchService = MatchService();

    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      appBar: _buildAppBar(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1c1c1c), Color(0xFF3a3a3a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friends')
                .where('user1', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading friends.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final friends = snapshot.data!.docs;

              if (friends.isEmpty) {
                return const Center(
                  child: Text(
                    'You have no friends.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  String friendId = friends[index]['user2'];

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: friendService.getUserDetails(friendId),
                    builder: (context,
                        AsyncSnapshot<Map<String, dynamic>?> userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const ListTile(
                              title: Text(
                                'Loading...',
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      }

                      if (!userSnapshot.hasData || userSnapshot.data == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const ListTile(
                              title: Text(
                                'User not found',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }

                      final userData = userSnapshot.data!;
                      final username = userData['username'] ?? 'Unknown';
                      final email = userData['email'] ?? 'No Email Provided';
                      final isOnline = userData['online'] ?? false;
                      final inMatch = userData['inMatch'] ?? false;

                      // Visual indicator for online or offline status
                      final onlineStatus = isOnline
                          ? const Icon(Icons.circle,
                              color: Colors.green, size: 14)
                          : const Icon(Icons.circle,
                              color: Colors.red, size: 14);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
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
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.tealAccent.shade700,
                                  child: Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              username,
                                              style: GoogleFonts.robotoMono(
                                                textStyle: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          onlineStatus, // Display online/offline status
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: inMatch
                                      ? null // Disable button if already in a match
                                      : () {
                                          // Trigger the match request on button press
                                          friendService
                                              .sendMatchRequest(friendId)
                                              .then((_) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Match request sent successfully!')),
                                            );
                                          }).catchError((error) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Failed to send match request: $error')),
                                            );
                                          });
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: inMatch
                                        ? Colors.grey
                                        : Colors.teal.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  child: Text(
                                    inMatch ? 'In Match' : 'Start Match',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  // Optional: Implement if you plan to use _startMatch method in the UI
  void _startMatch(BuildContext context, String friendId) async {
    final MatchService matchService = MatchService();
    try {
      // Trigger match creation logic here
      await matchService.createMatch(friendId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match started successfully!')),
      );

      // Navigate to the match page if needed
      // Navigator.pushNamed(context, '/match', arguments: matchId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start match: $e')),
      );
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.deepPurple.shade700,
      title: Text(
        'Play with a Friend',
        style: GoogleFonts.luckiestGuy(
          textStyle: const TextStyle(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ),
      elevation: 4,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }
}
