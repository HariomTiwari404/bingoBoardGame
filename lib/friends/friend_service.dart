// lib/friends/friend_service.dart

import 'package:bingo/push_notifications/push_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User user = FirebaseAuth.instance.currentUser!;

  /// Send a friend request only if not already friends and no request exists
  Future<String> sendFriendRequest(String friendEmailOrUsername) async {
    try {
      // Find the friend by email or username
      var friendSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: friendEmailOrUsername)
          .get();

      if (friendSnapshot.docs.isEmpty) {
        friendSnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: friendEmailOrUsername)
            .get();

        if (friendSnapshot.docs.isEmpty) {
          throw 'User not found.';
        }
      }

      String friendId = friendSnapshot.docs.first.id;

      // Check if they are already friends
      bool alreadyFriends = await areFriends(user.uid, friendId);
      if (alreadyFriends) {
        throw 'You are already friends with this user.';
      }

      // Check if there is a pending request from this user to the friend
      var sentRequest = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: user.uid)
          .where('to', isEqualTo: friendId)
          .get();

      if (sentRequest.docs.isNotEmpty) {
        throw 'You have already sent a friend request to this user.';
      }

      // Check if there is a pending request from the friend to this user
      var receivedRequest = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: friendId)
          .where('to', isEqualTo: user.uid)
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        throw 'This user has already sent you a friend request. Accept it instead.';
      }

      // Create the friend request with 'pending' status
      await _firestore.collection('friend_requests').add({
        'from': user.uid,
        'to': friendId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send notification to the recipient
      await sendFriendRequestNotification(
        friendId,
        '📩 New Friend Request!',
        'You have a new friend request from ${user.email}.',
      );

      // Return the friendId after successful request creation
      return friendId;
    } catch (e) {
      rethrow;
    }
  }

  /// Get friends and their details
  Stream<QuerySnapshot> getFriendsList() {
    return _firestore
        .collection('friends')
        .where('user1', isEqualTo: user.uid)
        .snapshots();
  }

  /// Accept a friend request and establish mutual friendship
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    try {
      // Create mutual friendships
      await _firestore.collection('friends').add({
        'user1': user.uid,
        'user2': fromUserId,
      });

      await _firestore.collection('friends').add({
        'user1': fromUserId,
        'user2': user.uid,
      });

      // Delete the friend request
      await _firestore.collection('friend_requests').doc(requestId).delete();

      // Send notification to the sender
      await sendFriendRequestAcceptedNotification(
        fromUserId,
        '✅ Friend Request Accepted!',
        'Your friend request was accepted by ${user.email}.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId, String fromUserId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();

      // Send notification to the sender
      await sendFriendRequestRejectedNotification(
        fromUserId,
        '❌ Friend Request Rejected',
        'Your friend request was rejected by ${user.email}.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Send push notification to a specific user
  Future<void> _sendNotification(
      String userId, String title, String body) async {
    try {
      QuerySnapshot tokensSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .get();

      List<String> tokens =
          tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

      for (String token in tokens) {
        await PushNotificationService.sendNotificationToUser(
            token, title, body);
      }

      print('📲 Notification sent to user: $userId');
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  /// Send Friend Request Notification
  Future<void> sendFriendRequestNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  /// Send Friend Request Accepted Notification
  Future<void> sendFriendRequestAcceptedNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  /// Send Friend Request Rejected Notification
  Future<void> sendFriendRequestRejectedNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  /// Send Match Request Notification
  Future<void> sendMatchRequestNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  /// Send Match End Notification
  Future<void> sendMatchEndNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  /// Check if two users are friends (in either direction)
  Future<bool> areFriends(String userId1, String userId2) async {
    var friendsSnapshot = await _firestore
        .collection('friends')
        .where('user1', isEqualTo: userId1)
        .where('user2', isEqualTo: userId2)
        .get();

    if (friendsSnapshot.docs.isEmpty) {
      var reverseSnapshot = await _firestore
          .collection('friends')
          .where('user1', isEqualTo: userId2)
          .where('user2', isEqualTo: userId1)
          .get();
      return reverseSnapshot.docs.isNotEmpty;
    }
    return true;
  }

  /// Fetch user details by user ID
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    var userSnapshot = await _firestore.collection('users').doc(userId).get();
    return userSnapshot.data();
  }

  /// Get friend requests the current user has received
  Stream<QuerySnapshot> getReceivedFriendRequests() {
    return _firestore
        .collection('friend_requests')
        .where('to', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Get friend requests the current user has sent
  Stream<QuerySnapshot> getSentFriendRequests() {
    return _firestore
        .collection('friend_requests')
        .where('from', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Search users by username
  Stream<QuerySnapshot> searchUsersByUsername(String username) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: username)
        .where('username', isLessThanOrEqualTo: '$username\uf8ff')
        .snapshots();
  }

  /// Delete a friend relationship from both users
  Future<void> deleteFriend(String friendId) async {
    // Delete the friendship entry from both directions
    var friendsSnapshot1 = await _firestore
        .collection('friends')
        .where('user1', isEqualTo: user.uid)
        .where('user2', isEqualTo: friendId)
        .get();

    if (friendsSnapshot1.docs.isNotEmpty) {
      await friendsSnapshot1.docs.first.reference.delete();
    }

    var friendsSnapshot2 = await _firestore
        .collection('friends')
        .where('user1', isEqualTo: friendId)
        .where('user2', isEqualTo: user.uid)
        .get();

    if (friendsSnapshot2.docs.isNotEmpty) {
      await friendsSnapshot2.docs.first.reference.delete();
    }
  }

  /// Accepts a match request by updating the match status and setting both users as in a match.
  Future<void> acceptMatchRequest(
      String matchId, String hostId, String guestId) async {
    try {
      print(
          'Accepting match request: Match ID $matchId between Host $hostId and Guest $guestId');

      // Update match status to 'active' and set 'currentTurn' to host
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'active',
        'currentTurn': hostId, // Initialize currentTurn to host
      });
      print('Match status updated to active and currentTurn set to host.');

      // Set 'inMatch' to true and assign 'currentMatchId' for both users
      await _firestore.collection('users').doc(hostId).update({
        'inMatch': true,
        'currentMatchId': matchId,
      });
      await _firestore.collection('users').doc(guestId).update({
        'inMatch': true,
        'currentMatchId': matchId,
      });
      print('Users updated to reflect they are in a match.');

      // Send notifications to both users
      await _sendNotification(
        hostId,
        '✅ Match Accepted!',
        'Your match request has been accepted by ${user.email}.',
      );
      print('Notification sent to host.');

      await _sendNotification(
        guestId,
        '✅ Match Accepted!',
        'You have accepted the match request from $hostId.',
      );
      print('Notification sent to guest.');
    } catch (e) {
      print('Error accepting match request: $e');
      rethrow;
    }
  }

  /// Flatten the 2D Bingo board into a 1D list for Firestore storage
  List<int> _flattenBoard(List<List<int>> board) {
    return board.expand((row) => row).toList();
  }

  /// Retrieves all device tokens for a given user.
  Future<List<String>> _getUserTokens(String userId) async {
    try {
      QuerySnapshot tokensSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .get();

      return tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();
    } catch (e) {
      print('Error fetching user tokens: $e');
      return [];
    }
  }

  /// Send Match Accepted Notification
  Future<void> sendMatchAcceptedNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  /// Send Match Rejected Notification
  Future<void> sendMatchRejectedNotification(
      String userId, String title, String body) async {
    await _sendNotification(userId, title, body);
  }

  Future<void> sendMatchRequest(String guestId) async {
    try {
      final matchesCollection = _firestore.collection('matches');
      final matchRef =
          _firestore.collection('matches').doc(); // Auto-generated ID

      // **Fetch the host's selected board or generate a random one**
      List<List<int>> hostBoard = await _getSelectedOrRandomBoard(user.uid);

      // **Fetch the guest's selected board or generate a random one**
      List<List<int>> guestBoard = await _getSelectedOrRandomBoard(guestId);

      // Flatten the 2D boards to store in Firestore
      List<int> flattenedHostBoard = _flattenBoard(hostBoard);
      List<int> flattenedGuestBoard = _flattenBoard(guestBoard);

      await _firestore.runTransaction((transaction) async {
        // Create the match document
        transaction.set(matchRef, {
          'host': user.uid,
          'guest': guestId,
          'status': 'pending', // Initial status for the match
          'timestamp': FieldValue.serverTimestamp(),
          'currentTurn': user.uid, // Initialize to host's turn
          'winner': null,
          'finished': false,
          'turnsTaken': 0,
          'maxTurns': 25,
        });

        // Initialize host's board and game state
        DocumentReference hostPlayerRef =
            matchRef.collection('players').doc(user.uid);
        transaction.set(hostPlayerRef, {
          'board': flattenedHostBoard,
          'markedNumbers': [],
          'completedLines': [],
          'bingo': false,
          'ready': false, // A flag to track if the player is ready to play
          'turns': 0, // Track the number of turns taken by this player
        });

        // Initialize guest's board and game state
        DocumentReference guestPlayerRef =
            matchRef.collection('players').doc(guestId);
        transaction.set(guestPlayerRef, {
          'board': flattenedGuestBoard,
          'markedNumbers': [],
          'completedLines': [],
          'bingo': false,
          'ready': false, // A flag to track if the player is ready to play
          'turns': 0, // Track the number of turns taken by this player
        });

        print('Match document and player documents created successfully.');
      });

      // Send a notification to the guest about the match request
      await sendMatchRequestNotification(
        guestId,
        '🎮 Match Request!',
        'You have a new match request from ${user.email}.',
      );

      print('Match request sent to user: $guestId');
    } catch (e) {
      print('Error sending match request: $e');
      throw Exception('Failed to send match request: $e');
    }
  }

  /// Helper function to get the selected board or generate a random one
  Future<List<List<int>>> _getSelectedOrRandomBoard(String userId) async {
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
      return _generateRandomBoard();
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

  /// Generate a random 5x5 Bingo board with numbers from 1 to 25
  List<List<int>> _generateRandomBoard() {
    List<int> numbers = List<int>.generate(25, (index) => index + 1)..shuffle();
    List<List<int>> board = [];
    for (int i = 0; i < 5; i++) {
      board.add(numbers.sublist(i * 5, (i + 1) * 5));
    }
    return board;
  }

  /// Rejects a match request by updating the match status.
  Future<void> rejectMatchRequest(String matchId, String hostId) async {
    try {
      // Update match status to 'rejected'
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'rejected',
      });

      // Send notification to the host that the request was rejected
      await sendMatchRejectedNotification(
        hostId,
        '❌ Match Request Rejected',
        'Your match request was rejected by ${user.email}.',
      );

      print('Match request rejected and status updated.');
    } catch (e) {
      print('Error rejecting match request: $e');
      rethrow;
    }
  }
}
