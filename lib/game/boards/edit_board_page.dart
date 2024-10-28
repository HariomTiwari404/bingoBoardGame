import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditBoardPage extends StatefulWidget {
  final String boardId;
  final List<int> board;

  const EditBoardPage({required this.boardId, required this.board, super.key});

  @override
  _EditBoardPageState createState() => _EditBoardPageState();
}

class _EditBoardPageState extends State<EditBoardPage> {
  late List<TextEditingController> controllers;
  late List<String?> errorTexts; // To store error messages for each field
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize text controllers and error texts for each board cell
    controllers = List.generate(
      25,
      (index) => TextEditingController(text: widget.board[index].toString()),
    );
    errorTexts = List.generate(25, (index) => null);

    // Add listeners to detect real-time duplicates
    for (int i = 0; i < controllers.length; i++) {
      controllers[i].addListener(() => validateField(i));
    }
  }

  @override
  void dispose() {
    // Dispose of the controllers when the page is closed
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Function to validate individual fields for duplicates
  void validateField(int index) {
    String? error;
    String currentValue = controllers[index].text;

    if (currentValue.isEmpty) {
      error = 'Required';
    } else {
      final int? num = int.tryParse(currentValue);
      if (num == null) {
        error = 'Invalid';
      } else if (num < 1 || num > 25) {
        error = '1-25';
      } else {
        // Check for duplicates
        int duplicateCount = controllers
            .where((controller) => controller.text == currentValue)
            .length;
        if (duplicateCount > 1) {
          error = 'Duplicate';
        }
      }
    }

    setState(() {
      errorTexts[index] = error;
    });
  }

  Future<void> saveEditedBoard() async {
    // First, validate all fields
    bool isValid = true;
    for (int i = 0; i < controllers.length; i++) {
      validateField(i);
      if (errorTexts[i] != null) {
        isValid = false;
      }
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please resolve all errors before saving.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Convert controllers into a list of integers
    List<int> newBoard = controllers.map((controller) {
      int? num = int.tryParse(controller.text);
      return num ?? 0; // Use 0 as default if input is invalid
    }).toList();

    // Additional duplicate check to ensure data integrity
    if (newBoard.toSet().length != newBoard.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board cannot have duplicate numbers.')),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Save the edited board to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('boards')
          .doc(widget.boardId)
          .update({
        'board': newBoard,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board saved successfully')),
      );

      // Go back to the previous page
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving board: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String? validateNumber(String? value, int index) {
    if (value == null || value.isEmpty) {
      return 'Required';
    }
    final intValue = int.tryParse(value);
    if (intValue == null) {
      return 'Invalid';
    }
    if (intValue < 1 || intValue > 25) {
      return '1-25';
    }
    // Check for duplicates
    int duplicateCount =
        controllers.where((controller) => controller.text == value).length;
    if (duplicateCount > 1) {
      return 'Duplicate';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the current theme is dark
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Board'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : saveEditedBoard,
            icon: _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save Board',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate dynamic font size based on the screen width
          double fontSize = constraints.maxWidth / 20;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: 25,
                itemBuilder: (context, index) {
                  return TextFormField(
                    controller: controllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '${index + 1}',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[200], // Dark mode support
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorText: errorTexts[index],
                      errorStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
                    ),
                    style: TextStyle(
                      fontSize: fontSize, // Responsive font size
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    validator: (value) => validateNumber(value, index),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : saveEditedBoard,
        backgroundColor: Colors.deepPurple,
        icon: _isSaving
            ? const CircularProgressIndicator(
                color: Colors.white,
              )
            : const Icon(Icons.save),
        label: _isSaving ? const Text('Saving...') : const Text('Save'),
        tooltip: 'Save Board',
      ),
    );
  }
}
