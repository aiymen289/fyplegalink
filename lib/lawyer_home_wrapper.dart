import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'lawyer_chat_screen.dart';

class LawyerHomeWrapper extends StatefulWidget {
  const LawyerHomeWrapper({super.key});

  @override
  State<LawyerHomeWrapper> createState() => _LawyerHomeWrapperState();
}

class _LawyerHomeWrapperState extends State<LawyerHomeWrapper> {
  final User? user = FirebaseAuth.instance.currentUser;
  late String lawyerId;
  bool _isDrawerOpen = true;
  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _lawyerData;
  int _pendingRequests = 0;
  int _acceptedRequests = 0;
  int _scheduledSessions = 0;
  double _earnings = 0.0;

  // For caching
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _earningsHistory = [];
  List<Map<String, dynamic>> _chatHistory = [];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'title': 'Dashboard', 'index': 0},
    {'icon': Icons.person, 'title': 'Profile Info', 'index': 1},
    {'icon': Icons.notifications, 'title': 'Client Requests', 'index': 2},
    {'icon': Icons.calendar_today, 'title': 'Schedule', 'index': 3},
    {'icon': Icons.chat, 'title': 'Chats', 'index': 4},
    {'icon': Icons.attach_money, 'title': 'Earnings', 'index': 5},
    {'icon': Icons.settings, 'title': 'Settings', 'index': 6},
  ];

  @override
  void initState() {
    super.initState();
    lawyerId = user?.uid ?? '';
    if (lawyerId.isEmpty) {
      _isLoading = false;
      return;
    }
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _getLawyerProfile();
      await _loadAllRequests();
      await _loadEarnings();
      await _loadChatHistory();
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

  Future<void> _getLawyerProfile() async {
    try {
      final lawyerDoc = await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(lawyerId)
          .get();

      if (lawyerDoc.exists) {
        setState(() {
          _lawyerData = lawyerDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print("Error getting lawyer profile: $e");
    }
  }

  Future<void> _loadAllRequests() async {
    try {
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('client_requests')
          .where('assignedLawyerId', isEqualTo: lawyerId)
          .get();

      _allRequests = requestsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      _updateRequestCounts();
    } catch (e) {
      print("Error loading requests: $e");
    }
  }

  void _updateRequestCounts() {
    int pending = 0;
    int accepted = 0;
    int scheduled = 0;

    for (var request in _allRequests) {
      final status = request['status'] ?? 'pending';
      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'accepted':
          accepted++;
          break;
        case 'scheduled':
          scheduled++;
          break;
      }
    }

    setState(() {
      _pendingRequests = pending;
      _acceptedRequests = accepted;
      _scheduledSessions = scheduled;
    });
  }

  Future<void> _loadEarnings() async {
    try {
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('lawyerId', isEqualTo: lawyerId)
          .where('status', isEqualTo: 'approved')
          .get();

      double totalEarnings = 0.0;
      _earningsHistory = paymentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = data['amount'] ?? 0;
        totalEarnings += (amount is int ? amount.toDouble() : amount);
        return {'id': doc.id, ...data};
      }).toList();

      setState(() {
        _earnings = totalEarnings;
      });
    } catch (e) {
      print("Error loading earnings: $e");
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final chatSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('lawyerId', isEqualTo: lawyerId)
          .get();

      _chatHistory = chatSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print("Error loading chat history: $e");
    }
  }

  void _setupListeners() {
    // Listen for new requests
    FirebaseFirestore.instance
        .collection('client_requests')
        .where('assignedLawyerId', isEqualTo: lawyerId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _allRequests = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
          _updateRequestCounts();
        });
      }
    });

    // Listen for payments
    FirebaseFirestore.instance
        .collection('payments')
        .where('lawyerId', isEqualTo: lawyerId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        double totalEarnings = 0.0;
        _earningsHistory = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = data['amount'] ?? 0;
          totalEarnings += (amount is int ? amount.toDouble() : amount);
          return {'id': doc.id, ...data};
        }).toList();

        setState(() {
          _earnings = totalEarnings;
        });
      }
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null || lawyerId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                "Authentication Error",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Please login again"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text("Go to Login"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.deepPurple,
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
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _lawyerData?['name']?.toString().substring(0, 1) ?? 'L',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
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
                    color: Colors.deepPurple[900],
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
                    radius: 50,
                    backgroundColor: Colors.deepPurple[100],
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.deepPurple[900],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _lawyerData?['name'] ?? 'Lawyer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _lawyerData?['specialization'] ?? 'General Practice',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[700],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
                selectedTileColor: Colors.deepPurple[700],
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
          if (_isDrawerOpen)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple[700],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    "Earnings",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Rs. ${_earnings.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Total Revenue",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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
        return _buildClientRequests();
      case 3:
        return _buildSchedule();
      case 4:
        return _buildChats();
      case 5:
        return _buildEarnings();
      case 6:
        return _buildSettings();
      default:
        return _buildDashboard();
    }
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Lawyer Dashboard';
      case 1:
        return 'Profile Information';
      case 2:
        return 'Client Requests';
      case 3:
        return 'Schedule';
      case 4:
        return 'Chats';
      case 5:
        return 'Earnings';
      case 6:
        return 'Settings';
      default:
        return 'Lawyer Dashboard';
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
            Colors.deepPurple.shade50,
            Colors.indigo.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_lawyerData?['name'] ?? 'Lawyer'}! 👨‍⚖️',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _lawyerData?['specialization'] ??
                                'General Practice',
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
              ),
            ),

            const SizedBox(height: 20),

            // Stats Row
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  'Pending Requests',
                  _pendingRequests.toString(),
                  Icons.notifications_active,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Active Chats',
                  _acceptedRequests.toString(),
                  Icons.chat,
                  Colors.green,
                ),
                _buildStatCard(
                  'Scheduled',
                  _scheduledSessions.toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Earnings',
                  'Rs. ${_earnings.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 2,
              children: [
                _buildActionCard(
                  'View Requests',
                  Icons.notifications,
                  Colors.deepPurple,
                  () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
                _buildActionCard(
                  'Check Schedule',
                  Icons.calendar_today,
                  Colors.blue,
                  () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                ),
                _buildActionCard(
                  'Start Chat',
                  Icons.chat,
                  Colors.green,
                  () {
                    setState(() {
                      _selectedIndex = 4;
                    });
                  },
                ),
                _buildActionCard(
                  'Update Profile',
                  Icons.edit,
                  Colors.orange,
                  () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Recent Requests
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
                    const Row(
                      children: [
                        Icon(Icons.history, color: Colors.deepPurple),
                        SizedBox(width: 10),
                        Text(
                          'Recent Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildRecentRequests(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
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
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: color.withOpacity(0.5), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRequests() {
    final recentRequests = _allRequests
        .where(
            (req) => req['status'] == 'pending' || req['status'] == 'accepted')
        .take(5)
        .toList();

    if (recentRequests.isEmpty) {
      return const Column(
        children: [
          Icon(Icons.notifications_off, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            "No recent requests",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      children: recentRequests.map((request) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            child: const Icon(Icons.person, color: Colors.deepPurple),
          ),
          title: Text(request['clientName'] ?? 'Client'),
          subtitle:
              Text('Status: ${request['status']?.toUpperCase() ?? 'PENDING'}'),
          trailing: Chip(
            label: Text(
              request['status'] == 'pending' ? 'New' : 'Active',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            backgroundColor:
                request['status'] == 'pending' ? Colors.orange : Colors.green,
          ),
          onTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        );
      }).toList(),
    );
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
                          color: Colors.deepPurple,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: Colors.deepPurple,
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                      'Full Name', _lawyerData?['name'] ?? 'N/A'),
                  _buildProfileField('Email', _lawyerData?['email'] ?? 'N/A'),
                  _buildProfileField('Phone', _lawyerData?['phone'] ?? 'N/A'),
                  _buildProfileField('City', _lawyerData?['city'] ?? 'N/A'),
                  _buildProfileField(
                    'Specialization',
                    _lawyerData?['specialization'] ?? 'General Practice',
                  ),
                  _buildProfileField(
                    'Experience',
                    _lawyerData?['experience'] ?? 'Not specified',
                  ),
                  _buildProfileField(
                    'Bar License',
                    _lawyerData?['barLicense'] ?? 'N/A',
                  ),
                  _buildProfileField(
                    'Consultation Fee',
                    'Rs. ${_lawyerData?['consultationFee'] ?? '2000'}',
                  ),
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
                    'Professional Bio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _lawyerData?['bio'] ?? 'No bio provided',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController =
        TextEditingController(text: _lawyerData?['name'] ?? '');
    final phoneController =
        TextEditingController(text: _lawyerData?['phone'] ?? '');
    final cityController =
        TextEditingController(text: _lawyerData?['city'] ?? '');
    final specializationController =
        TextEditingController(text: _lawyerData?['specialization'] ?? '');
    final experienceController =
        TextEditingController(text: _lawyerData?['experience'] ?? '');
    final licenseController =
        TextEditingController(text: _lawyerData?['barLicense'] ?? '');
    final bioController =
        TextEditingController(text: _lawyerData?['bio'] ?? '');
    final feeController = TextEditingController(
        text: (_lawyerData?['consultationFee'] ?? 2000).toString());

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
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: specializationController,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: experienceController,
                decoration: const InputDecoration(
                  labelText: 'Experience (e.g., 5 years)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: licenseController,
                decoration: const InputDecoration(
                  labelText: 'Bar License Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: feeController,
                decoration: const InputDecoration(
                  labelText: 'Consultation Fee (Rs.)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Professional Bio',
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
                    .collection('lawyers')
                    .doc(lawyerId)
                    .update({
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'city': cityController.text.trim(),
                  'specialization': specializationController.text.trim(),
                  'experience': experienceController.text.trim(),
                  'barLicense': licenseController.text.trim(),
                  'consultationFee': int.tryParse(feeController.text) ?? 2000,
                  'bio': bioController.text.trim(),
                });

                await _getLawyerProfile();

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

  // ================= CLIENT REQUESTS =================
  Widget _buildClientRequests() {
    final pendingRequests =
        _allRequests.where((req) => req['status'] == 'pending').toList();
    final acceptedRequests =
        _allRequests.where((req) => req['status'] == 'accepted').toList();
    final scheduledRequests =
        _allRequests.where((req) => req['status'] == 'scheduled').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade700
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Client Requests",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "${_allRequests.length} total request${_allRequests.length != 1 ? 's' : ''}",
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
                const SizedBox(height: 10),
                TabBar(
                  tabs: const [
                    Tab(text: 'Pending'),
                    Tab(text: 'Accepted'),
                    Tab(text: 'Scheduled'),
                  ],
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRequestList(pendingRequests, 'pending'),
                _buildRequestList(acceptedRequests, 'accepted'),
                _buildRequestList(scheduledRequests, 'scheduled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests, String status) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending'
                  ? Icons.notifications_off
                  : status == 'accepted'
                      ? Icons.chat
                      : Icons.calendar_today,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              status == 'pending'
                  ? "No pending requests"
                  : status == 'accepted'
                      ? "No active chats"
                      : "No scheduled sessions",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          final requestId = request['id'];
          final clientId = request['clientId'];
          final clientName = request['clientName'] ?? 'Client';
          final clientEmail = request['clientEmail'] ?? 'No Email';
          final timestamp = request['timestamp'] as Timestamp?;
          final scheduledDate = request['scheduledDate'] as Timestamp?;
          final scheduledTime = request['scheduledTime'];
          final legalIssue = request['legalIssue'];

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
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.deepPurple.shade100,
                        child:
                            const Icon(Icons.person, color: Colors.deepPurple),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              clientEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Online status
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('clients')
                            .doc(clientId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final isOnline = snapshot.hasData &&
                                  snapshot.data!.exists
                              ? (snapshot.data!.data()
                                      as Map<String, dynamic>)['isOnline'] ??
                                  false
                              : false;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 4,
                                  backgroundColor:
                                      isOnline ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isOnline ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (legalIssue != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Legal Issue:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(legalIssue),
                      ],
                    ),
                  if (scheduledDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.blue),
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
                      if (status == 'pending')
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text('Accept & Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _acceptRequest(requestId, clientId, clientName);
                            },
                          ),
                        ),
                      if (status == 'pending') const SizedBox(width: 10),
                      if (status == 'pending')
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Schedule'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blue),
                              foregroundColor: Colors.blue,
                            ),
                            onPressed: () {
                              _scheduleRequest(requestId);
                            },
                          ),
                        ),
                      if (status == 'accepted')
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text('Open Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LawyerChatScreen(
                                    lawyerId: lawyerId,
                                    clientId: clientId,
                                    clientName: clientName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (status == 'scheduled')
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Mark as Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _completeRequest(requestId);
                            },
                          ),
                        ),
                      if (status == 'scheduled') const SizedBox(width: 10),
                      if (status == 'scheduled')
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () {
                              _cancelSchedule(requestId);
                            },
                          ),
                        ),
                    ],
                  ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _formatDate(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(
      String requestId, String clientId, String clientName) async {
    try {
      await FirebaseFirestore.instance
          .collection('client_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LawyerChatScreen(
            lawyerId: lawyerId,
            clientId: clientId,
            clientName: clientName,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleRequest(String requestId) async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );

    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        try {
          await FirebaseFirestore.instance
              .collection('client_requests')
              .doc(requestId)
              .update({
            'status': 'scheduled',
            'scheduledDate': Timestamp.fromDate(selectedDate),
            'scheduledTime':
                '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}',
            'scheduledAt': FieldValue.serverTimestamp(),
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session scheduled successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _completeRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('client_requests')
          .doc(requestId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session marked as complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelSchedule(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('client_requests')
          .doc(requestId)
          .update({
        'status': 'pending',
        'scheduledDate': FieldValue.delete(),
        'scheduledTime': FieldValue.delete(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ================= SCHEDULE =================
  Widget _buildSchedule() {
    final scheduledSessions =
        _allRequests.where((req) => req['status'] == 'scheduled').toList();

    // Sort by scheduled date
    scheduledSessions.sort((a, b) {
      final dateA = a['scheduledDate'] as Timestamp?;
      final dateB = b['scheduledDate'] as Timestamp?;
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Schedule",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "${scheduledSessions.length} scheduled session${scheduledSessions.length != 1 ? 's' : ''}",
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
            ],
          ),
        ),
        Expanded(
          child: scheduledSessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        "No scheduled sessions",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Schedule sessions from client requests",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scheduledSessions.length,
                  itemBuilder: (context, index) {
                    final session = scheduledSessions[index];
                    final scheduledDate =
                        session['scheduledDate'] as Timestamp?;
                    final scheduledTime = session['scheduledTime'];
                    final clientName = session['clientName'] ?? 'Client';
                    final legalIssue = session['legalIssue'];

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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person,
                                      color: Colors.blue),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    clientName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.blue),
                                SizedBox(width: 5),
                                Text(
                                  scheduledDate != null
                                      ? '${_formatDate(scheduledDate)}'
                                      : 'Date not set',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            if (scheduledTime != null)
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 16, color: Colors.blue),
                                  SizedBox(width: 5),
                                  Text(
                                    'Time: $scheduledTime',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            if (legalIssue != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 10),
                                  Text(
                                    'Legal Issue: $legalIssue',
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text('Start Chat'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LawyerChatScreen(
                                            lawyerId: lawyerId,
                                            clientId: session['clientId'],
                                            clientName: clientName,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.check_circle,
                                        size: 16),
                                    label: const Text('Complete'),
                                    style: OutlinedButton.styleFrom(
                                      side:
                                          const BorderSide(color: Colors.green),
                                      foregroundColor: Colors.green,
                                    ),
                                    onPressed: () {
                                      _completeRequest(session['id']);
                                    },
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
      ],
    );
  }

  // ================= CHATS =================
  Widget _buildChats() {
    final activeChats =
        _allRequests.where((req) => req['status'] == 'accepted').toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.chat, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Active Chats",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "${activeChats.length} active chat${activeChats.length != 1 ? 's' : ''}",
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
            ],
          ),
        ),
        Expanded(
          child: activeChats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        "No active chats",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Accept client requests to start chatting",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeChats.length,
                  itemBuilder: (context, index) {
                    final chat = activeChats[index];
                    final clientId = chat['clientId'];
                    final clientName = chat['clientName'] ?? 'Client';
                    final lastMessage = chat['lastMessage'];
                    final lastMessageTime =
                        chat['lastMessageTime'] as Timestamp?;
                    final unreadCount = chat['unreadCount'] ?? 0;

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc('${lawyerId}_$clientId')
                          .snapshots(),
                      builder: (context, snapshot) {
                        bool isTyping = false;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          isTyping = data['clientTyping'] ?? false;
                        }

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.deepPurple.shade100,
                                  child: const Icon(Icons.person,
                                      color: Colors.deepPurple),
                                ),
                                // Online indicator
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('clients')
                                      .doc(clientId)
                                      .snapshots(),
                                  builder: (context, clientSnap) {
                                    final isOnline = clientSnap.hasData &&
                                            clientSnap.data!.exists
                                        ? (clientSnap.data!.data() as Map<
                                                String, dynamic>)['isOnline'] ??
                                            false
                                        : false;
                                    return Positioned(
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
                                    );
                                  },
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    clientName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                if (isTyping)
                                  const Text(
                                    "Client is typing...",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else if (lastMessage != null)
                                  Text(
                                    lastMessage.length > 30
                                        ? '${lastMessage.substring(0, 30)}...'
                                        : lastMessage,
                                    style: const TextStyle(color: Colors.grey),
                                  )
                                else
                                  const Text(
                                    "No messages yet",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: lastMessageTime != null
                                ? Text(
                                    _formatTime(lastMessageTime),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LawyerChatScreen(
                                    lawyerId: lawyerId,
                                    clientId: clientId,
                                    clientName: clientName,
                                  ),
                                ),
                              );
                            },
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

  // ================= EARNINGS =================
  Widget _buildEarnings() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Earnings",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "Total: Rs. ${_earnings.toStringAsFixed(0)}",
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
            ],
          ),
        ),
        Expanded(
          child: _earningsHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_money, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        "No earnings yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Complete sessions to earn revenue",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _earningsHistory.length,
                  itemBuilder: (context, index) {
                    final payment = _earningsHistory[index];
                    final amount = payment['amount'] ?? 0;
                    final clientName = payment['clientName'] ?? 'Client';
                    final timestamp = payment['timestamp'] as Timestamp?;
                    final paymentId = payment['paymentId'] ?? 'N/A';

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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  clientName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Text(
                                    'Rs. $amount',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.credit_card,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Text(
                                  'Payment ID: ${paymentId.toString().substring(0, 8)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Text(
                                  timestamp != null
                                      ? _formatDate(timestamp)
                                      : 'Date not set',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
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
      ],
    );
  }

  // ================= SETTINGS =================
  Widget _buildSettings() {
    bool notifications = true;
    bool emailUpdates = true;

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
              color: Colors.deepPurple,
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
                      value: notifications,
                      onChanged: (value) {
                        setState(() {
                          notifications = value;
                        });
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email Updates'),
                    trailing: Switch(
                      value: emailUpdates,
                      onChanged: (value) {
                        setState(() {
                          emailUpdates = value;
                        });
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Privacy & Security'),
                    onTap: () {
                      // Navigate to privacy settings
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    onTap: () {
                      // Navigate to help
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About'),
                    onTap: () {
                      // Show about dialog
                    },
                  ),
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
                    'Account Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Delete Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _showDeleteAccountDialog();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Delete account logic
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('hh:mm a').format(date);
  }
}
