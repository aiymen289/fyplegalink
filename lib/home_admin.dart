import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String searchQuery = '';

  // ================= IMAGE VIEW =================
  void _viewImage(BuildContext context, String base64) {
    Uint8List imageBytes = base64Decode(base64);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.blueGrey[900],
            title: const Text("Document View"),
          ),
          body: Center(child: Image.memory(imageBytes)),
        ),
      ),
    );
  }

  // ================= APPROVE =================
  Future<void> approve(BuildContext context, String col, String uid) async {
    final doc = await FirebaseFirestore.instance.collection(col).doc(uid).get();

    final data = doc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance.collection(col).doc(uid).update({
      'isApproved': true,
    });

    await FirebaseFirestore.instance.collection('${col}_history').doc(uid).set({
      ...data,
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Approved Successfully")),
    );
  }

  // ================= REJECT =================
  Future<void> reject(BuildContext context, String col, String uid) async {
    final doc = await FirebaseFirestore.instance.collection(col).doc(uid).get();

    final data = doc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance.collection(col).doc(uid).delete();

    await FirebaseFirestore.instance.collection('${col}_history').doc(uid).set({
      ...data,
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Rejected Successfully")),
    );
  }

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 93, 92, 92),
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          title: const Text("Admin Dashboard"),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "Pending Lawyers"),
              Tab(text: "Pending Clients"),
              Tab(text: "Connections"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _pendingList('lawyers', true),
            _pendingList('clients', false),
            _connectionsTab(),
          ],
        ),
      ),
    );
  }

  // ================= PENDING LIST =================
  Widget _pendingList(String collection, bool isLawyer) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('isApproved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No Pending Requests"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;

            return Card(
              child: ListTile(
                title: Text(isLawyer
                    ? (d['name'] ?? 'No Name')
                    : (d['fullName'] ?? 'No Name')),
                subtitle: Text(d['email'] ?? 'No Email'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d['cnicFrontBase64'] != null)
                      IconButton(
                        icon: const Icon(Icons.credit_card, color: Colors.blue),
                        onPressed: () =>
                            _viewImage(context, d['cnicFrontBase64']),
                      ),
                    if (d['cnicBackBase64'] != null)
                      IconButton(
                        icon:
                            const Icon(Icons.credit_card, color: Colors.orange),
                        onPressed: () =>
                            _viewImage(context, d['cnicBackBase64']),
                      ),
                    if (isLawyer && d['certificateBase64'] != null)
                      IconButton(
                        icon: const Icon(Icons.school, color: Colors.purple),
                        onPressed: () =>
                            _viewImage(context, d['certificateBase64']),
                      ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => approve(context, collection, id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => reject(context, collection, id),
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

  // ================= CONNECTION TAB (FIXED) =================
  Widget _connectionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (val) {
              setState(() => searchQuery = val);
            },
            decoration: InputDecoration(
              hintText: "Search client / lawyer",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color.fromARGB(255, 98, 95, 95),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('client_requests')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final clientName =
                    (data['clientName'] ?? '').toString().toLowerCase();

                final lawyerName =
                    (data['lawyerName'] ?? '').toString().toLowerCase();

                final search = searchQuery.toLowerCase();

                return clientName.contains(search) ||
                    lawyerName.contains(search);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text("No Connections Found"));
              }

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final req =
                      filteredDocs[index].data() as Map<String, dynamic>;

                  return _connectionListItem(req);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= CONNECTION ROW =================
  Widget _connectionListItem(Map<String, dynamic> req) {
    final status = (req['status'] ?? 'pending').toString();

    Color statusColor = Colors.orange;

    if (status == 'accepted') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'scheduled') statusColor = Colors.blue;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          (req['clientName'] ?? 'Unknown Client').toString(),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          (req['lawyerName'] ?? 'Unknown Lawyer').toString(),
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }
}
