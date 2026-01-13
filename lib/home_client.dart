import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'chat_screen.dart'; // Agar ClientHome se chat screen jaana ho

class ClientHome extends StatelessWidget {
  const ClientHome({super.key});

  @override
  Widget build(BuildContext context) {
    final clientId = FirebaseAuth.instance.currentUser!.uid;
    final clientEmail = FirebaseAuth.instance.currentUser!.email ?? "No Email";
    final clientName = FirebaseAuth.instance.currentUser!.displayName ?? "No Name";

    return Scaffold(
      appBar: AppBar(title: const Text("Client Dashboard")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lawyers')
            .where('isApproved', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No approved lawyers yet."));
          }

          final lawyers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: lawyers.length,
            itemBuilder: (context, index) {
              final lawyer = lawyers[index].data() as Map<String, dynamic>;
              final lawyerId = lawyers[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                child: ListTile(
                  title: Text(lawyer['name'] ?? 'No Name'),
                  subtitle: Text(lawyer['email'] ?? 'No Email'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Unique doc id to avoid duplicate requests
                      final requestDocId = clientId + "_" + lawyerId;

                      final doc = await FirebaseFirestore.instance
                          .collection('client_requests')
                          .doc(requestDocId)
                          .get();

                      if (!doc.exists) {
                        await FirebaseFirestore.instance
                            .collection('client_requests')
                            .doc(requestDocId)
                            .set({
                          'clientId': clientId,
                          'clientName': clientName,
                          'clientEmail': clientEmail,
                          'assignedLawyerId': lawyerId,
                          'status': 'pending',
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Request sent to lawyer!")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Request already pending.")),
                        );
                      }
                    },
                    child: const Text("Chat Now"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
