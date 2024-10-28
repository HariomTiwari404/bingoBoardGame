// lib/pages/match_page.dart

import 'package:bingo/game/bingo_game.dart';
import 'package:bingo/game/chat/chat_widget.dart';
import 'package:bingo/game/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchPage extends StatefulWidget {
  const MatchPage({super.key});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  late String matchId;
  late String playerId;
  late String opponentId;
  late BingoGame bingoGame;
  final MatchService matchService = MatchService();
  late User currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      matchId = args;
      playerId = currentUser.uid;

      // Fetch match data to determine the opponentId
      FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get()
          .then((snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> matchData =
              snapshot.data() as Map<String, dynamic>;
          String hostId = matchData['host'];
          String guestId = matchData['guest'];

          // Determine the opponentId based on the current player
          if (playerId == hostId) {
            opponentId = guestId;
          } else {
            opponentId = hostId;
          }

          // Call setState to ensure opponentId is updated
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match data not found.')),
          );
          Navigator.pop(context);
        }
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching match data: $error')),
        );
        Navigator.pop(context);
      });

      bingoGame = BingoGame(matchId: matchId, currentUser: currentUser);
      _fetchPlayerAndOpponentLines();
    } else {
      // Handle invalid match ID
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid match ID.')),
      );
      Navigator.pop(context);
    }
  }

  Future<Map<String, int>> _fetchPlayerAndOpponentLines() async {
    DocumentSnapshot playerSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('players')
        .doc(playerId)
        .get();

    DocumentSnapshot opponentSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('players')
        .doc(opponentId)
        .get();

    if (!playerSnapshot.exists || !opponentSnapshot.exists) {
      throw Exception('Player or opponent data not found.');
    }

    Map<String, dynamic> playerData =
        playerSnapshot.data() as Map<String, dynamic>;
    Map<String, dynamic> opponentData =
        opponentSnapshot.data() as Map<String, dynamic>;

    List<String> playerCompletedLines =
        List<String>.from(playerData['completedLines'] ?? []);
    List<String> opponentCompletedLines =
        List<String>.from(opponentData['completedLines'] ?? []);

    return {
      'playerLines': playerCompletedLines.length,
      'opponentLines': opponentCompletedLines.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bingo Match'),
        backgroundColor: Colors.tealAccent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: matchService.getMatchStream(matchId),
        builder: (context, matchSnapshot) {
          if (matchSnapshot.hasError) {
            return const Center(child: Text('Error loading match data.'));
          }

          if (matchSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!matchSnapshot.data!.exists) {
            return const Center(child: Text('Match not found.'));
          }

          Map<String, dynamic> matchData =
              matchSnapshot.data!.data() as Map<String, dynamic>;
          String currentTurn = matchData['currentTurn'] ?? '';
          String status = matchData['status'] ?? 'unknown';
          String? winnerId = matchData['winner'];

          // If match is finished, navigate back with a message
          if (status == 'finished') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.popUntil(context, ModalRoute.withName('/dashboard'));
                String message;
                if (winnerId == playerId) {
                  message = '🎉 Congratulations! You won the match!';
                } else if (winnerId == opponentId) {
                  message = '😞 You lost the match. Better luck next time!';
                } else {
                  message = 'The match ended in a tie!';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      status == 'active'
                          ? (currentTurn == playerId
                              ? "It's your turn!"
                              : "Waiting for opponent's turn...")
                          : (winnerId != null
                              ? (winnerId == playerId
                                  ? "🎉 You won the match!"
                                  : (winnerId == opponentId
                                      ? "😞 You lost the match."
                                      : "The match ended in a tie!"))
                              : "Match status: $status"),
                      style: TextStyle(
                        fontSize: 18,
                        color: status == 'active'
                            ? (currentTurn == playerId
                                ? Colors.green
                                : Colors.red)
                            : (winnerId == playerId
                                ? Colors.blue
                                : (winnerId == opponentId
                                    ? Colors.orange
                                    : Colors.purple)),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Integrating ChatWidget here
                  ChatWidget(
                    matchId: matchId,
                    playerId: playerId,
                  ),

                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream:
                          matchService.getPlayerGameState(matchId, playerId),
                      builder: (context, playerSnapshot) {
                        if (playerSnapshot.hasError) {
                          return const Center(
                              child: Text('Error loading game data.'));
                        }

                        if (playerSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!playerSnapshot.data!.exists) {
                          return const Center(
                              child: Text('Player data not found.'));
                        }

                        Map<String, dynamic> playerData =
                            playerSnapshot.data!.data() as Map<String, dynamic>;
                        List<int> board =
                            List<int>.from(playerData['board'] ?? []);
                        List<int> markedNumbers =
                            List<int>.from(playerData['markedNumbers'] ?? []);
                        List<String> completedLines = List<String>.from(
                            playerData['completedLines'] ?? []);
                        bool hasBingo = playerData['bingo'] ?? false;

                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              const Text(
                                'Your Board',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _buildBoard(
                                board,
                                markedNumbers,
                                completedLines,
                                status == 'active' && currentTurn == playerId,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Completed Lines: ${completedLines.length}/5',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (hasBingo)
                                const Text(
                                  '🎉 You have achieved Bingo!',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.blue),
                                ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  _showEndMatchDialog();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('End Match'),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBoard(
    List<int> board,
    List<int> markedNumbers,
    List<String> completedLines,
    bool isYourTurn,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine the minimum dimension to maintain square cells
        double size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        // Calculate cell size based on the grid size
        double cellSize =
            (size - 32) / 5; // 32 accounts for padding (16 on each side)

        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(), // Disable scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // 5x5 grid
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1, // Make cells square
            ),
            itemCount: 25,
            itemBuilder: (context, index) {
              int number = board[index];
              bool isMarked = markedNumbers.contains(number);

              // Determine if part of a completed line
              bool isInCompletedLine = false;
              for (String line in completedLines) {
                if (line.startsWith('row')) {
                  int row = int.parse(line.substring(3));
                  if (index ~/ 5 == row) {
                    isInCompletedLine = true;
                    break;
                  }
                } else if (line.startsWith('col')) {
                  int col = int.parse(line.substring(3));
                  if (index % 5 == col) {
                    isInCompletedLine = true;
                    break;
                  }
                } else if (line == 'diag1' && index ~/ 5 == index % 5) {
                  isInCompletedLine = true;
                  break;
                } else if (line == 'diag2' && index ~/ 5 + index % 5 == 4) {
                  isInCompletedLine = true;
                  break;
                }
              }

              return GestureDetector(
                onTap: isYourTurn && !isMarked && !isInCompletedLine
                    ? () async {
                        try {
                          await matchService.markNumber(
                              number, matchId, playerId);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    : null,
                child: Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: isMarked
                        ? Colors.green
                        : isInCompletedLine
                            ? Colors.blueAccent
                            : Colors.white,
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isMarked || isInCompletedLine
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Shows a dialog to confirm ending the match.
  void _showEndMatchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Match'),
          content: const Text('Are you sure you want to end this match?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('End Match'),
              onPressed: () async {
                Navigator.of(context).pop();
                await matchService.endMatch(matchId, playerId);
              },
            ),
          ],
        );
      },
    );
  }
}
