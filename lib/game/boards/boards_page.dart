import 'package:bingo/game/boards/edit_board_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyBoardsPage extends StatefulWidget {
  const MyBoardsPage({super.key});

  @override
  _MyBoardsPageState createState() => _MyBoardsPageState();
}

class _MyBoardsPageState extends State<MyBoardsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  late CollectionReference boardsRef;

  @override
  void initState() {
    super.initState();
    boardsRef = _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('boards');
  }

  // Function to create a random board if no boards exist
  List<int> generateRandomBoard() {
    List<int> numbers = List.generate(25, (index) => index + 1)..shuffle();
    return numbers;
  }

  // Function to create a new board
  Future<void> createBoard() async {
    List<int> newBoard = generateRandomBoard();
    await boardsRef.add({
      'board': newBoard,
      'selected': false,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New board created')),
    );
  }

  Future<void> selectBoard(String boardId) async {
    // Deselect all boards first
    final allBoards = await boardsRef.get();
    for (var board in allBoards.docs) {
      await boardsRef.doc(board.id).update({'selected': false});
    }

    // Set selected board to true
    await boardsRef.doc(boardId).update({'selected': true});

    // Trigger UI update
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Board selected')),
    );
  }

  // Function to delete a board with confirmation dialog
  Future<void> deleteBoard(String boardId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: const Text('Are you sure you want to delete this board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm) {
      await boardsRef.doc(boardId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Boards"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: boardsRef.orderBy('selected', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading boards.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final boards = snapshot.data!.docs;

          if (boards.isEmpty) {
            // If no boards, generate a random board automatically
            createBoard();
            return const Center(
                child: Text('No boards found, generating one...'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Adjust grid layout based on screen width
              int crossAxisCount;
              double screenWidth = constraints.maxWidth;
              if (screenWidth < 600) {
                crossAxisCount = 1;
              } else if (screenWidth < 900) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 3;
              }

              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  itemCount: boards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final boardData =
                        boards[index].data() as Map<String, dynamic>;
                    final boardId = boards[index].id;
                    final List<int> board = List<int>.from(boardData['board']);
                    final bool isSelected = boardData['selected'] ?? false;

                    return GestureDetector(
                      onTap: () => selectBoard(boardId),
                      child: Card(
                        elevation: isSelected ? 8 : 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected
                              ? const BorderSide(
                                  color: Colors.deepPurple, width: 2)
                              : BorderSide.none,
                        ),
                        color: isSelected
                            ? Colors.deepPurple.shade50
                            : Colors.white,
                        child: Column(
                          children: [
                            // Board Grid
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 4,
                                  ),
                                  itemCount: board.length,
                                  itemBuilder: (context, idx) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.deepPurple),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        board[idx].toString(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple.shade800,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Action Buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Delete Button
                                  IconButton(
                                    onPressed: () => deleteBoard(boardId),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: 'Delete Board',
                                  ),
                                  // Edit Button
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditBoardPage(
                                            boardId: boardId,
                                            board: board,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    tooltip: 'Edit Board',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createBoard,
        backgroundColor: Colors.deepPurple,
        tooltip: 'Create New Board',
        child: const Icon(Icons.add),
      ),
    );
  }
}
