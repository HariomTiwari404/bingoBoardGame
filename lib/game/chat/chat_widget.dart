import 'dart:async';

import 'package:bingo/game/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatWidget extends StatefulWidget {
  final String matchId;
  final String playerId;

  const ChatWidget({
    super.key,
    required this.matchId,
    required this.playerId,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Add the following inside your ChatWidget to reset unread messages when chat is opened
  @override
  void initState() {
    super.initState();
    // Existing initialization code...

    // Reset unread messages when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final matchService = MatchService();
      matchService.resetUnreadMessages(widget.matchId, widget.playerId);
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _firestore
        .collection('matches')
        .doc(widget.matchId)
        .collection('messages')
        .add({
      'senderId': widget.playerId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false, // Message is unseen by default
    });

    _controller.clear();
    _scrollToBottom();
  }

  void _markMessagesAsSeen() async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('matches')
        .doc(widget.matchId)
        .collection('messages')
        .where('senderId', isNotEqualTo: widget.playerId)
        .where('seen', isEqualTo: false)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({'seen': true});
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('matches')
                  .doc(widget.matchId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  controller: _scrollController, // Attach the scroll controller
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isCurrentUser =
                        message['senderId'] == widget.playerId;
                    final messageText = message['text'];
                    final timestamp =
                        (message['timestamp'] as Timestamp?)?.toDate();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Align(
                        alignment: isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end, // Align to the right
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? Colors.green.withOpacity(0.7)
                                    : Colors.blueAccent.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              padding: const EdgeInsets.all(10),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                messageText ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            // Show seen status for current user's message
                            if (isCurrentUser)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  message['seen'] ? 'Seen' : 'Sent',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blueAccent,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
