import 'dart:async';

import 'package:bingo/game/bingo_game.dart';
import 'package:bingo/globals.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late User user; // Make user non-final and initialize later

  // Sets to keep track of already handled matches to prevent duplicate pop-ups
  final Set<String> _handledIncomingMatches = {};
  final Set<String> _handledAcceptedMatches = {};
  final Set<String> _handledFinishedMatches = {}; // Track finished matches

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _incomingMatchRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _acceptedMatchRequestsSubscription;
  StreamSubscription<QuerySnapshot>? _finishedMatchesSubscription;
  bool _isDialogShowing = false; // Add this flag to track dialog state

  // Singleton pattern
  static final MatchService _instance = MatchService._internal();

  factory MatchService() {
    return _instance;
  }

  MatchService._internal();

  /// Initialize the MatchService with the authenticated user
  void initialize(User currentUser) {
    user = currentUser;
    _setupIncomingMatchRequestsListener();
    _setupAcceptedMatchRequestsListener();
    _setupFinishedMatchesListener(); // New listener for finished matches
  }

  /// Listener for incoming match requests
  void _setupIncomingMatchRequestsListener() {
    _incomingMatchRequestsSubscription = _firestore
        .collection('matches')
        .where('guest', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          String matchId = docChange.doc.id;
          // Check if the match has already been handled (accepted, rejected, or finished)
          if (!_handledIncomingMatches.contains(matchId) && !_isDialogShowing) {
            _handledIncomingMatches.add(matchId);
            _showIncomingMatchRequestDialog(docChange.doc);
          }
        }
      }
    });
  }

  /// Listener for accepted matches
  void _setupAcceptedMatchRequestsListener() {
    _acceptedMatchRequestsSubscription = _firestore
        .collection('matches')
        .where('host', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        String matchId = docChange.doc.id;

        // Skip if the match is already handled
        if (_handledAcceptedMatches.contains(matchId) || _isDialogShowing)
          continue;

        if (docChange.type == DocumentChangeType.added) {
          _handledAcceptedMatches.add(matchId);
          _showMatchAcceptedDialog(docChange.doc);
        }
      }
    });
  }

  void _setupFinishedMatchesListener() {
    _finishedMatchesSubscription = _firestore
        .collection('matches')
        .where('status', isEqualTo: 'finished')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        String matchId = docChange.doc.id;

        // Check if this match has already been handled
        if (_handledFinishedMatches.contains(matchId) || _isDialogShowing)
          continue;

        if (docChange.type == DocumentChangeType.modified) {
          _handledFinishedMatches.add(matchId);
          _showFinishedMatchDialog(docChange.doc);
        }
      }
    });
  }

  Future<void> _showFinishedMatchDialog(DocumentSnapshot matchDoc) async {
    if (_isDialogShowing) return; // Prevent showing another dialog

    _isDialogShowing = true; // Set flag to true when dialog is opened

    String matchId = matchDoc.id;
    String? winnerId = matchDoc['winner'];
    String message;

    if (winnerId == user.uid) {
      message = '🎉 Congratulations! You won the match!';
    } else if (winnerId == null) {
      message = 'The match ended in a tie!';
    } else {
      message = '😞 You lost the match. Better luck next time!';
    }

    showDialog(
      context: navigatorKey.currentState!.overlay!.context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Match Finished'),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogShowing = false; // Reset flag
                // Optionally, navigate to dashboard or another screen
                if (navigatorKey.currentState != null) {
                  navigatorKey.currentState!
                      .pushNamedAndRemoveUntil('/dashboard', (route) => false);
                }
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false; // Reset flag when dialog is dismissed
    });
  }

  Future<void> _showIncomingMatchRequestDialog(
      DocumentSnapshot matchDoc) async {
    if (_isDialogShowing) return; // Prevent showing another dialog

    _isDialogShowing = true; // Set flag to true when dialog is opened

    String matchId = matchDoc.id;

    // Fetch the latest match data
    DocumentSnapshot matchSnapshot =
        await _firestore.collection('matches').doc(matchId).get();

    // Check if the match is still pending
    if (!matchSnapshot.exists || matchSnapshot['status'] != 'pending') {
      print('Match $matchId is no longer pending.');
      _isDialogShowing = false; // Reset flag
      return; // Exit if the match is not pending
    }

    String hostId = matchDoc['host'];

    // Fetch host's user data
    DocumentSnapshot hostSnapshot =
        await _firestore.collection('users').doc(hostId).get();
    if (!hostSnapshot.exists) {
      _showSnackBar('Host user not found.');
      _isDialogShowing = false; // Reset flag
      return;
    }

    Map<String, dynamic> hostData = hostSnapshot.data() as Map<String, dynamic>;
    String hostUsername = hostData['username'] ?? 'Unknown';

    // Show dialog using navigatorKey
    showDialog(
      context: navigatorKey.currentState!.overlay!.context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Match Request from $hostUsername'),
          content: const Text('Do you want to accept this match request?'),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await rejectMatch(matchId, hostId);
                  Navigator.of(context, rootNavigator: true)
                      .pop(); // Close the dialog
                  _showSnackBar('Match request rejected.');
                } catch (e) {
                  _showSnackBar('Error rejecting match: $e');
                } finally {
                  _isDialogShowing =
                      false; // Reset flag after closing the dialog
                }
              },
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await acceptMatch(matchId, hostId);
                  Navigator.of(context, rootNavigator: true)
                      .pop(); // Close the dialog
                  if (navigatorKey.currentState != null) {
                    navigatorKey.currentState!
                        .pushNamed('/match', arguments: matchId);
                  }
                } catch (e) {
                  _showSnackBar('Error accepting match: $e');
                } finally {
                  _isDialogShowing =
                      false; // Reset flag after closing the dialog
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false; // Reset flag when dialog is dismissed
    });
  }

  Future<void> _showMatchAcceptedDialog(DocumentSnapshot matchDoc) async {
    if (_isDialogShowing) return; // Prevent showing another dialog

    _isDialogShowing = true; // Set flag to true when dialog is opened

    String matchId = matchDoc.id;
    String guestId = matchDoc['guest'];

    // Verify if the match is still active
    DocumentSnapshot matchSnapshot =
        await _firestore.collection('matches').doc(matchId).get();

    if (!matchSnapshot.exists || matchSnapshot['status'] != 'active') {
      print('Match $matchId is no longer available or active.');
      _isDialogShowing = false; // Reset flag
      return; // Exit early if the match is no longer available or active
    }

    // Fetch guest's user data
    DocumentSnapshot guestSnapshot =
        await _firestore.collection('users').doc(guestId).get();
    if (!guestSnapshot.exists) {
      _showSnackBar('Guest user not found.');
      _isDialogShowing = false; // Reset flag
      return;
    }

    Map<String, dynamic> guestData =
        guestSnapshot.data() as Map<String, dynamic>;
    String guestUsername = guestData['username'] ?? 'Unknown';

    // Show dialog using navigatorKey
    showDialog(
      context: navigatorKey.currentState!.overlay!.context,
      barrierDismissible: false, // Prevent dismissal by tapping outside
      builder: (context) {
        return AlertDialog(
          title: Text('$guestUsername accepted your match request!'),
          content: const Text('Would you like to join the match now?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _showSnackBar('You can join the match anytime.');
                _isDialogShowing = false; // Reset flag
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ensure dialog is closed once
                if (navigatorKey.currentState != null) {
                  navigatorKey.currentState!
                      .pushNamed('/match', arguments: matchId);
                }
                _isDialogShowing = false; // Reset flag
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Join Match'),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false; // Reset flag when dialog is dismissed
    });
  }
// lib/game/match_service.dart

  void resetUnreadMessages(String matchId, String playerId) {
    _firestore
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .where('senderId', isNotEqualTo: playerId)
        .where('seen', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        _firestore
            .collection('matches')
            .doc(matchId)
            .collection('messages')
            .doc(doc.id)
            .update({
          'seen': true,
        });
      }
    }).catchError((e) {
      print('Error resetting unread messages: $e');
    });
  }

  /// Helper function to show a SnackBar
  void _showSnackBar(String message) {
    BuildContext? context = navigatorKey.currentState?.overlay?.context;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      print('SnackBar context is null. Message: $message');
    }
  }

  /// Create a new match with a friend.
  Future<String> createMatch(String friendId) async {
    try {
      DocumentReference matchRef = _firestore.collection('matches').doc();
      String matchId = matchRef.id;

      await matchRef.set({
        'host': user.uid,
        'guest': friendId,
        'players': [user.uid, friendId], // Initialize players array
        'status': 'pending',
        'currentTurn': user.uid,
        'winner': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Initialize host's board
      BingoGame hostGame = BingoGame(matchId: matchId, currentUser: user);
      List<int> hostBoard = (await hostGame.getSelectedOrRandomBoard(user.uid))
          .expand((x) => x)
          .toList();

      await matchRef.collection('players').doc(user.uid).set({
        'board': hostBoard,
        'markedNumbers': [],
        'completedLines': [],
        'bingo': false,
      });

      return matchId;
    } catch (e) {
      print('Error in createMatch: $e');
      rethrow;
    }
  }

  Future<void> joinMatch(String matchId) async {
    try {
      DocumentReference matchRef =
          _firestore.collection('matches').doc(matchId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);

        if (!matchSnapshot.exists) {
          throw Exception('Match does not exist.');
        }

        Map<String, dynamic> matchData =
            matchSnapshot.data() as Map<String, dynamic>;

        // Check if the match is still pending
        if (matchData['status'] != 'pending') {
          // Show notification that the match is not available for joining
          _showSnackBar('Match is no longer pending or available.');

          // Delete the match data since it's no longer valid
          await deleteMatchData(matchId);
          return; // Stop further execution
        }

        if (matchData['host'] == user.uid) {
          throw Exception('You cannot join your own match.');
        }

        String hostId = matchData['host'];
        String guestId = user.uid;

        // **Update the guest and set players array**
        transaction.update(matchRef, {
          'guest': guestId,
          'status': 'active', // Now the match is active
          'players': [hostId, guestId], // Set players array
          'currentTurn': hostId, // Set the turn to host
        });

        // Initialize guest's board
        BingoGame guestGame = BingoGame(matchId: matchId, currentUser: user);
        List<int> guestBoard =
            (await guestGame.getSelectedOrRandomBoard(user.uid))
                .expand((x) => x)
                .toList();

        // Assign guest's board in Firestore
        transaction.set(matchRef.collection('players').doc(user.uid), {
          'board': guestBoard,
          'markedNumbers': [],
          'completedLines': [],
          'bingo': false,
        });
      });

      // **Navigate to the match page**
      navigatorKey.currentState!.pushNamed('/match', arguments: matchId);
    } catch (e) {
      print('Error in joinMatch: $e');
      rethrow;
    }
  }

  Future<void> migrateUsersMatchesWon() async {
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();

    for (var userDoc in usersSnapshot.docs) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      if (!userData.containsKey('matchesWon')) {
        await userDoc.reference.update({
          'matchesWon': 0,
        });
        print('Migrated user ${userDoc.id} to include matchesWon set to 0.');
      }
    }
  }

  Future<void> migrateExistingMatchesPlayersArray() async {
    QuerySnapshot matchesSnapshot =
        await _firestore.collection('matches').get();

    for (var matchDoc in matchesSnapshot.docs) {
      Map<String, dynamic> matchData = matchDoc.data() as Map<String, dynamic>;

      if (!matchData.containsKey('players')) {
        String hostId = matchData['host'];
        String guestId =
            matchData['guest'] ?? 'unknown_guest'; // Handle null guests

        // Update the match document to include the players array
        await matchDoc.reference.update({
          'players': [hostId, guestId],
        });

        print('Migrated match ${matchDoc.id} to include players array.');
      }
    }
  }

  /// Method to accept a match
  Future<void> acceptMatch(String matchId, String guestId) async {
    try {
      DocumentReference matchRef =
          _firestore.collection('matches').doc(matchId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);

        if (!matchSnapshot.exists) throw Exception('Match does not exist.');

        String matchStatus = matchSnapshot['status'];

        // Ensure the match is still pending before accepting
        if (matchStatus != 'pending') {
          _showSnackBar('Match is no longer pending or has been rejected.');
          return;
        }

        String hostId = matchSnapshot['host'];

        // Fetch host's and guest's boards
        BingoGame hostGame = BingoGame(matchId: matchId, currentUser: user);
        List<int> hostBoard = (await hostGame.getSelectedOrRandomBoard(hostId))
            .expand((x) => x)
            .toList();

        BingoGame guestGame = BingoGame(matchId: matchId, currentUser: user);
        List<int> guestBoard =
            (await guestGame.getSelectedOrRandomBoard(guestId))
                .expand((x) => x)
                .toList();

        // **Update match and player data to active**
        transaction.update(matchRef, {
          'status': 'active',
          'currentTurn': hostId,
          'players': [hostId, guestId], // Ensure players array is correct
        });

        transaction.set(matchRef.collection('players').doc(hostId), {
          'board': hostBoard,
          'markedNumbers': [],
          'completedLines': [],
          'bingo': false,
        });

        transaction.set(matchRef.collection('players').doc(guestId), {
          'board': guestBoard,
          'markedNumbers': [],
          'completedLines': [],
          'bingo': false,
        });

        // **Mark the match as handled after it's accepted**
        _handledAcceptedMatches.add(matchId);
      });

      // **Prevent Navigating to MatchPage if Already There**
      if (navigatorKey.currentState!.canPop()) {
        final currentRoute =
            ModalRoute.of(navigatorKey.currentState!.context)?.settings.name;
        final currentArguments =
            ModalRoute.of(navigatorKey.currentState!.context)
                ?.settings
                .arguments;

        if (currentRoute == '/match' && currentArguments == matchId) {
          // Already on the MatchPage for this match, no need to navigate again
          return;
        }
      }

      // **Navigate to the match page**
      navigatorKey.currentState!.pushNamed('/match', arguments: matchId);
    } catch (e) {
      print('Error in acceptMatch: $e');
      rethrow;
    }
  }

  /// Reject a match request by updating match status and ending the match.
  Future<void> rejectMatch(String matchId, String hostId) async {
    try {
      DocumentReference matchRef =
          _firestore.collection('matches').doc(matchId);

      // Update the match status to "rejected"
      await matchRef.update({
        'status': 'rejected',
      });

      // Update users' inMatch status
      await _firestore.collection('users').doc(hostId).update({
        'inMatch': false,
        'currentMatchId': FieldValue.delete(),
      });

      await _firestore.collection('users').doc(user.uid).update({
        'inMatch': false,
        'currentMatchId': FieldValue.delete(),
      });

      // Delay the deletion of match data to ensure UI updates correctly
      Future.delayed(const Duration(seconds: 2), () async {
        await deleteMatchData(matchId);
      });

      print('Match rejected and data deletion scheduled.');
    } catch (e) {
      // **Error Handling:** Log and rethrow the exception
      print('Error in rejectMatch: $e');
      rethrow;
    }
  }

  Future<void> endMatch(String matchId, String winnerId) async {
    try {
      DocumentReference matchRef =
          _firestore.collection('matches').doc(matchId);
      DocumentReference winnerRef =
          _firestore.collection('users').doc(winnerId);

      await _firestore.runTransaction((transaction) async {
        // Step 1: Retrieve the match document
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);

        if (!matchSnapshot.exists) {
          throw Exception('Match does not exist.');
        }

        // Step 2: Update the match status to 'finished' and set the winner
        transaction.update(matchRef, {
          'status': 'finished',
          'winner': winnerId,
        });

        // Step 3: Increment the winner's matchesWon count using FieldValue.increment
        transaction.update(winnerRef, {
          'matchesWon': FieldValue.increment(1),
        });

        // Step 4: Retrieve host and guest IDs from the match document
        String hostId = matchSnapshot['host'];
        String guestId = matchSnapshot['guest'];

        // Step 5: Update both players' inMatch status and remove currentMatchId
        DocumentReference hostRef = _firestore.collection('users').doc(hostId);
        DocumentReference guestRef =
            _firestore.collection('users').doc(guestId);

        transaction.update(hostRef, {
          'inMatch': false,
          'currentMatchId': FieldValue.delete(),
        });
        transaction.update(guestRef, {
          'inMatch': false,
          'currentMatchId': FieldValue.delete(),
        });

        // Step 6: Reset handled match sets to avoid stale pop-ups
        resetHandledSets();

        // Step 7: Dispose of listeners to prevent memory leaks
        dispose();

        // Step 8: Navigate back to the dashboard, clearing the navigation stack
        Navigator.of(navigatorKey.currentContext!).pushNamedAndRemoveUntil(
            '/dashboard', (Route<dynamic> route) => false);

        // Step 9: Schedule deletion of match data after a delay
        Future.delayed(const Duration(seconds: 10), () async {
          await deleteMatchData(matchId);
        });

        print('Match $matchId finished and data deletion scheduled.');
      });
    } catch (e) {
      print('Error in endMatch: $e');
      rethrow; // Rethrow the exception for further handling if necessary
    }
  }

  Future<void> migrateExistingMatches() async {
    QuerySnapshot matchesSnapshot =
        await _firestore.collection('matches').get();

    for (var matchDoc in matchesSnapshot.docs) {
      Map<String, dynamic> matchData = matchDoc.data() as Map<String, dynamic>;

      if (!matchData.containsKey('players')) {
        String hostId = matchData['host'];
        String guestId = matchData['guest'];

        // Update the match document to include the players array
        await matchDoc.reference.update({
          'players': [hostId, guestId],
        });

        print('Migrated match ${matchDoc.id} to include players array.');
      }
    }
  }

  void resetHandledSets() {
    _handledIncomingMatches.clear();
    _handledAcceptedMatches.clear();
    _handledFinishedMatches.clear();
    _isDialogShowing = false; // Reset the dialog flag as well
  }

  Future<void> deleteMatchData(String matchId) async {
    try {
      DocumentReference matchRef =
          _firestore.collection('matches').doc(matchId);

      // Fetch the match to ensure it still exists before deletion
      DocumentSnapshot matchSnapshot = await matchRef.get();
      if (!matchSnapshot.exists) {
        print('Match $matchId already deleted.');
        return;
      }

      // Fetch all the players' documents in the match
      QuerySnapshot playersSnapshot =
          await matchRef.collection('players').get();

      // Delete each player's document
      for (DocumentSnapshot playerDoc in playersSnapshot.docs) {
        await playerDoc.reference.delete();
      }

      // Finally, delete the match document itself
      await matchRef.delete();

      // Remove matchId from handled sets
      _handledIncomingMatches.remove(matchId);
      _handledAcceptedMatches.remove(matchId);
      _handledFinishedMatches.remove(matchId);

      print('Match data deleted for matchId: $matchId');
    } catch (e) {
      print('Error deleting match data: $e');
      rethrow;
    }
  }

  /// Mark a number on the player's board, also marking it for the opponent
  Future<void> markNumber(int number, String matchId, String playerId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Reference to the match document
        DocumentReference matchRef =
            _firestore.collection('matches').doc(matchId);
        DocumentSnapshot matchSnapshot = await transaction.get(matchRef);

        // Verify match existence
        if (!matchSnapshot.exists) {
          throw Exception('Match does not exist.');
        }

        // Extract match data
        Map<String, dynamic> matchData =
            matchSnapshot.data() as Map<String, dynamic>;
        String currentTurn = matchData['currentTurn'];
        String status = matchData['status'];

        // Ensure the match is active
        if (status != 'active') {
          throw Exception('Match is not active.');
        }

        // Ensure it's the player's turn
        if (currentTurn != playerId) {
          throw Exception('It is not your turn.');
        }

        String hostId = matchData['host'];
        String guestId = matchData['guest'];
        String opponentId = hostId == playerId ? guestId : hostId;

        // References to both players
        DocumentReference playerRef =
            matchRef.collection('players').doc(playerId);
        DocumentReference opponentRef =
            matchRef.collection('players').doc(opponentId);

        DocumentSnapshot playerSnapshot = await transaction.get(playerRef);
        DocumentSnapshot opponentSnapshot = await transaction.get(opponentRef);

        // Verify player data existence
        if (!playerSnapshot.exists || !opponentSnapshot.exists) {
          throw Exception('Player data does not exist.');
        }

        // Retrieve and check marked numbers for both players
        List<int> playerMarkedNumbers =
            List<int>.from(playerSnapshot.get('markedNumbers') ?? []);
        List<int> opponentMarkedNumbers =
            List<int>.from(opponentSnapshot.get('markedNumbers') ?? []);

        // Check if the number is already marked by any player
        if (playerMarkedNumbers.contains(number) ||
            opponentMarkedNumbers.contains(number)) {
          throw Exception('Number already marked.');
        }

        // **Step 1:** Mark the number for both players
        transaction.update(playerRef, {
          'markedNumbers': FieldValue.arrayUnion([number]),
        });
        transaction.update(opponentRef, {
          'markedNumbers': FieldValue.arrayUnion([number]),
        });

        print(
            'Number $number marked for Player $playerId and Opponent $opponentId.');

        // Initialize BingoGame instance
        BingoGame gameLogic = BingoGame(matchId: matchId, currentUser: user);

        // **Step 2:** Check for completed lines for the current player
        List<int> playerBoard =
            List<int>.from(playerSnapshot.get('board') ?? []);
        List<String> playerNewCompletedLines = gameLogic.checkCompletedLines(
          playerBoard,
          playerMarkedNumbers + [number],
        );

        if (playerNewCompletedLines.isNotEmpty) {
          transaction.update(playerRef, {
            'completedLines': FieldValue.arrayUnion(playerNewCompletedLines),
          });
          print('Player $playerId completed lines: $playerNewCompletedLines');
        }

        // **Step 3:** Check for completed lines for the opponent
        List<int> opponentBoard =
            List<int>.from(opponentSnapshot.get('board') ?? []);
        List<String> opponentNewCompletedLines = gameLogic.checkCompletedLines(
          opponentBoard,
          opponentMarkedNumbers + [number],
        );

        if (opponentNewCompletedLines.isNotEmpty) {
          transaction.update(opponentRef, {
            'completedLines': FieldValue.arrayUnion(opponentNewCompletedLines),
          });
          print(
              'Opponent $opponentId completed lines: $opponentNewCompletedLines');
        }

        // **Step 4:** Fetch updated completed lines for both players
        List<dynamic> playerCompletedLinesDynamic =
            playerSnapshot.get('completedLines') ?? [];
        List<String> playerCompletedLines =
            List<String>.from(playerCompletedLinesDynamic) +
                playerNewCompletedLines;

        List<dynamic> opponentCompletedLinesDynamic =
            opponentSnapshot.get('completedLines') ?? [];
        List<String> opponentCompletedLines =
            List<String>.from(opponentCompletedLinesDynamic) +
                opponentNewCompletedLines;

        // **Step 5:** Convert to Set to prevent duplicates
        Set<String> playerCompletedLinesSet = playerCompletedLines.toSet();
        Set<String> opponentCompletedLinesSet = opponentCompletedLines.toSet();

        // **Step 6:** Check if any player has achieved Bingo
        bool playerBingo = playerCompletedLinesSet.length >= 5;
        bool opponentBingo = opponentCompletedLinesSet.length >= 5;

        String? winnerId;

        if (playerBingo && !opponentBingo) {
          winnerId = playerId;
        } else if (!playerBingo && opponentBingo) {
          winnerId = opponentId;
        } else if (playerBingo && opponentBingo) {
          // Both have Bingo, decide based on who achieved it first
          // For simplicity, declare the current player as the winner
          winnerId = playerId;
        }

        if (winnerId != null) {
          // **Step 7:** Declare the winner and update match status
          transaction.update(matchRef, {
            'status': 'finished',
            'winner': winnerId,
          });

          // **Step 8:** Update 'bingo' field for both players
          transaction.update(playerRef, {
            'bingo': playerBingo,
          });
          transaction.update(opponentRef, {
            'bingo': opponentBingo,
          });

          print('Winner determined: $winnerId');

          // **Step 9:** Increment the winner's `matchesWon` count
          DocumentReference winnerRef =
              _firestore.collection('users').doc(winnerId);
          transaction.update(winnerRef, {
            'matchesWon': FieldValue.increment(1),
          });

          print('Incremented matchesWon for user: $winnerId');

          // **Step 10:** Exit the transaction as the match is over
          return;
        }

        // **Step 10:** If no winner yet, switch turn to the opponent
        transaction.update(matchRef, {
          'currentTurn': opponentId,
        });

        print('Turn switched to Opponent $opponentId.');
      });
    } catch (e, stacktrace) {
      // **Error Handling:** Log detailed error information for debugging
      print('Error in markNumber: $e');
      print('Stacktrace: $stacktrace');

      // **Optional:** You can handle specific exceptions or show error messages to the user
      // For example, you can throw a custom exception or use a state management solution
      rethrow; // Re-throw the exception after logging
    }
  }

  /// Stream of ongoing matches for the current user.
  Stream<DocumentSnapshot> getMatchStream(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots();
  }

  /// Stream of player's game state.
  Stream<DocumentSnapshot> getPlayerGameState(String matchId, String playerId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .collection('players')
        .doc(playerId)
        .snapshots();
  }

  /// Method to declare a match as a tie and end the match
  Future<void> declareTie(String matchId, String playerId) async {
    try {
      DocumentReference matchRef =
          _firestore.collection('matches').doc(matchId);

      // Update the match status to 'finished' and set both players as not the winner (i.e., a tie)
      await matchRef.update({
        'status': 'finished',
        'winner': null, // No winner since it's a tie
      });

      // Fetch the players in the match
      QuerySnapshot playersSnapshot =
          await matchRef.collection('players').get();

      // Update both players' `inMatch` status to false and remove the current match ID
      for (var doc in playersSnapshot.docs) {
        String playerId = doc.id;
        await _firestore.collection('users').doc(playerId).update({
          'inMatch': false,
          'currentMatchId': FieldValue.delete(),
        });
      }

      // Optionally, you can also clean up the match data after a delay if necessary
      Future.delayed(const Duration(seconds: 10), () async {
        await deleteMatchData(matchId);
      });

      print('Match $matchId declared as a tie and finished.');
    } catch (e) {
      print('Error in declaring a tie: $e');
      rethrow;
    }
  }

  /// Dispose function to cancel subscriptions (call when app is terminating)
  void dispose() {
    _incomingMatchRequestsSubscription?.cancel();
    _acceptedMatchRequestsSubscription?.cancel();
    _finishedMatchesSubscription?.cancel();
  }
}
