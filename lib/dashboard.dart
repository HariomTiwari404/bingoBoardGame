// lib/pages/dashboard_page.dart

import 'package:bingo/game/leaderboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Define a scaling factor based on the screen width
    final double scaleFactor =
        screenWidth < 350 ? 0.8 : (screenWidth < 450 ? 0.9 : 1.0);

    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      appBar: _buildAppBar(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('users').doc(currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text(
              'Error loading user data.',
              style: TextStyle(color: Colors.white),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(
                child: Text(
              'User data not found.',
              style: TextStyle(color: Colors.white),
            ));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final bool inMatch = userData?['inMatch'] ?? false;
          final String? currentMatchId = userData?['currentMatchId'];
          final String username = userData?['username'] ?? 'Player';
          final int matchesWon = userData?['matchesWon'] ?? 0;

          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1c1c1c), Color(0xFF3a3a3a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildAnimatedTitle(context),
                      SizedBox(height: 30 * scaleFactor),
                      _buildProfileSection(username, matchesWon, scaleFactor),
                      SizedBox(height: 40 * scaleFactor),
                      _buildGridButtons(context, scaleFactor, screenWidth),
                      SizedBox(height: 40 * scaleFactor),
                      _buildOngoingMatchSection(
                          context, inMatch, currentMatchId, screenWidth),
                      SizedBox(height: 40 * scaleFactor),
                      _buildActiveMatches(firestore, currentUserId, context,
                          scaleFactor, screenWidth),
                      SizedBox(height: 40 * scaleFactor),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Building the AppBar with dark theme and logout button only
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        'Bingo Dashboard',
        style: GoogleFonts.oswald(
          textStyle: const TextStyle(
            fontSize: 28,
            letterSpacing: 2,
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

  // Animated Title with GTA V inspired styling
  Widget _buildAnimatedTitle(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Define a scaling factor for the title based on the screen width
    final double titleScaleFactor = screenWidth < 350
        ? 0.7
        : (screenWidth < 450 ? 0.9 : 1.0); // Adjust as needed

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1, end: 1.05),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.red, Colors.orange, Colors.yellow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              '🎲 B I N G O 🎲',
              textAlign: TextAlign.center,
              style: GoogleFonts.bangers(
                textStyle: TextStyle(
                  fontSize: 50 * titleScaleFactor,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black54,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Building the profile section
  Widget _buildProfileSection(
      String username, int matchesWon, double scaleFactor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(5, 5),
              ),
            ],
            border: Border.all(
              color: Colors.tealAccent,
              width: 2,
            ),
          ),
          padding: EdgeInsets.all(20 * scaleFactor),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30 * scaleFactor,
                backgroundColor: Colors.tealAccent.shade700,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'P',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24 * scaleFactor),
                ),
              ),
              SizedBox(width: 20 * scaleFactor),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.robotoMono(
                        textStyle: TextStyle(
                          fontSize: 24 * scaleFactor,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 5 * scaleFactor),
                    Text(
                      'Matches Won: $matchesWon',
                      style: GoogleFonts.robotoMono(
                        textStyle: TextStyle(
                          fontSize: 18 * scaleFactor,
                          color: Colors.white70,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Building the grid of buttons with GTA V aesthetic
  Widget _buildGridButtons(
      BuildContext context, double scaleFactor, double screenWidth) {
    // Determine crossAxisCount based on screen width
    int crossAxisCount = screenWidth < 400 ? 1 : 2;

    // Adjust childAspectRatio dynamically
    double childAspectRatio = screenWidth < 400 ? 2.5 : 1.5;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16 * scaleFactor,
      mainAxisSpacing: 16 * scaleFactor,
      childAspectRatio: childAspectRatio,
      children: <Widget>[
        _buildGameButton(
          icon: Icons.play_arrow,
          label: 'Play with a Friend',
          onPressed: () {
            Navigator.pushNamed(context, '/play_with_friend');
          },
          backgroundColor: Colors.grey.shade900,
          textColor: Colors.white,
          scaleFactor: scaleFactor,
        ),
        _buildGameButton(
          icon: Icons.people,
          label: 'Friends',
          onPressed: () {
            Navigator.pushNamed(context, '/friends');
          },
          backgroundColor: Colors.grey.shade900,
          textColor: Colors.white,
          scaleFactor: scaleFactor,
        ),
        _buildGameButton(
          icon: Icons.leaderboard,
          label: 'Leaderboard',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LeaderboardPage()),
            );
          },
          backgroundColor: Colors.grey.shade900,
          textColor: Colors.white,
          scaleFactor: scaleFactor,
        ),
        _buildGameButton(
          icon: Icons.view_list,
          label: 'My Boards',
          onPressed: () {
            Navigator.pushNamed(context, '/my_boards');
          },
          backgroundColor: Colors.grey.shade900,
          textColor: Colors.white,
          scaleFactor: scaleFactor,
        ),
      ],
    );
  }

  // Building individual game buttons with elevated design and hover effects
  Widget _buildGameButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    double scaleFactor = 1.0,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(5, 5),
              ),
            ],
            border: Border.all(
              color: Colors.tealAccent,
              width: 2,
            ),
          ),
          padding: EdgeInsets.all(20 * scaleFactor),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 50 * scaleFactor,
                color: textColor,
              ),
              SizedBox(height: 10 * scaleFactor),
              Text(
                label,
                style: GoogleFonts.robotoMono(
                  textStyle: TextStyle(
                    fontSize: 20 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Building the ongoing match section with GTA V style
  Widget _buildOngoingMatchSection(
      BuildContext context, bool inMatch, String? matchId, double screenWidth) {
    if (!inMatch || matchId == null) {
      return const Text(
        'No ongoing match',
        style: TextStyle(fontSize: 18, color: Colors.white70),
      );
    }

    // Calculate button width based on screen size
    double buttonWidth = screenWidth < 300 ? screenWidth * 0.8 : 250;
    double buttonHeight = 60;

    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/match',
            arguments: matchId,
          );
        },
        icon: const Icon(Icons.gamepad),
        label: const Text('Continue Ongoing Match'),
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 10,
        ),
      ),
    );
  }

  // Building the active matches list with GTA V aesthetics
  Widget _buildActiveMatches(FirebaseFirestore firestore, String userId,
      BuildContext context, double scaleFactor, double screenWidth) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('matches')
          .where('status', isEqualTo: 'active')
          .where('players', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Error loading matches.',
            style: TextStyle(color: Colors.white),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No active matches found',
            style: TextStyle(color: Colors.white),
          );
        }

        final matches = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Matches',
              style: GoogleFonts.oswald(
                textStyle: const TextStyle(
                  fontSize: 24,
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 10 * scaleFactor),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                final matchData = match.data() as Map<String, dynamic>;
                final matchId = match.id;
                final opponentId = matchData['host'] == userId
                    ? matchData['guest']
                    : matchData['host'];

                return Card(
                  margin: EdgeInsets.symmetric(
                      vertical: 8.0 * scaleFactor, horizontal: 0.0),
                  color: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.tealAccent.shade700,
                      child: Text(
                        opponentId != null && opponentId.isNotEmpty
                            ? opponentId[0].toUpperCase()
                            : 'O',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(
                      'Match vs ${opponentId ?? "Opponent"}',
                      style: GoogleFonts.robotoMono(
                        textStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text(
                      'Tap to join',
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing:
                        const Icon(Icons.play_arrow, color: Colors.tealAccent),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/match',
                        arguments: matchId,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
