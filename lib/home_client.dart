import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  late String clientId;
  late String clientEmail;
  late String clientName;
  String? pendingRequestLawyerId;
  Map<String, dynamic>? activeRequestData;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    clientId = user.uid;
    clientEmail = user.email ?? "No Email";
    clientName = user.displayName ?? "Client";

    // Listen for active requests
    _listenToActiveRequests();
  }

  void _listenToActiveRequests() {
    FirebaseFirestore.instance
        .collection('client_requests')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final request = doc.data();
          final status = request['status'] ?? 'pending';

          // Check if there's any pending/scheduled request
          if (status == 'pending' || status == 'scheduled') {
            setState(() {
              pendingRequestLawyerId = request['assignedLawyerId'];
              activeRequestData = request;
            });
            return;
          }
        }
        // No pending/scheduled requests found
        setState(() {
          pendingRequestLawyerId = null;
          activeRequestData = null;
        });
      } else {
        setState(() {
          pendingRequestLawyerId = null;
          activeRequestData = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Client Dashboard"),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // If there's a pending/scheduled request, show waiting screen
    if (pendingRequestLawyerId != null && activeRequestData != null) {
      return _buildWaitingScreen();
    }

    // Otherwise show normal dashboard with lawyers list
    return Column(
      children: [
        // My Requests Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "My Consultation Requests",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _buildRequestsSection(clientId, context),
            ],
          ),
        ),

        // Available Lawyers Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              const Text(
                "Available Lawyers",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lawyers')
                .where('isApproved', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No approved lawyers available yet.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final lawyers = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: lawyers.length,
                itemBuilder: (context, index) {
                  final lawyer = lawyers[index].data() as Map<String, dynamic>;
                  final lawyerId = lawyers[index].id;
                  final isOnline = lawyer['isOnline'] ?? false;

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child:
                                Icon(Icons.person, color: Colors.teal.shade700),
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
                                border:
                                    Border.all(color: Colors.white, width: 2),
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
                        ],
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final requestDocId = "${clientId}_$lawyerId";

                            await FirebaseFirestore.instance
                                .collection('client_requests')
                                .doc(requestDocId)
                                .set({
                              'clientId': clientId,
                              'clientName': clientName,
                              'clientEmail': clientEmail,
                              'assignedLawyerId': lawyerId,
                              'lawyerName': lawyer['name'] ?? 'Unknown',
                              'status': 'pending',
                              'timestamp': FieldValue.serverTimestamp(),
                              'requestTime': DateTime.now().toIso8601String(),
                            }, SetOptions(merge: true));

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Request sent to lawyer!"),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Update UI to show waiting screen
                              setState(() {
                                pendingRequestLawyerId = lawyerId;
                                activeRequestData = {
                                  'status': 'pending',
                                  'lawyerName': lawyer['name'] ?? 'Unknown',
                                };
                              });
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
                        },
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text("Request"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingScreen() {
    final status = activeRequestData?['status'] ?? 'pending';
    final lawyerName = activeRequestData?['lawyerName'] ?? 'Unknown Lawyer';
    final scheduledDate = activeRequestData?['scheduledDate'];
    final scheduledTime = activeRequestData?['scheduledTime'];

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.teal.shade50,
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),

              // Animated Icon
              Icon(
                Icons.hourglass_top,
                size: 100,
                color: Colors.teal.shade700,
              ),

              const SizedBox(height: 30),

              // Main Title with Animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  status == 'scheduled'
                      ? "Consultation Scheduled!"
                      : "Waiting for Lawyer's Response",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // Status Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.teal.shade700,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Lawyer: $lawyerName",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Status Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: status == 'scheduled'
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: status == 'scheduled'
                                ? Colors.blue
                                : Colors.orange,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'scheduled'
                                  ? Icons.event_available
                                  : Icons.access_time,
                              color: status == 'scheduled'
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              status == 'scheduled'
                                  ? "SCHEDULED"
                                  : "WAITING FOR APPROVAL",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: status == 'scheduled'
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Status Message
                      Text(
                        status == 'scheduled'
                            ? "Your consultation has been scheduled. Please wait for the scheduled time."
                            : "Your request has been sent to the lawyer. They will respond soon with either Chat Now or Schedule option.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Scheduled Details (if scheduled)
                      if (status == 'scheduled' && scheduledDate != null)
                        Column(
                          children: [
                            const SizedBox(height: 25),
                            const Divider(),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.blue),
                                const SizedBox(width: 10),
                                Text(
                                  "Date: ${_formatDate(scheduledDate)}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (scheduledTime != null)
                              Row(
                                children: [
                                  Icon(Icons.access_time, color: Colors.blue),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Time: $scheduledTime",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Real-time Updates Section
              StreamBuilder<DocumentSnapshot>(
                stream: pendingRequestLawyerId != null
                    ? FirebaseFirestore.instance
                        .collection('client_requests')
                        .doc("${clientId}_$pendingRequestLawyerId")
                        .snapshots()
                    : Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final request =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final currentStatus = request['status'] ?? 'pending';

                    // Check if lawyer has accepted chat now
                    if (currentStatus == 'accepted') {
                      // Show success message and chat button
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _showLawyerReadyPopup(
                            context, request['lawyerName'] ?? 'Lawyer');
                      });

                      return Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 60,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "${request['lawyerName'] ?? 'Lawyer'} is ready to chat!",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    clientId: clientId,
                                    lawyerId: pendingRequestLawyerId!,
                                    lawyerName:
                                        request['lawyerName'] ?? 'Unknown',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat),
                            label: const Text("Start Chat Now"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  }

                  // Show loading animation while waiting
                  return Column(
                    children: [
                      const Text(
                        "Real-time Updates:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildLoadingAnimation(),
                      const SizedBox(height: 10),
                      Text(
                        status == 'scheduled'
                            ? "Waiting for scheduled time..."
                            : "Lawyer is reviewing your request",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // Show request details
                      _showRequestDetails();
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text("View Details"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Cancel request option
                      _showCancelDialog();
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text("Cancel Request"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              // Refresh Button
              TextButton.icon(
                onPressed: () {
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh Status"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedDot(0),
          _buildAnimatedDot(1),
          _buildAnimatedDot(2),
        ],
      ),
    );
  }

  Widget _buildAnimatedDot(int index) {
    // Use Future.delayed for sequential animation
    Future.delayed(Duration(milliseconds: 200 * index), () {
      if (mounted) {
        setState(() {});
      }
    });

    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.teal,
        shape: BoxShape.circle,
      ),
    );
  }

  void _showLawyerReadyPopup(BuildContext context, String lawyerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            const SizedBox(width: 10),
            const Text("Lawyer Ready!"),
          ],
        ),
        content: Text(
          "$lawyerName has accepted your request and is ready to chat with you.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    clientId: clientId,
                    lawyerId: pendingRequestLawyerId!,
                    lawyerName: lawyerName,
                  ),
                ),
              );
            },
            child: const Text("Start Chat"),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lawyer: ${activeRequestData?['lawyerName'] ?? 'Unknown'}"),
            const SizedBox(height: 10),
            Text(
                "Status: ${activeRequestData?['status']?.toUpperCase() ?? 'PENDING'}"),
            const SizedBox(height: 10),
            Text("Client: $clientName"),
            const SizedBox(height: 10),
            Text("Email: $clientEmail"),
            if (activeRequestData?['scheduledDate'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                      "Scheduled Date: ${_formatDate(activeRequestData!['scheduledDate'])}"),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Request"),
        content: const Text("Are you sure you want to cancel this request?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              try {
                if (pendingRequestLawyerId != null) {
                  await FirebaseFirestore.instance
                      .collection('client_requests')
                      .doc("${clientId}_$pendingRequestLawyerId")
                      .update({
                    'status': 'cancelled',
                    'cancelledAt': FieldValue.serverTimestamp(),
                  });

                  setState(() {
                    pendingRequestLawyerId = null;
                    activeRequestData = null;
                  });

                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog

                    // Show snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Request cancelled successfully"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Redirect client to dashboard (refresh the page)
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const ClientHome(),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsSection(String clientId, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('client_requests')
          .where('clientId', isEqualTo: clientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 50,
            child:
                Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Error loading requests: ${snapshot.error}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "No active requests. Send a request to a lawyer to get started!",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index].data() as Map<String, dynamic>;
              final status = request['status'] ?? 'pending';
              final lawyerName = request['lawyerName'] ?? 'Unknown Lawyer';

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'pending'
                              ? Icons.hourglass_empty
                              : status == 'scheduled'
                                  ? Icons.event_available
                                  : Icons.chat_bubble,
                          color: status == 'pending'
                              ? Colors.orange
                              : status == 'scheduled'
                                  ? Colors.blue
                                  : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lawyerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == 'pending'
                          ? "⏳ Checking lawyer availability..."
                          : status == 'scheduled'
                              ? "📅 Consultation scheduled"
                              : "✅ Lawyer available - You can chat now!",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (status == 'scheduled' &&
                        request['scheduledDate'] != null)
                      Text(
                        "Date: ${_formatDate(request['scheduledDate'])}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    if (status == 'accepted')
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                clientId: clientId,
                                lawyerId: request['assignedLawyerId'],
                                lawyerName: lawyerName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text("Open Chat",
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 32),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not set';
    if (date is Timestamp) {
      final dt = date.toDate();
      return "${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return date.toString();
  }
}

// Chat Screen for Client
class ChatScreen extends StatefulWidget {
  final String clientId;
  final String lawyerId;
  final String lawyerName;

  const ChatScreen({
    super.key,
    required this.clientId,
    required this.lawyerId,
    required this.lawyerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String get chatId => "${widget.clientId}_${widget.lawyerId}";

  @override
  void initState() {
    super.initState();
    _setClientOnline(true);

    // Update request status to accepted when chat starts
    _updateRequestStatus();
  }

  void _updateRequestStatus() async {
    final requestDocId = "${widget.clientId}_${widget.lawyerId}";
    await FirebaseFirestore.instance
        .collection('client_requests')
        .doc(requestDocId)
        .update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  void _setClientOnline(bool online) async {
    await FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .update({'isOnline': online});
  }

  void _updateTyping(bool typing) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({'clientTyping': typing}, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': widget.clientId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      });

      _messageController.clear();
      _updateTyping(false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending message: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _setClientOnline(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lawyers')
              .doc(widget.lawyerId)
              .snapshots(),
          builder: (context, snapshot) {
            final isOnline = snapshot.hasData && snapshot.data!.exists
                ? (snapshot.data!.data() as Map<String, dynamic>)['isOnline'] ??
                    false
                : false;
            return Row(
              children: [
                Text(widget.lawyerName),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 5,
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == widget.clientId;
                    final seen = msg['seen'] ?? false;

                    // Mark message as seen if it's from lawyer
                    if (!isMe && !seen) {
                      FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .collection('messages')
                          .doc(messages[index].id)
                          .update({'seen': true});
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['message'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (isMe)
                              Icon(
                                seen ? Icons.done_all : Icons.done,
                                size: 12,
                                color: seen ? Colors.blue : Colors.white,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator + input
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .snapshots(),
            builder: (context, snapshot) {
              bool typing = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                typing = data['lawyerTyping'] ?? false;
              }
              return Column(
                children: [
                  if (typing)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Lawyer is typing...",
                          style: TextStyle(
                              color: Colors.blue, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  _buildInput(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: (val) => _updateTyping(val.isNotEmpty),
              decoration: InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.teal,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
