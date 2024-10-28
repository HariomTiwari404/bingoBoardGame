import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BingoGame {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User currentUser;
  final String matchId;

  BingoGame({required this.matchId, required this.currentUser});

  /// Generates a random 5x5 Bingo board with numbers between 1 and 25.
  List<List<int>> generateRandomBoard() {
    List<int> numbers = List<int>.generate(25, (index) => index + 1)..shuffle();
    List<List<int>> board = [];
    for (int i = 0; i < 5; i++) {
      board.add(numbers.sublist(i * 5, (i + 1) * 5));
    }
    return board;
  }

  /// Fetches the selected board for the current player or generates a random one if none is selected.
  Future<List<List<int>>> getSelectedOrRandomBoard(String userId) async {
    final boardsRef = _firestore
        .collection('users')
        .doc(userId) // Fetch board for the specific userId (host or guest)
        .collection('boards');

    // Query for the selected board
    final QuerySnapshot selectedBoardSnapshot =
        await boardsRef.where('selected', isEqualTo: true).limit(1).get();

    if (selectedBoardSnapshot.docs.isNotEmpty) {
      // If a selected board exists, use it
      List<int> selectedBoard =
          List<int>.from(selectedBoardSnapshot.docs.first['board']);
      return _recreateBoard(selectedBoard); // Convert it to 5x5 format
    } else {
      // If no selected board, generate a random one
      return generateRandomBoard();
    }
  }

  /// Recreates a 5x5 board from a flattened list.
  List<List<int>> _recreateBoard(List<int> flattenedBoard) {
    List<List<int>> board = [];
    for (int i = 0; i < 5; i++) {
      board.add(flattenedBoard.sublist(i * 5, (i + 1) * 5));
    }
    return board;
  }

  /// Checks for completed lines (rows, columns, diagonals).
  List<String> checkCompletedLines(List<int> board, List<int> markedNumbers) {
    List<String> completedLines = [];

    // Recreate 5x5 board
    List<List<int>> board2D = _recreateBoard(board);

    // Check rows
    for (int i = 0; i < 5; i++) {
      if (board2D[i].every((number) => markedNumbers.contains(number))) {
        completedLines.add('row$i');
      }
    }

    // Check columns
    for (int col = 0; col < 5; col++) {
      bool columnComplete = true;
      for (int row = 0; row < 5; row++) {
        if (!markedNumbers.contains(board2D[row][col])) {
          columnComplete = false;
          break;
        }
      }
      if (columnComplete) {
        completedLines.add('col$col');
      }
    }

    // Check diagonals
    bool diag1Complete = true;
    bool diag2Complete = true;
    for (int i = 0; i < 5; i++) {
      if (!markedNumbers.contains(board2D[i][i])) {
        diag1Complete = false;
      }
      if (!markedNumbers.contains(board2D[i][4 - i])) {
        diag2Complete = false;
      }
    }
    if (diag1Complete) {
      completedLines.add('diag1');
    }
    if (diag2Complete) {
      completedLines.add('diag2');
    }

    return completedLines;
  }
}
