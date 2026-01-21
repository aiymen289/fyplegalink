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

  // ================= IMAGE VIEW FOR PAYMENT RECEIPT =================
  void _viewPaymentReceipt(BuildContext context, String base64) {
    try {
      Uint8List imageBytes = base64Decode(base64);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.blueGrey[900],
              title: const Text("Receipt View"),
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(imageBytes),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error loading image")),
      );
    }
  }

  // ================= IMAGE VIEW FOR DOCUMENTS =================
  void _viewDocumentImage(BuildContext context, String base64, String title) {
    try {
      Uint8List imageBytes = base64Decode(base64);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.blueGrey[900],
              title: Text(title),
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(imageBytes),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error loading image")),
      );
    }
  }

  // ================= APPROVE LAWYER/CLIENT =================
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

  // ================= REJECT LAWYER/CLIENT =================
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

  // ================= APPROVE PAYMENT =================
  Future<void> approvePayment(BuildContext context, String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'Admin',
      });

      // Get payment details
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .get();

      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final clientId = paymentData['clientId'];

      // Update client's payment status
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .update({
        'hasPaidConsultation': true,
        'paymentApprovedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment Approved Successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ================= REJECT PAYMENT =================
  Future<void> rejectPayment(BuildContext context, String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'Admin',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment Rejected Successfully"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // Added Payments tab
      child: Scaffold(
        // Main Scaffold background color set to light grey
        backgroundColor: const Color.fromARGB(255, 227, 201, 201),
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[900],
          title: const Text("Admin Dashboard"),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "Pending Lawyers"),
              Tab(text: "Pending Clients"),
              Tab(text: "Payments"),
              Tab(text: "Connections"),
              Tab(text: "All Lawyers"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _pendingLawyersList(), // Tab 1: Pending Lawyers
            _pendingClientsList(), // Tab 2: Pending Clients
            _paymentsTab(), // Tab 3: Payments
            _connectionsTab(), // Tab 4: Connections
            _allLawyersTab(), // Tab 5: All Lawyers
          ],
        ),
      ),
    );
  }

  // ================= PENDING LAWYERS LIST =================
  Widget _pendingLawyersList() {
    return Container(
      // Setting light grey background for this tab
      color: const Color.fromARGB(255, 169, 169, 168),
      child: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('lawyers')
            .where('isApproved', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No Pending Lawyers"));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Pending Lawyers: ${docs.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final id = docs[index].id;

                    return Card(
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          d['name'] ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['email'] ?? 'No Email'),
                            if (d['specialization'] != null)
                              Text(
                                d['specialization'],
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // CNIC Front Button
                            if (d['cnicFrontBase64'] != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.credit_card,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                tooltip: "CNIC Front",
                                onPressed: () => _viewDocumentImage(context,
                                    d['cnicFrontBase64'], "CNIC Front"),
                              ),

                            // CNIC Back Button
                            if (d['cnicBackBase64'] != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.credit_card,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                tooltip: "CNIC Back",
                                onPressed: () => _viewDocumentImage(
                                    context, d['cnicBackBase64'], "CNIC Back"),
                              ),

                            // Certificate Button
                            if (d['certificateBase64'] != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.school,
                                  color: Colors.purple,
                                  size: 20,
                                ),
                                tooltip: "Bar Council Certificate",
                                onPressed: () => _viewDocumentImage(context,
                                    d['certificateBase64'], "Law Certificate"),
                              ),

                            const SizedBox(width: 10),

                            // Approve Button
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () => approve(context, 'lawyers', id),
                            ),

                            // Reject Button
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => reject(context, 'lawyers', id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= PENDING CLIENTS LIST =================
  Widget _pendingClientsList() {
    return Container(
      // Setting light grey background for this tab
      color: const Color.fromARGB(255, 169, 169, 168),
      child: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .where('isApproved', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No Pending Clients"));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Pending Clients: ${docs.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final id = docs[index].id;

                    return Card(
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          d['fullName'] ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['email'] ?? 'No Email'),
                            if (d['phone'] != null)
                              Text(
                                d['phone'],
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // CNIC Front Button
                            if (d['cnicFrontBase64'] != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.credit_card,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                tooltip: "CNIC Front",
                                onPressed: () => _viewDocumentImage(context,
                                    d['cnicFrontBase64'], "CNIC Front"),
                              ),

                            // CNIC Back Button
                            if (d['cnicBackBase64'] != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.credit_card,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                tooltip: "CNIC Back",
                                onPressed: () => _viewDocumentImage(
                                    context, d['cnicBackBase64'], "CNIC Back"),
                              ),

                            const SizedBox(width: 10),

                            // Approve Button
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              onPressed: () => approve(context, 'clients', id),
                            ),

                            // Reject Button
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => reject(context, 'clients', id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= PAYMENTS TAB =================
  Widget _paymentsTab() {
    return Container(
      // Setting light grey background for this tab
      color: const Color.fromARGB(255, 169, 169, 168),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search by client name or email",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color.fromARGB(255, 34, 34, 34),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Payments Table
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No payments found",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Filter by search query
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final clientName =
                      data['clientName']?.toString().toLowerCase() ?? '';
                  final clientEmail =
                      data['clientEmail']?.toString().toLowerCase() ?? '';
                  final searchLower = searchQuery.toLowerCase();

                  return searchLower.isEmpty ||
                      clientName.contains(searchLower) ||
                      clientEmail.contains(searchLower);
                }).toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      horizontalMargin: 10,
                      columns: const [
                        DataColumn(label: Text("Client Name")),
                        DataColumn(label: Text("Email")),
                        DataColumn(label: Text("Phone")),
                        DataColumn(label: Text("Amount")),
                        DataColumn(label: Text("Receipt")),
                        DataColumn(label: Text("Status")),
                        DataColumn(label: Text("Date")),
                        DataColumn(label: Text("Actions")),
                      ],
                      rows: filteredDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final paymentId = doc.id;
                        final clientName = data['clientName'] ?? 'N/A';
                        final clientEmail = data['clientEmail'] ?? 'N/A';
                        final clientPhone = data['clientPhone'] ?? 'N/A';
                        final amount = data['amount'] ?? 0;
                        final status = data['status'] ?? 'pending';
                        final timestamp = data['timestamp'] != null
                            ? (data['timestamp'] as Timestamp).toDate()
                            : DateTime.now();
                        final receiptImage = data['receiptImage'] as String?;

                        // Status color
                        Color statusColor = Colors.orange;
                        String statusText = 'Pending';

                        if (status == 'approved') {
                          statusColor = Colors.green;
                          statusText = 'Approved';
                        } else if (status == 'rejected') {
                          statusColor = Colors.red;
                          statusText = 'Rejected';
                        }

                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(
                                  clientName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  clientEmail,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(clientPhone)),
                            DataCell(
                              Text(
                                "Rs. $amount",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            DataCell(
                              receiptImage != null
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.receipt,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () {
                                        _viewPaymentReceipt(
                                            context, receiptImage!);
                                      },
                                    )
                                  : const Text("No receipt"),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "${timestamp.day}/${timestamp.month}/${timestamp.year}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  if (status == 'pending')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        approvePayment(context, paymentId);
                                      },
                                    ),
                                  if (status == 'pending')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        rejectPayment(context, paymentId);
                                      },
                                    ),
                                  if (status == 'approved')
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  if (status == 'rejected')
                                    const Icon(
                                      Icons.block,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= CONNECTIONS TAB =================
  Widget _connectionsTab() {
    return Container(
      // Setting light grey background for this tab
      color: const Color.fromARGB(255, 169, 169, 168),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search client / lawyer",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
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
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final req = doc.data() as Map<String, dynamic>;
                  final clientName =
                      req['clientName']?.toString().toLowerCase() ?? '';
                  final lawyerName =
                      req['lawyerName']?.toString().toLowerCase() ?? '';
                  final searchLower = searchQuery.toLowerCase();

                  return searchLower.isEmpty ||
                      clientName.contains(searchLower) ||
                      lawyerName.contains(searchLower);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No Connections Found",
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final req =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    return _connectionListCard(req);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= ALL LAWYERS TAB =================
  Widget _allLawyersTab() {
    return Container(
      // Setting light grey background for this tab
      color: const Color.fromARGB(255, 169, 169, 168),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lawyers')
            .where('isApproved', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No approved lawyers"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final lawyer = docs[index].data() as Map<String, dynamic>;
              final isOnline = lawyer['isOnline'] ?? false;

              return Card(
                elevation: 3,
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal.shade100,
                        child: Icon(Icons.person, color: Colors.teal.shade700),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    lawyer['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lawyer['email'] ?? 'No Email'),
                      const SizedBox(height: 4),
                      Text(
                        lawyer['specialization'] ?? 'General Practice',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_money,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          const Text(
                            "Consultation Fee: Rs. 2,000",
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    isOnline ? "Online" : "Offline",
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ================= CONNECTION LIST CARD =================
  Widget _connectionListCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'pending';
    final paymentVerified = req['paymentVerified'] ?? false;

    Color statusColor = Colors.orange;
    if (status == 'accepted') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'scheduled') statusColor = Colors.blue;
    if (status == 'cancelled') statusColor = Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 169, 169, 168),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 5,
            color: Colors.grey.withOpacity(0.3),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Status
          Row(
            children: [
              Icon(
                paymentVerified ? Icons.verified : Icons.payment,
                size: 16,
                color: paymentVerified ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 5),
              Text(
                paymentVerified ? "Payment Verified" : "Payment Pending",
                style: TextStyle(
                  color: paymentVerified ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // CLIENT
          const Text(
            "CLIENT",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            req['clientName'] ?? '',
            style: const TextStyle(color: Colors.black, fontSize: 14),
          ),
          Text(
            req['clientEmail'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 8),

          // LAWYER
          const Text(
            "LAWYER",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            req['lawyerName'] ?? '',
            style: const TextStyle(color: Colors.black, fontSize: 14),
          ),
          Text(
            req['lawyerEmail'] ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 8),

          // CASE TYPE
          const Text(
            "CASE TYPE",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            req['caseType'] ?? 'Not Provided',
            style: const TextStyle(color: Colors.black, fontSize: 12),
          ),

          const SizedBox(height: 8),

          // CONSULTATION FEE
          const Text(
            "CONSULTATION FEE",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            "Rs. ${req['consultationFee'] ?? '2,000'}",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // STATUS BADGE
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
