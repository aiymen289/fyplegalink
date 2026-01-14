import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lawyer_chat_screen.dart';
class LawyerHomeWrapper extends StatefulWidget {
  const LawyerHomeWrapper({super.key});

  @override
  State<LawyerHomeWrapper> createState() => _LawyerHomeWrapperState();
}

class _LawyerHomeWrapperState extends State<LawyerHomeWrapper> {
  bool isExpanded = true;
  String selectedMenu = "info";

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ===== SIDEBAR =====
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isExpanded ? 240 : 70,
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      setState(() => isExpanded = !isExpanded);
                    },
                  ),
                  const SizedBox(height: 20),

                  _menuItem("Personal Info", Icons.person, "info"),
                  _menuItem("Client Requests", Icons.notifications, "requests"),

                  const Spacer(),

                  _menuItem("Logout", Icons.logout, "logout"),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ===== MAIN SCREEN =====
            Expanded(
              child: selectedMenu == "info"
                  ? _buildPersonalInfoScreen(uid)
                  : _buildClientRequestsScreen(uid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(String title, IconData icon, String key) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: isExpanded
          ? Text(title, style: const TextStyle(color: Colors.white))
          : null,
      onTap: () async {
        if (key == "logout") {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          setState(() => selectedMenu = key);
        }
      },
    );
  }

  // ================= PERSONAL INFO =================
  Widget _buildPersonalInfoScreen(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('lawyers').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  "Lawyer Profile",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _infoRow("Name", data['name']),
                _infoRow("Email", data['email']),
                _infoRow("Phone", data['phone']),
                _infoRow("City", data['city']),
                _infoRow("Specialization", data['specialization']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value ?? "N/A")),
        ],
      ),
    );
  }

  // ================= CLIENT REQUESTS =================
  Widget _buildClientRequestsScreen(String lawyerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('client_requests')
          .where('assignedLawyerId', isEqualTo: lawyerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No client requests"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final req = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final requestDocId = snapshot.data!.docs[index].id;

            return Card(
              child: ListTile(
                title: Row(
                  children: [
                    Text(req['clientName'] ?? 'Client'),
                    const SizedBox(width: 8),
                    // Online/offline status
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('clients')
                          .doc(req['clientId'])
                          .snapshots(),
                      builder: (context, clientSnap) {
                        if (!clientSnap.hasData) return Container();
                        final isOnline = clientSnap.data!.get('isOnline') ?? false;
                        return CircleAvatar(
                          radius: 5,
                          backgroundColor: isOnline ? Colors.green : Colors.grey,
                        );
                      },
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Status: ${req['status']}"),
                    // Typing indicator
                    StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('chats')
      .doc("${lawyerId}_${req['clientId']}")
      .snapshots(),
  builder: (context, chatSnap) {
    if (!chatSnap.hasData || !chatSnap.data!.exists) return Container();
    final data = chatSnap.data!.data() as Map<String, dynamic>;
    final typing = data['typing'] ?? false;
    return typing
        ? const Text(
            "Client is typing...",
            style: TextStyle(color: Colors.blue),
          )
        : Container();
  },

                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== CHAT NOW =====
                    if (req['status'] == 'pending' || req['status'] == 'accepted')
                      ElevatedButton(
                        child: const Text("Chat Now"),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('client_requests')
                              .doc(requestDocId)
                              .update({'status': 'accepted'});

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LawyerChatScreen(
                                lawyerId: lawyerId,
                                clientId: req['clientId'],
                                clientName: req['clientName'],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 8),

                    // ===== SCHEDULE =====
                    if (req['status'] == 'pending')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: const Text("Schedule"),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                            initialDate: DateTime.now(),
                          );

                          if (selected != null) {
                            await FirebaseFirestore.instance
                                .collection('client_requests')
                                .doc(requestDocId)
                                .update({
                              'status': 'scheduled',
                              'scheduledDate': Timestamp.fromDate(selected),
                            });
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
  }
}
