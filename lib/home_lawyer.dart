import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class LawyerHome extends StatelessWidget {
  const LawyerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('client_requests')
          .where('assignedLawyerId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No client requests yet."));
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data() as Map<String, dynamic>;
            final requestId = requests[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: ListTile(
                title: Text(request['clientName'] ?? 'No Name'),
                subtitle: Text(request['clientEmail'] ?? 'No Email'),
                trailing: request['status'] == 'pending'
                    ? ElevatedButton(
                        onPressed: () async {
                          await firestore
                              .collection('client_requests')
                              .doc(requestId)
                              .update({'status': 'approved'});

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                clientId: request['clientId'],
                                lawyerId: uid,
                              ),
                            ),
                          );
                        },
                        child: const Text("Accept"),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                clientId: request['clientId'],
                                lawyerId: uid,
                              ),
                            ),
                          );
                        },
                        child: const Text("Open Chat"),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
