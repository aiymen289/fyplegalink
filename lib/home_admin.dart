import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  // VIEW IMAGE -----------------------
  void _viewImage(BuildContext context, String base64) {
    Uint8List imageBytes = base64Decode(base64);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Image View")),
          body: Center(child: Image.memory(imageBytes)),
        ),
      ),
    );
  }

  // APPROVE --------------------
  Future<void> approve(BuildContext context, String col, String uid) async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection(col).doc(uid).get();
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

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

  // REJECT --------------------
  Future<void> reject(BuildContext context, String col, String uid) async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection(col).doc(uid).get();
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

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

  // -------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.gavel),
                text: "Pending Lawyers",
              ),
              Tab(
                icon: Icon(Icons.person),
                text: "Pending Clients",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ---------------------- LAWYERS TAB -----------------------
            StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('lawyers')
                  .where('isApproved', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                int pendingCount = snapshot.data!.docs.length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Pending Lawyers: $pendingCount",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: snapshot.data!.docs.isEmpty
                          ? const Center(child: Text("No Pending Lawyers"))
                          : ListView(
                              children: snapshot.data!.docs.map((doc) {
                                var d = doc.data();
                                return Card(
                                  child: ListTile(
                                    title: Text(d['name']),
                                    subtitle: Text(d['email']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (d['cnicFrontBase64'] != null)
                                          IconButton(
                                            icon: const Icon(Icons.credit_card,
                                                color: Colors.blue),
                                            tooltip: "CNIC Front",
                                            onPressed: () => _viewImage(
                                                context, d['cnicFrontBase64']),
                                          ),
                                        if (d['cnicBackBase64'] != null)
                                          IconButton(
                                            icon: const Icon(Icons.credit_card,
                                                color: Colors.orange),
                                            tooltip: "CNIC Back",
                                            onPressed: () => _viewImage(
                                                context, d['cnicBackBase64']),
                                          ),
                                        if (d['certificateBase64'] != null)
                                          IconButton(
                                            icon: const Icon(Icons.school,
                                                color: Colors.purple),
                                            tooltip: "Bar Council Certificate",
                                            onPressed: () => _viewImage(context,
                                                d['certificateBase64']),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: () => approve(
                                              context, 'lawyers', doc.id),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () => reject(
                                              context, 'lawyers', doc.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                );
              },
            ),

            // ---------------------- CLIENTS TAB -----------------------
            StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('clients')
                  .where('isApproved', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                int pendingCount = snapshot.data!.docs.length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Pending Clients: $pendingCount",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: snapshot.data!.docs.isEmpty
                          ? const Center(child: Text("No Pending Clients"))
                          : ListView(
                              children: snapshot.data!.docs.map((doc) {
                                var d = doc.data();
                                return Card(
                                  child: ListTile(
                                    title: Text(d['fullName']),
                                    subtitle: Text(d['email']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.credit_card,
                                              color: Colors.blue),
                                          tooltip: "CNIC Front",
                                          onPressed: () => _viewImage(
                                              context, d['cnicFrontBase64']),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.credit_card,
                                              color: Colors.orange),
                                          tooltip: "CNIC Back",
                                          onPressed: () => _viewImage(
                                              context, d['cnicBackBase64']),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: () => approve(
                                              context, 'clients', doc.id),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () => reject(
                                              context, 'clients', doc.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
