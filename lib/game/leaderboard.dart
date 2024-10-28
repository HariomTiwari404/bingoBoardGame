// lib/game/leaderboard.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor =
        screenWidth < 350 ? 0.8 : (screenWidth < 450 ? 0.9 : 1.0);

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for consistency
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('users')
              .orderBy('matchesWon', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Error loading leaderboard.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = snapshot.data!.docs;

            if (users.isEmpty) {
              return const Center(
                child: Text(
                  'No players found.',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1c1c1c), Color(0xFF3a3a3a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16.0 * scaleFactor,
                    vertical: 20.0 * scaleFactor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeaderboardHeader(scaleFactor),
                    SizedBox(height: 20 * scaleFactor),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user =
                              users[index].data() as Map<String, dynamic>;
                          final username = user['username'] ?? 'Player';
                          final matchesWon = user['matchesWon'] ?? 0;

                          return _buildLeaderboardItem(
                              index + 1, username, matchesWon, scaleFactor);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Building the AppBar with dark theme and logout button
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        'Leaderboard',
        style: GoogleFonts.oswald(
          textStyle: const TextStyle(
            fontSize: 24,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ],
    );
  }

  // Building the leaderboard header
  Widget _buildLeaderboardHeader(double scaleFactor) {
    return Text(
      'Top Players',
      style: GoogleFonts.bangers(
        textStyle: TextStyle(
          fontSize: 32 * scaleFactor,
          color: Colors.tealAccent,
          shadows: const [
            Shadow(
              blurRadius: 5.0,
              color: Colors.black54,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
    );
  }

  // Building individual leaderboard items
  Widget _buildLeaderboardItem(
      int rank, String username, int matchesWon, double scaleFactor) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.0 * scaleFactor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey.shade800,
      elevation: 4,
      child: ListTile(
        leading: _buildRankBadge(rank),
        title: Text(
          username,
          style: GoogleFonts.robotoMono(
            textStyle: TextStyle(
              fontSize: 20 * scaleFactor,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
            ),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$matchesWon Wins',
          style: TextStyle(
            fontSize: 16 * scaleFactor,
            color: Colors.white70,
          ),
        ),
        trailing: CircleAvatar(
          backgroundColor: Colors.purple.shade300,
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : 'P',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  // Building rank badges for top players
  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    switch (rank) {
      case 1:
        badgeColor = Colors.amber.shade700;
        break;
      case 2:
        badgeColor = Colors.grey.shade400;
        break;
      case 3:
        badgeColor = Colors.brown.shade400;
        break;
      default:
        badgeColor = Colors.transparent;
    }

    if (rank <= 3) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: badgeColor,
        child: Text(
          rank.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white70,
        ),
      );
    }
  }
}
