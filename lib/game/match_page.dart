// lib/pages/match_page.dart

import 'package:bingo/game/bingo_game.dart';
import 'package:bingo/game/chat/chat_widget.dart';
import 'package:bingo/game/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MatchPage extends StatefulWidget {
  const MatchPage({super.key});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  String? matchId;
  late String playerId;
  late String opponentId;
  late BingoGame bingoGame;
  final MatchService matchService = MatchService();
  late User currentUser;
  List<List<int>> playerBoard = [];
  bool isChatVisible = false;
  bool hasUnreadMessages = false;
  bool isMatchFinished = false;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser!;
    playerId = currentUser.uid;
    _loadTheme();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchService.initialize(currentUser);
      _loadMatchId();
      _listenForNewMessages();
    });
  }

  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = !isDarkMode;
      prefs.setBool('isDarkMode', isDarkMode);
    });
  }

  Future<void> _saveMatchId(String matchId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_match_id', matchId);
    print('Match ID saved: $matchId');
  }

  @override
  void dispose() {
    print('MatchPage dispose called.');

    if (!isMatchFinished && matchId != null) {
      print('Match is not finished. Declaring tie and deleting match data.');
      _declareTie();
      _deleteMatchOnLeave();
    }
    matchService.dispose();

    super.dispose();
  }

  Future<void> _declareTie() async {
    if (matchId != null) {
      await matchService.declareTie(matchId!, playerId);
      print('Declared tie for matchId: $matchId');
    }
  }

  Future<void> _deleteMatchOnLeave() async {
    await matchService.deleteMatchData(matchId!);
    print('Match deleted as player left the screen.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is String) {
      if (matchId == args) {
        print('Already on MatchPage for matchId: $matchId');
        return;
      }

      matchId = args;
      print('Match ID received: $matchId');

      _saveMatchId(matchId!);

      FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get()
          .then((snapshot) async {
        if (snapshot.exists) {
          Map<String, dynamic> matchData =
              snapshot.data() as Map<String, dynamic>;
          String hostId = matchData['host'];
          String guestId = matchData['guest'];

          opponentId = playerId == hostId ? guestId : hostId;

          await _initializeBoard(currentUser.uid);

          setState(() {});
          print('Opponent ID set to: $opponentId');
        } else {
          _showErrorAndExit('Match data not found.');
        }
      }).catchError((error) {
        _showErrorAndExit('Error fetching match data: $error');
      });

      bingoGame = BingoGame(matchId: matchId!, currentUser: currentUser);
      print('BingoGame initialized for matchId: $matchId');
    } else {
      _showErrorAndExit('Invalid match ID.');
    }
  }

  void _showErrorAndExit(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
    print('Error: $message');
  }

  void _loadMatchId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    matchId = prefs.getString('current_match_id');

    if (matchId != null && matchId!.isNotEmpty) {
      print('Loaded matchId from preferences: $matchId');
      _loadMatchData();
    } else {
      _showErrorAndExit('Invalid or missing match ID.');
    }
  }

  Future<void> _loadMatchData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();

      if (snapshot.exists) {
        final matchData = snapshot.data() as Map<String, dynamic>;
        String hostId = matchData['host'];
        String guestId = matchData['guest'];

        opponentId = playerId == hostId ? guestId : hostId;
        bingoGame = BingoGame(matchId: matchId!, currentUser: currentUser);
        print('BingoGame re-initialized for matchId: $matchId');

        await _initializeBoard(playerId);

        _listenForNewMessages();

        setState(() {});
        print('Match data loaded successfully.');
      } else {
        _showErrorAndExit('Match data not found.');
      }
    } catch (error) {
      _showErrorAndExit('Error fetching match data: $error');
    }
  }

  Future<void> _initializeBoard(String userId) async {
    playerBoard = await bingoGame.getSelectedOrRandomBoard(userId);
    setState(() {});
    print('Player board initialized for userId: $userId');
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

  void _listenForNewMessages() {
    FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .snapshots()
        .listen((snapshot) {
      if (!isChatVisible) {
        final newMessages = snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.added)
            .toList();

        if (newMessages.isNotEmpty) {
          setState(() {
            hasUnreadMessages = true;
          });
          print('New unread messages detected.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (matchId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bingo Match'),
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              color:
                  isDarkMode ? Colors.black : Colors.white, // Adjust this line
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: matchService.getMatchStream(matchId!),
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

                if (status == 'finished') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !isMatchFinished) {
                      setState(() {
                        isMatchFinished = true;
                      });
                      Navigator.popUntil(
                          context, ModalRoute.withName('/dashboard'));
                      String message;
                      if (winnerId == playerId) {
                        message = '🎉 Congratulations! You won the match!';
                      } else if (winnerId == opponentId) {
                        message =
                            '😞 You lost the match. Better luck next time!';
                      } else {
                        message = 'The match ended in a tie!';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                      print('Match finished. Navigated to dashboard.');
                    }
                  });
                  return Container(); // Prevent building the rest of the UI
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
                              fontSize: 20,
                              color: status == 'active'
                                  ? (currentTurn == playerId
                                      ? Colors.green
                                      : Colors.red)
                                  : (winnerId == playerId
                                      ? Colors.blue
                                      : (winnerId == opponentId
                                          ? Colors.orange
                                          : Colors.purple)),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: matchService.getPlayerGameState(
                                matchId!, playerId),
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
                                  playerSnapshot.data!.data()
                                      as Map<String, dynamic>;
                              List<int> board =
                                  List<int>.from(playerData['board'] ?? []);
                              List<int> markedNumbers = List<int>.from(
                                  playerData['markedNumbers'] ?? []);
                              List<String> completedLines = List<String>.from(
                                  playerData['completedLines'] ?? []);
                              bool hasBingo = playerData['bingo'] ?? false;

                              return SingleChildScrollView(
                                child: Column(
                                  children: [
                                    const Text(
                                      'Your Board',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildBoard(
                                      board,
                                      markedNumbers,
                                      completedLines,
                                      status == 'active' &&
                                          currentTurn == playerId,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Completed Lines: ${completedLines.length}/5',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    if (hasBingo)
                                      const Text(
                                        '🎉 You have achieved Bingo!',
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.blue),
                                      ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _showEndMatchDialog();
                                      },
                                      icon: const Icon(Icons.exit_to_app),
                                      label: const Text('End Match'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade400,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        textStyle: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
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
            // Floating chat widget at the bottom-right corner
            if (isChatVisible)
              Positioned(
                bottom: 80,
                right: 16,
                child: _buildChatWidget(isHalfScreen: true),
              ),
            // Button to toggle chat visibility
            Positioned(
              bottom: isChatVisible ? 240 : 16,
              right: 16,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        isChatVisible = !isChatVisible;
                        if (isChatVisible) {
                          hasUnreadMessages = false;
                        }
                      });
                      print('Chat visibility toggled: $isChatVisible');
                    },
                    backgroundColor:
                        isChatVisible ? Colors.red : Colors.tealAccent.shade700,
                    child: Icon(isChatVisible ? Icons.close : Icons.chat),
                  ),
                  if (hasUnreadMessages && !isChatVisible)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  Widget _buildChatWidget({bool isHalfScreen = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey.shade800.withOpacity(0.95)
            : Colors.tealAccent.shade100.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      width: isHalfScreen
          ? MediaQuery.of(context).size.width * 0.6
          : MediaQuery.of(context).size.width * 0.8,
      height: isHalfScreen
          ? MediaQuery.of(context).size.height * 0.5
          : MediaQuery.of(context).size.height * 0.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ChatWidget(
          matchId: matchId!,
          playerId: playerId,
        ),
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
        double size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        double cellSize = (size - 32) / 5;

        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: 25,
            itemBuilder: (context, index) {
              int number = board[index];
              bool isMarked = markedNumbers.contains(number);

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
                              number, matchId!, playerId);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isMarked
                        ? Colors.green.shade400
                        : isInCompletedLine
                            ? Colors.blueAccent.shade100
                            : isDarkMode
                                ? Colors.grey.shade800
                                : Colors.white,
                    border: Border.all(
                        color:
                            isDarkMode ? Colors.grey.shade700 : Colors.black26),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (isMarked || isInCompletedLine)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isMarked || isInCompletedLine
                          ? Colors.white
                          : isDarkMode
                              ? Colors.white
                              : Colors.black87,
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
                print('End Match dialog canceled.');
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('End Match'),
              onPressed: () async {
                Navigator.of(context).pop();

                Map<String, int> linesData =
                    await _fetchPlayerAndOpponentLines();

                if (linesData['playerLines']! >= 5 &&
                    linesData['opponentLines']! < 5) {
                  await matchService.endMatch(matchId!, playerId);
                } else if (linesData['opponentLines']! >= 5 &&
                    linesData['playerLines']! < 5) {
                  await matchService.endMatch(matchId!, opponentId);
                } else if (linesData['playerLines']! >= 5 &&
                    linesData['opponentLines']! >= 5) {
                  await matchService.declareTie(matchId!, playerId);
                } else {
                  await matchService.declareTie(matchId!, playerId);
                }

                setState(() {
                  isMatchFinished = true;
                });
                print('Match ended by user.');
              },
            ),
          ],
        );
      },
    );
  }
}
