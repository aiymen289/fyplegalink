import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int selectedTab = 0; // 0 = Lawyers, 1 = Clients

  // ================= ACTIONS =================
  Future<void> _approveLawyer(String uid) async {
    await _firestore.collection('lawyers').doc(uid).update({
      'status': 'approved',
    });
  }

  Future<void> _rejectLawyer(String uid) async {
    await _firestore.collection('lawyers').doc(uid).update({
      'status': 'rejected',
    });
  }

  Future<void> _approveClient(String uid) async {
    await _firestore.collection('clients').doc(uid).update({
      'isApproved': true,
    });
  }

  Future<void> _rejectClient(String uid) async {
    await _firestore.collection('clients').doc(uid).update({
      'isApproved': false,
    });
  }

  // ================= LAWYERS TAB =================
  Widget _buildLawyersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('lawyers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text("No data"));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No pending lawyers"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text(data['name'] ?? 'No Name'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? 'No Email'),
                    Text(data['specialization'] ?? 'No Specialization'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _approveLawyer(docs[index].id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectLawyer(docs[index].id),
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

  // ================= CLIENTS TAB =================
  Widget _buildClientsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('clients').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text("No data"));
        }

        // 🔥 FILTER IN DART (NOT FIRESTORE)
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isApproved'] == false || data['isApproved'] == null;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No pending clients"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text(data['fullName'] ?? 'No Name'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? 'No Email'),
                    Text(data['phone'] ?? 'No Phone'),
                    if (data['caseType'] != null)
                      Text("Case: ${data['caseType']}"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _approveClient(docs[index].id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectClient(docs[index].id),
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color:
                        selectedTab == 0 ? Colors.deepPurple : Colors.black,
                    child: const Center(
                      child: Text(
                        "Pending Lawyers",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color:
                        selectedTab == 1 ? Colors.deepPurple : Colors.black,
                    child: const Center(
                      child: Text(
                        "Pending Clients",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: selectedTab == 0 ? _buildLawyersTab() : _buildClientsTab(),
    );
  }
}
