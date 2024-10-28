import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sets the user's online status to true and updates the current match ID (optional)
  Future<void> setUserOnline({String? matchId}) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'online': true,
          'lastActive': FieldValue.serverTimestamp(),
          if (matchId != null) 'currentMatchId': matchId,
        });
        print('User online status updated: true');
      } catch (e) {
        print('Failed to update user online status: $e');
      }
    }
  }

  /// Clears the current match ID for the user without affecting online status
  Future<void> clearCurrentMatchIdOnly() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'currentMatchId': FieldValue.delete(),
        });
        print('User currentMatchId cleared (without changing online status)');
      } catch (e) {
        print('Failed to clear current match ID: $e');
      }
    }
  }

  /// Sets the user's online status to false and clears the current match ID (only call when user is truly offline)
  Future<void> setUserOffline() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'online': false,
          'lastActive': FieldValue.serverTimestamp(),
          'currentMatchId': FieldValue.delete(),
        });
        print('User online status updated: false');
      } catch (e) {
        print('Failed to update user offline status: $e');
      }
    }
  }

  /// Updates the current match ID for the user
  Future<void> updateCurrentMatchId(String matchId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'currentMatchId': matchId,
        });
        print('User currentMatchId updated: $matchId');
      } catch (e) {
        print('Failed to update current match ID: $e');
      }
    }
  }
}
