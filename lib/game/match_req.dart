import 'package:bingo/game/match_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchRequestsPage extends StatefulWidget {
  const MatchRequestsPage({super.key});

  @override
  State<MatchRequestsPage> createState() => _MatchRequestsPageState();
}

class _MatchRequestsPageState extends State<MatchRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final MatchService matchService = MatchService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Requests'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('guest', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading match requests.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final matchRequests = snapshot.data!.docs;

          if (matchRequests.isEmpty) {
            return const Center(
              child: Text(
                'No incoming match requests.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: matchRequests.length,
            itemBuilder: (context, index) {
              final match = matchRequests[index];
              final hostId = match['host'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(hostId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'),
                      trailing: CircularProgressIndicator(),
                    );
                  }

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('User not found'),
                    );
                  }

                  final hostData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final hostUsername = hostData?['username'] ?? 'Unknown';
                  final hostEmail = hostData?['email'] ?? 'No Email';

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade300,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(hostUsername),
                      subtitle: Text(hostEmail),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              try {
                                // Accept match and wait for the result
                                await matchService.acceptMatch(
                                    match.id, hostId);

                                // Check if widget is still mounted before trying to navigate
                                if (mounted) {
                                  Navigator.pushNamed(context, '/match',
                                      arguments: match.id);
                                }
                              } catch (error) {
                                // Check if the widget is still mounted before showing the SnackBar
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error accepting match: $error')),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              try {
                                // Reject match and wait for the result
                                await matchService.rejectMatch(
                                    match.id, hostId);

                                // Check if widget is still mounted before showing the SnackBar
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Match request rejected.')),
                                  );
                                }
                              } catch (error) {
                                // Check if the widget is still mounted before showing the SnackBar
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error rejecting match: $error')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
