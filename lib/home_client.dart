import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  late String clientId;
  late String clientEmail;
  late String clientName;
  late String clientPhone;
  String? pendingRequestLawyerId;
  Map<String, dynamic>? activeRequestData;
  bool _hasPaidConsultation = false;
  bool _isDrawerOpen = false;
  int _selectedIndex = 0;
  String caseType = 'Not specified';
  bool _isLoading = true;

  // For caching data
  List<Map<String, dynamic>> _allLawyers = [];
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _payments = [];
  String _paymentStatus = 'none'; // 'none', 'pending', 'approved', 'rejected'
  String? _approvedPaymentId;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'title': 'Dashboard', 'index': 0},
    {'icon': Icons.person, 'title': 'Profile Info', 'index': 1},
    {'icon': Icons.people, 'title': 'All Lawyers', 'index': 2},
    {'icon': Icons.history, 'title': 'My Requests', 'index': 3},
    {'icon': Icons.chat, 'title': 'Chat History', 'index': 4},
    {'icon': Icons.payment, 'title': 'Payment History', 'index': 5},
    {'icon': Icons.settings, 'title': 'Settings', 'index': 6},
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    clientId = user.uid;
    clientEmail = user.email ?? "No Email";
    clientName = user.displayName ?? "Client";

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _getClientDetails();
      await _checkPaymentStatus();
      await _loadInitialData();
      _setupListeners();
    } catch (e) {
      print("Error initializing data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getClientDetails() async {
    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .get();

      if (clientDoc.exists) {
        setState(() {
          clientPhone = clientDoc.data()?['phone'] ?? 'No Phone';
          clientName = clientDoc.data()?['fullName'] ?? clientName;
          caseType = clientDoc.data()?['caseType'] ?? 'Not specified';
        });
      }
    } catch (e) {
      print("Error getting client details: $e");
    }
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('clientId', isEqualTo: clientId)
          .get();

      if (paymentSnapshot.docs.isEmpty) {
        setState(() {
          _paymentStatus = 'none';
          _hasPaidConsultation = false;
          _approvedPaymentId = null;
        });
        return;
      }

      // Check for approved payment
      for (var doc in paymentSnapshot.docs) {
        final payment = doc.data() as Map<String, dynamic>;
        final status = payment['status'] ?? 'pending';

        if (status == 'approved') {
          setState(() {
            _paymentStatus = 'approved';
            _hasPaidConsultation = true;
            _approvedPaymentId = doc.id;
          });
          return;
        }
      }

      // Check for pending payment
      for (var doc in paymentSnapshot.docs) {
        final payment = doc.data() as Map<String, dynamic>;
        final status = payment['status'] ?? 'pending';

        if (status == 'pending') {
          setState(() {
            _paymentStatus = 'pending';
            _hasPaidConsultation = false;
            _approvedPaymentId = null;
          });
          return;
        }
      }

      // If only rejected payments
      setState(() {
        _paymentStatus = 'rejected';
        _hasPaidConsultation = false;
        _approvedPaymentId = null;
      });
    } catch (e) {
      print("Error checking payment status: $e");
      setState(() {
        _paymentStatus = 'none';
        _hasPaidConsultation = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Load lawyers - always load
      final lawyersSnapshot =
          await FirebaseFirestore.instance.collection('lawyers').get();

      _allLawyers = lawyersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      // Load requests - only if payment is approved
      if (_hasPaidConsultation) {
        await _loadMyRequests();
      }

      // Load payments - always load
      await _loadPayments();
    } catch (e) {
      print("Error loading initial data: $e");
    }
  }

  Future<void> _loadMyRequests() async {
    try {
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('client_requests')
          .where('clientId', isEqualTo: clientId)
          .get();

      _myRequests = requestsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      // Find active request
      for (var request in _myRequests) {
        final status = request['status'] ?? 'pending';
        if (status == 'pending' ||
            status == 'scheduled' ||
            status == 'accepted') {
          setState(() {
            pendingRequestLawyerId = request['assignedLawyerId'];
            activeRequestData = request;
          });
          break;
        }
      }
    } catch (e) {
      print("Error loading my requests: $e");
    }
  }

  Future<void> _loadPayments() async {
    try {
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('clientId', isEqualTo: clientId)
          .orderBy('timestamp', descending: true)
          .get();

      _payments = paymentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print("Error loading payments: $e");
    }
  }

  void _setupListeners() {
    // Listen for payment updates - REAL TIME
    FirebaseFirestore.instance
        .collection('payments')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .listen((snapshot) async {
      if (mounted) {
        // Update payments list
        _payments = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();

        // Check payment status again
        bool hadPaidBefore = _hasPaidConsultation;

        // Reset
        _paymentStatus = 'none';
        _hasPaidConsultation = false;
        _approvedPaymentId = null;

        // Check for approved payment
        for (var doc in snapshot.docs) {
          final payment = doc.data() as Map<String, dynamic>;
          final status = payment['status'] ?? 'pending';

          if (status == 'approved') {
            _paymentStatus = 'approved';
            _hasPaidConsultation = true;
            _approvedPaymentId = doc.id;
            break;
          } else if (status == 'pending' && _paymentStatus == 'none') {
            _paymentStatus = 'pending';
          } else if (status == 'rejected' && _paymentStatus == 'none') {
            _paymentStatus = 'rejected';
          }
        }

        // If payment just got approved, load lawyers and requests
        if (_hasPaidConsultation && !hadPaidBefore) {
          await _loadMyRequests();
        }

        // If payment was approved but now not, clear requests
        if (!_hasPaidConsultation && hadPaidBefore) {
          _myRequests.clear();
          pendingRequestLawyerId = null;
          activeRequestData = null;
        }

        setState(() {});
      }
    });

    // Listen for new requests - only if payment is approved
    if (_hasPaidConsultation) {
      FirebaseFirestore.instance
          .collection('client_requests')
          .where('clientId', isEqualTo: clientId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _myRequests = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {'id': doc.id, ...data};
            }).toList();

            // Update active request
            pendingRequestLawyerId = null;
            activeRequestData = null;
            for (var request in _myRequests) {
              final status = request['status'] ?? 'pending';
              if (status == 'pending' ||
                  status == 'scheduled' ||
                  status == 'accepted') {
                pendingRequestLawyerId = request['assignedLawyerId'];
                activeRequestData = request;
                break;
              }
            }
          });
        }
      });
    }

    // Listen for lawyer updates - always listen
    FirebaseFirestore.instance
        .collection('lawyers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _allLawyers = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.teal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _isDrawerOpen = !_isDrawerOpen;
            });
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              _hasPaidConsultation ? Icons.verified : Icons.payment,
              color: _hasPaidConsultation ? Colors.green : Colors.orange,
              size: 24,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Sidebar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isDrawerOpen ? 250 : 70,
                  decoration: BoxDecoration(
                    color: Colors.teal[900],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: _buildSidebar(),
                ),
                // Main Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSidebar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (_isDrawerOpen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.teal[100],
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.teal[900],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    clientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    clientEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white54),
                ],
              ),
            ),
          ..._menuItems.map((item) {
            return MouseRegion(
              onEnter: (_) {
                if (!_isDrawerOpen) {
                  setState(() {
                    _isDrawerOpen = true;
                  });
                }
              },
              child: ListTile(
                leading: Icon(
                  item['icon'],
                  color: _selectedIndex == item['index']
                      ? Colors.white
                      : Colors.white70,
                ),
                title: _isDrawerOpen
                    ? Text(
                        item['title'],
                        style: TextStyle(
                          color: _selectedIndex == item['index']
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: _selectedIndex == item['index']
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _selectedIndex = item['index'];
                    _isDrawerOpen = true;
                  });
                },
                selected: _selectedIndex == item['index'],
                selectedTileColor: Colors.teal[700],
                tileColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isDrawerOpen ? 20 : 12,
                  vertical: 8,
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hasPaidConsultation
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hasPaidConsultation ? Colors.green : Colors.orange,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasPaidConsultation ? Icons.verified : Icons.warning,
                  color: _hasPaidConsultation ? Colors.green : Colors.orange,
                  size: 16,
                ),
                if (_isDrawerOpen) const SizedBox(width: 8),
                if (_isDrawerOpen)
                  Flexible(
                    child: Text(
                      _hasPaidConsultation
                          ? 'Payment Verified'
                          : _paymentStatus == 'pending'
                              ? 'Payment Pending'
                              : 'Payment Required',
                      style: TextStyle(
                        color:
                            _hasPaidConsultation ? Colors.green : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildProfileInfo();
      case 2:
        return _buildAllLawyers();
      case 3:
        return _buildMyRequests();
      case 4:
        return _buildChatHistory();
      case 5:
        return _buildPaymentHistory();
      case 6:
        return _buildSettings();
      default:
        return _buildDashboard();
    }
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Client Dashboard';
      case 1:
        return 'Profile Information';
      case 2:
        return 'Available Lawyers';
      case 3:
        return 'My Consultation Requests';
      case 4:
        return 'Chat History';
      case 5:
        return 'Payment History';
      case 6:
        return 'Settings';
      default:
        return 'Client Dashboard';
    }
  }

  // ================= DASHBOARD =================
  Widget _buildDashboard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade50,
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.teal.shade100,
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, $clientName! 👋',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _hasPaidConsultation
                                    ? 'Ready to connect with lawyers!'
                                    : _paymentStatus == 'pending'
                                        ? 'Waiting for admin approval'
                                        : 'Pay consultation fee to get started',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildDashboardStat(
                          'Payment Status',
                          _paymentStatus.toUpperCase(),
                          _hasPaidConsultation
                              ? Icons.check_circle
                              : _paymentStatus == 'pending'
                                  ? Icons.pending
                                  : Icons.payment,
                          _hasPaidConsultation
                              ? Colors.green
                              : _paymentStatus == 'pending'
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        const SizedBox(width: 15),
                        _buildDashboardStat(
                          'Active Requests',
                          pendingRequestLawyerId != null ? '1' : '0',
                          Icons.request_page,
                          pendingRequestLawyerId != null
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        const SizedBox(width: 15),
                        _buildDashboardStat(
                          'Available Lawyers',
                          _hasPaidConsultation
                              ? _allLawyers
                                  .where(
                                      (lawyer) => lawyer['isApproved'] == true)
                                  .length
                                  .toString()
                              : 'Locked',
                          Icons.people,
                          _hasPaidConsultation ? Colors.purple : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  _hasPaidConsultation ? 'Connect with Lawyer' : 'View Lawyers',
                  Icons.people,
                  _hasPaidConsultation ? Colors.blue : Colors.grey,
                  () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
                _buildActionCard(
                  'View My Requests',
                  Icons.request_page,
                  _hasPaidConsultation ? Colors.orange : Colors.grey,
                  () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                ),
                _buildActionCard(
                  'Update Profile',
                  Icons.edit,
                  Colors.green,
                  () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
                _buildActionCard(
                  'Payment History',
                  Icons.payment,
                  Colors.purple,
                  () {
                    setState(() {
                      _selectedIndex = 5;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (pendingRequestLawyerId != null &&
                activeRequestData != null &&
                _hasPaidConsultation)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Request Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.teal),
                        title: Text(
                          activeRequestData?['lawyerName'] ?? 'Unknown Lawyer',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Status: ${activeRequestData?['status']?.toUpperCase() ?? 'PENDING'}',
                          style: TextStyle(
                            color: _getStatusColor(
                                activeRequestData?['status'] ?? 'pending'),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            if (activeRequestData?['status'] == 'accepted') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    clientId: clientId,
                                    lawyerId: pendingRequestLawyerId!,
                                    lawyerName:
                                        activeRequestData?['lawyerName'] ??
                                            'Unknown',
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                activeRequestData?['status'] == 'accepted'
                                    ? Colors.green
                                    : Colors.grey,
                          ),
                          child: const Text(
                            'Chat',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_hasPaidConsultation)
              Card(
                elevation: 4,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.orange.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _paymentStatus == 'pending'
                                ? Icons.pending
                                : Icons.payment,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _paymentStatus == 'pending'
                                ? 'Payment Pending Approval'
                                : 'Consultation Fee Required',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _paymentStatus == 'pending'
                            ? 'Your payment is under review by admin. Please wait for approval.'
                            : 'To connect with lawyers and get legal advice, you need to pay the consultation fee first.',
                        style: TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 10),
                      if (_paymentStatus != 'pending')
                        ElevatedButton(
                          onPressed: () {
                            _showPaymentDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text(
                            'Pay Now',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStat(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ================= PROFILE INFO =================
  Widget _buildProfileInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profile Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: Colors.teal,
                        onPressed: () {
                          _showEditProfileDialog();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField('Full Name', clientName),
                  _buildProfileField('Email', clientEmail),
                  _buildProfileField('Phone', clientPhone),
                  _buildProfileField('Case Type', caseType),
                  _buildProfileField('User ID', clientId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(
                        _hasPaidConsultation ? Icons.verified : Icons.payment,
                        color:
                            _hasPaidConsultation ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasPaidConsultation
                                  ? 'Consultation Fee Approved'
                                  : _paymentStatus == 'pending'
                                      ? 'Payment Pending Approval'
                                      : 'Consultation Fee Required',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _hasPaidConsultation
                                  ? 'You can connect with any lawyer'
                                  : _paymentStatus == 'pending'
                                      ? 'Admin is reviewing your payment'
                                      : 'Pay Rs. 2,000 to connect with lawyers',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_hasPaidConsultation && _paymentStatus != 'pending')
                        ElevatedButton(
                          onPressed: _showPaymentDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Text(
                            'Pay Now',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ));
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: clientName);
    final phoneController = TextEditingController(text: clientPhone);
    final caseController = TextEditingController(text: caseType);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: caseController,
                decoration: const InputDecoration(
                  labelText: 'Case Type',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('clients')
                    .doc(clientId)
                    .update({
                  'fullName': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'caseType': caseController.text.trim(),
                });

                setState(() {
                  clientName = nameController.text.trim();
                  clientPhone = phoneController.text.trim();
                  caseType = caseController.text.trim();
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ================= ALL LAWYERS =================
  Widget _buildAllLawyers() {
    if (!_hasPaidConsultation) {
      return _buildPaymentRequiredScreen();
    }

    // Client-side filtering for approved lawyers
    final approvedLawyers = _allLawyers.where((lawyer) {
      return lawyer['isApproved'] == true;
    }).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Available Lawyers",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "Your payment is approved! Connect with lawyers",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "${approvedLawyers.length} approved lawyer${approvedLawyers.length != 1 ? 's' : ''} found",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: approvedLawyers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        "No approved lawyers available yet.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Check back later for available lawyers",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _refreshLawyers();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: approvedLawyers.length,
                    itemBuilder: (context, index) {
                      final lawyer = approvedLawyers[index];
                      final lawyerId = lawyer['id'];
                      final isOnline = lawyer['isOnline'] ?? false;
                      final specialization =
                          lawyer['specialization'] ?? 'General Practice';
                      final experience =
                          lawyer['experience'] ?? 'Not specified';
                      final name = lawyer['name'] ?? 'No Name';
                      final email = lawyer['email'] ?? 'No Email';

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.teal.shade100,
                                        child: Icon(
                                          Icons.person,
                                          size: 30,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isOnline
                                                ? Colors.green
                                                : Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      _showRequestOptions(
                                          context, lawyerId, lawyer);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Connect',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Icon(
                                    Icons.work,
                                    size: 16,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Specialization: $specialization',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timeline,
                                    size: 16,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Experience: $experience',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Consultation Fee: Rs. 2,000',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _refreshLawyers() async {
    try {
      final lawyersSnapshot =
          await FirebaseFirestore.instance.collection('lawyers').get();

      setState(() {
        _allLawyers = lawyersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
      });
    } catch (e) {
      print("Error refreshing lawyers: $e");
    }
  }

  void _showRequestOptions(
      BuildContext context, String lawyerId, Map<String, dynamic> lawyer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Connect with Lawyer",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lawyer['name'] ?? 'Lawyer',
              style: TextStyle(
                fontSize: 16,
                color: Colors.teal.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text("Send Request"),
              subtitle: const Text("Send chat request to lawyer"),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.pop(context);
                _sendRequestToLawyer(lawyerId, lawyer);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendRequestToLawyer(
      String lawyerId, Map<String, dynamic> lawyer) async {
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
        'lawyerEmail': lawyer['email'] ?? 'Unknown',
        'status': 'pending',
        'isPaid': true,
        'paymentVerified': true,
        'timestamp': FieldValue.serverTimestamp(),
        'requestTime': DateTime.now().toIso8601String(),
        'consultationFee': 2000,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request sent to lawyer!"),
            backgroundColor: Colors.green,
          ),
        );

        // Update local data
        _myRequests.add({
          'id': requestDocId,
          'clientId': clientId,
          'assignedLawyerId': lawyerId,
          'lawyerName': lawyer['name'] ?? 'Unknown',
          'status': 'pending',
          'timestamp': Timestamp.now(),
        });

        setState(() {
          pendingRequestLawyerId = lawyerId;
          activeRequestData = {
            'status': 'pending',
            'lawyerName': lawyer['name'] ?? 'Unknown',
          };
          _selectedIndex = 3;
        });
      }
    } catch (e) {
      print("Error sending request: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshRequests() async {
    try {
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('client_requests')
          .where('clientId', isEqualTo: clientId)
          .get();

      setState(() {
        _myRequests = requestsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
      });
    } catch (e) {
      print("Error refreshing requests: $e");
    }
  }

  // ================= MY REQUESTS =================
  Widget _buildMyRequests() {
    if (!_hasPaidConsultation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              _paymentStatus == 'pending'
                  ? "Payment Pending Approval"
                  : "Payment Required",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _paymentStatus == 'pending'
                  ? "Your payment is under review by admin. Please wait for approval."
                  : "You need to have an approved payment\nto send requests to lawyers",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            if (_paymentStatus != 'pending')
              ElevatedButton(
                onPressed: _showPaymentDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                ),
                child: const Text(
                  'Pay Consultation Fee',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      );
    }

    // Sort requests by timestamp (client-side)
    _myRequests.sort((a, b) {
      final timeA = a['timestamp'] ?? Timestamp.now();
      final timeB = b['timestamp'] ?? Timestamp.now();
      return (timeB as Timestamp).compareTo(timeA as Timestamp);
    });

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              const Row(
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "My Consultation Requests",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          "Your payment is approved - Connect with lawyers",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromRGBO(255, 255, 255, 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "${_myRequests.length} request${_myRequests.length != 1 ? 's' : ''} found",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _myRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.request_page,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        "No requests yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Connect with a lawyer to get started",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 2;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text(
                          'Browse Lawyers',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _refreshRequests();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myRequests.length,
                    itemBuilder: (context, index) {
                      final request = _myRequests[index];
                      final requestId = request['id'];
                      final status = request['status'] ?? 'pending';
                      final lawyerName = request['lawyerName'] ?? 'Unknown';
                      final timestamp = request['timestamp'] as Timestamp?;
                      final scheduledDate = request['scheduledDate'];
                      final scheduledTime = request['scheduledTime'];

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    lawyerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    request['lawyerEmail'] ?? 'No email',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              if (scheduledDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Scheduled: ${_formatDate(scheduledDate)} ${scheduledTime != null ? 'at $scheduledTime' : ''}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  if (status == 'accepted')
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(
                                              clientId: clientId,
                                              lawyerId:
                                                  request['assignedLawyerId'],
                                              lawyerName: lawyerName,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text(
                                        'Start Chat',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  if (status == 'pending' ||
                                      status == 'scheduled')
                                    OutlinedButton(
                                      onPressed: () {
                                        _showCancelRequestDialog(
                                            requestId, lawyerName);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side:
                                            const BorderSide(color: Colors.red),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (timestamp != null)
                                    Text(
                                      _formatDate(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showCancelRequestDialog(String requestId, String lawyerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text(
            'Are you sure you want to cancel your request to $lawyerName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('client_requests')
                    .doc(requestId)
                    .update({
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PAYMENT REQUIRED SCREEN =================
  Widget _buildPaymentRequiredScreen() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey[50],
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 100,
                color: Colors.orange[700],
              ),
              const SizedBox(height: 20),
              Text(
                _paymentStatus == 'pending'
                    ? "Payment Pending Approval"
                    : "Consultation Fee Required",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _paymentStatus == 'pending'
                    ? "Your payment is under review by admin. Please wait for approval."
                    : "To connect with lawyers and get legal advice, you need to pay the consultation fee first.",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Consultation Fee",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Rs. 2,000",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Once payment is approved by admin, you can:\n• Connect with any lawyer\n• Send chat requests\n• Get legal consultation",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      if (_paymentStatus == 'pending')
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Row(
                            children: [
                              const Icon(Icons.info, color: Colors.blue),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Payment submitted on: ${_getLatestPaymentDate()}",
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (_paymentStatus != 'pending' && _paymentStatus != 'approved')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentFormScreen(
                          clientId: clientId,
                          clientName: clientName,
                          clientEmail: clientEmail,
                          clientPhone: clientPhone,
                          onPaymentSubmitted: () {
                            _checkPaymentStatus();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text("Pay Consultation Fee Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  _showPaymentInstructions();
                },
                child: const Text("View Payment Instructions"),
              ),
              if (_paymentStatus == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      const Text(
                        "Waiting for admin approval...",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLatestPaymentDate() {
    if (_payments.isEmpty) return 'Not submitted';
    final latestPayment = _payments.first;
    final timestamp = latestPayment['timestamp'] as Timestamp?;
    if (timestamp != null) {
      return _formatDate(timestamp);
    }
    return 'Recently';
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay Consultation Fee'),
        content: const Text(
            'You need to pay Rs. 2,000 consultation fee to connect with lawyers. Proceed to payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentFormScreen(
                    clientId: clientId,
                    clientName: clientName,
                    clientEmail: clientEmail,
                    clientPhone: clientPhone,
                    onPaymentSubmitted: () {
                      _checkPaymentStatus();
                    },
                  ),
                ),
              );
            },
            child: const Text('Proceed to Payment'),
          ),
        ],
      ),
    );
  }

  void _showPaymentInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payment Instructions"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("Please follow these steps:"),
              SizedBox(height: 10),
              Text("1. Send Rs. 2000 to EasyPaisa/JazzCash"),
              Text("2. Take screenshot of successful transaction"),
              Text("3. Upload screenshot in payment form"),
              Text("4. Wait for admin approval (usually within 24 hours)"),
              SizedBox(height: 10),
              Text(
                "Note: Once payment is approved, you can connect with any lawyer.",
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
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

  // ================= CHAT HISTORY =================
  Widget _buildChatHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Chat History',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Feature coming soon',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ================= PAYMENT HISTORY =================
  Widget _buildPaymentHistory() {
    // Sort payments by timestamp (client-side)
    _payments.sort((a, b) {
      final timeA = a['timestamp'] ?? Timestamp.now();
      final timeB = b['timestamp'] ?? Timestamp.now();
      return (timeB as Timestamp).compareTo(timeA as Timestamp);
    });

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
                "Payment History",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "${_payments.length} payment${_payments.length != 1 ? 's' : ''} found",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              if (_hasPaidConsultation)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.white, size: 20),
                      const SizedBox(width: 5),
                      const Text(
                        "Your payment is approved!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment, size: 80, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        "No payments yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Pay consultation fee to get started",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _showPaymentDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text(
                          'Make Payment',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadPayments();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      final status = payment['status'] ?? 'pending';
                      final amount = payment['amount'] ?? 0;
                      final timestamp = payment['timestamp'] as Timestamp?;
                      final approvedBy = payment['approvedBy'] ?? 'Admin';
                      final approvedAt = payment['approvedAt'] as Timestamp?;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Payment ID: ${payment['paymentId']?.toString().substring(0, 8) ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status == 'approved'
                                          ? Colors.green.withOpacity(0.1)
                                          : status == 'pending'
                                              ? Colors.orange.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: status == 'approved'
                                            ? Colors.green
                                            : status == 'pending'
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: status == 'approved'
                                            ? Colors.green
                                            : status == 'pending'
                                                ? Colors.orange
                                                : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.attach_money,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Amount: Rs. $amount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              if (timestamp != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Submitted: ${_formatDate(timestamp)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              if (status == 'approved' && approvedAt != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Approved by: $approvedBy',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Approved on: ${_formatDate(approvedAt)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              if (status == 'rejected')
                                const SizedBox(height: 5),
                              if (status == 'rejected')
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cancel,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Reason: ${payment['rejectionReason'] ?? 'Not specified'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ================= SETTINGS =================
  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Push Notifications'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {},
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email Notifications'),
                    trailing: Switch(
                      value: true,
                      onChanged: (value) {},
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Privacy Settings'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About App'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not set';
    if (date is Timestamp) {
      final dt = date.toDate();
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return date.toString();
  }
}

// ================= PAYMENT FORM SCREEN =================
class PaymentFormScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final VoidCallback onPaymentSubmitted;

  const PaymentFormScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.onPaymentSubmitted,
  });

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clientName);
    _emailController = TextEditingController(text: widget.clientEmail);
    _phoneController = TextEditingController(text: widget.clientPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to pick image: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _getImageBase64() async {
    if (_selectedImage == null || _imageBytes == null) return null;

    try {
      return base64Encode(_imageBytes!);
    } catch (e) {
      print("Error converting to base64: $e");
      return null;
    }
  }

  Future<void> _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImage == null || _imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please upload payment receipt"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final base64Image = await _getImageBase64();

        if (base64Image == null) {
          throw Exception("Failed to process image");
        }

        final paymentId =
            "${widget.clientId}_${DateTime.now().millisecondsSinceEpoch}";

        await FirebaseFirestore.instance
            .collection('payments')
            .doc(paymentId)
            .set({
          'paymentId': paymentId,
          'clientId': widget.clientId,
          'clientName': _nameController.text.trim(),
          'clientEmail': _emailController.text.trim(),
          'clientPhone': _phoneController.text.trim(),
          'amount': 2000,
          'status': 'pending',
          'receiptImage': base64Image,
          'timestamp': FieldValue.serverTimestamp(),
          'submittedAt': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : 'mobile',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Payment submitted successfully! Waiting for admin approval."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          widget.onPaymentSubmitted();
          Navigator.pop(context);
        }
      } on FirebaseException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Firestore Error: ${e.message}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error submitting payment: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Consultation Fee"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "Consultation Fee",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Rs. 2,000",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Pay using EasyPaisa/JazzCash and upload the receipt screenshot",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Client Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 11) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "Upload Payment Receipt",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: _imageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Tap to upload receipt screenshot",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "Supported: JPG, PNG",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                ),
              ),
              if (_imageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.change_circle),
                        label: const Text("Change Image"),
                      ),
                      const SizedBox(width: 20),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _imageBytes = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          "Remove",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    _isSubmitting
                        ? "Submitting..."
                        : "Submit Payment for Approval",
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 214, 234, 216),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color.fromARGB(255, 12, 12, 12)!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Important:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 93, 111, 231),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "• Send Rs. 2000 to EasyPaisa/JazzCash account",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      "• Take screenshot of successful transaction",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      "• Admin will verify within 24 hours",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      "• You can connect with lawyers after approval",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= CHAT SCREEN =================
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
    _updateRequestStatus();
  }

  void _updateRequestStatus() async {
    try {
      final requestDocId = "${widget.clientId}_${widget.lawyerId}";
      await FirebaseFirestore.instance
          .collection('client_requests')
          .doc(requestDocId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating request status: $e");
    }
  }

  void _setClientOnline(bool online) async {
    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .update({'isOnline': online});
    } catch (e) {
      print("Error setting client online: $e");
    }
  }

  void _updateTyping(bool typing) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set({'clientTyping': typing}, SetOptions(merge: true));
    } catch (e) {
      print("Error updating typing status: $e");
    }
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
      print("Error sending message: $e");
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat, size: 60, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          "No messages yet",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Start the conversation!",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
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
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
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
