import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  int _totalClients = 0;
  double _rating = 4.5;
  int _totalReviews = 0;
  bool _isOnline = true;
  Timer? _onlineStatusTimer;
  double _profileCompletion = 0.0;

  // For caching
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _earningsHistory = [];
  List<Map<String, dynamic>> _chatHistory = [];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'title': 'Dashboard', 'index': 0},
    {'icon': Icons.person, 'title': 'Profile', 'index': 1},
    {'icon': Icons.notifications, 'title': 'Requests', 'index': 2},
    {'icon': Icons.calendar_today, 'title': 'Schedule', 'index': 3},
    {'icon': Icons.chat, 'title': 'Chats', 'index': 4},
    {'icon': Icons.attach_money, 'title': 'Earnings', 'index': 5},
    {'icon': Icons.settings, 'title': 'Settings', 'index': 6},
    {'icon': Icons.logout, 'title': 'Logout', 'index': 7},
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
    _startOnlineStatusUpdater();
  }

  @override
  void dispose() {
    _onlineStatusTimer?.cancel();
    _updateOnlineStatus(false);
    super.dispose();
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    try {
      await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(lawyerId)
          .update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating online status: $e");
    }
  }

  void _startOnlineStatusUpdater() {
    _updateOnlineStatus(true);
    _onlineStatusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateOnlineStatus(true);
    });
  }

  Future<void> _initializeData() async {
    try {
      await _getLawyerProfile();
      await _loadAllRequests();
      await _loadEarnings();
      await _loadChatHistory();
      await _loadAdditionalProfileInfo();
      _calculateProfileCompletion();
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

  void _calculateProfileCompletion() {
    if (_lawyerData == null) return;

    double completion = 0.0;
    int totalFields = 0;
    int filledFields = 0;

    List<String> requiredFields = [
      'name',
      'email',
      'phone',
      'city',
      'specialization',
      'experience',
      'barLicense',
      'consultationFee',
      'bio'
    ];

    totalFields = requiredFields.length;

    for (String field in requiredFields) {
      if (_lawyerData?[field] != null &&
          _lawyerData![field].toString().isNotEmpty) {
        filledFields++;
      }
    }

    completion = filledFields / totalFields;

    setState(() {
      _profileCompletion = completion;
    });
  }

  Future<void> _loadAdditionalProfileInfo() async {
    try {
      // Load total clients
      final clientsSnapshot = await FirebaseFirestore.instance
          .collection('client_requests')
          .where('assignedLawyerId', isEqualTo: lawyerId)
          .get();

      final uniqueClients = <String>{};
      for (var doc in clientsSnapshot.docs) {
        uniqueClients.add(doc['clientId']);
      }

      // Load rating and reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('lawyerId', isEqualTo: lawyerId)
          .get();

      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        totalRating += (doc['rating'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _totalClients = uniqueClients.length;
          _totalReviews = reviewsSnapshot.docs.length;
          _rating = reviewsSnapshot.docs.isNotEmpty
              ? totalRating / reviewsSnapshot.docs.length
              : 4.5;
        });
      }
    } catch (e) {
      print("Error loading additional profile info: $e");
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
      return _buildErrorScreen();
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
          _buildNotificationBadge(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Sidebar with enhanced profile - FIXED WITH SCROLL
                _buildEnhancedSidebar(),
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

  Widget _buildEnhancedSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isDrawerOpen ? 300 : 80,
      decoration: BoxDecoration(
        color: Colors.deepPurple[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Enhanced Profile Section
          if (_isDrawerOpen)
            _buildEnhancedProfileSection()
          else
            _buildCollapsedProfileSection(),

          const SizedBox(height: 10),
          const Divider(color: Colors.white54, height: 1),
          const SizedBox(height: 10),

          // Menu Items - FIXED WITH EXPANDED AND SCROLL
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      return _buildMenuItem(item);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Statistics Card
                  if (_isDrawerOpen) _buildStatisticsCard(),

                  const SizedBox(height: 15),

                  // Online Status Toggle
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: _isDrawerOpen ? 20 : 10),
                    child: Row(
                      children: [
                        if (_isDrawerOpen)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    color:
                                        _isOnline ? Colors.green : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        Switch(
                          value: _isOnline,
                          onChanged: (value) {
                            setState(() {
                              _isOnline = value;
                            });
                            _updateOnlineStatus(value);
                          },
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.grey,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Profile Image with Online Status
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 1; // Navigate to Profile
              });
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.deepPurple[100],
                    child: _lawyerData?['profileImage'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(45),
                            child: Image.network(
                              _lawyerData!['profileImage'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.deepPurple[900],
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.deepPurple[900],
                          ),
                  ),
                ),
                // Online Status Badge
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.deepPurple[900]!, width: 2),
                  ),
                  child: Icon(
                    _isOnline ? Icons.circle : Icons.circle_outlined,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Name and Specialization
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 1; // Navigate to Profile
              });
            },
            child: Column(
              children: [
                Text(
                  _lawyerData?['name'] ?? 'Lawyer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 5),

                // Specialization Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _lawyerData?['specialization'] ?? 'General Practice',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Rating and Reviews
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 5),
              Text(
                _rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '($_totalReviews)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Profile Completion
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile: ${(_profileCompletion * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1; // Navigate to Profile
                      });
                    },
                    child: Text(
                      'Complete',
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: _profileCompletion,
                backgroundColor: Colors.deepPurple[700],
                color: _profileCompletion >= 0.8
                    ? Colors.green
                    : _profileCompletion >= 0.5
                        ? Colors.orange
                        : Colors.red,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isDrawerOpen = true;
              });
            },
            onDoubleTap: () {
              setState(() {
                _selectedIndex = 1; // Navigate to Profile
              });
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.deepPurple[100],
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.deepPurple[900],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.deepPurple[900]!, width: 2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'L',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    final isSelected = _selectedIndex == item['index'];
    final isLogout = item['index'] == 7;

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
          color: isSelected ? Colors.white : Colors.white70,
        ),
        title: _isDrawerOpen
            ? Text(
                item['title'],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              )
            : null,
        onTap: () {
          if (isLogout) {
            _logout();
          } else {
            setState(() {
              _selectedIndex = item['index'];
              _isDrawerOpen = true;
            });
          }
        },
        selected: isSelected,
        selectedTileColor: Colors.deepPurple[700],
        tileColor: isLogout ? Colors.red.withOpacity(0.2) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isDrawerOpen ? 20 : 12,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.deepPurple[800],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Earnings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${_earnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[900],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _buildStatItem('Clients', _totalClients.toString(), Icons.group,
                  Colors.blue),
              _buildStatItem('Active', _acceptedRequests.toString(), Icons.chat,
                  Colors.green),
              _buildStatItem('Pending', _pendingRequests.toString(),
                  Icons.notifications, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.deepPurple[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    if (_pendingRequests == 0) {
      return IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
      );
    }

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              _pendingRequests > 9 ? '9+' : _pendingRequests.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildEnhancedProfileInfo();
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

  // ================= ENHANCED PROFILE INFO =================
  Widget _buildEnhancedProfileInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade700,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  // Profile Image
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.deepPurple[100],
                          child: _lawyerData?['profileImage'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(45),
                                  child: Image.network(
                                    _lawyerData!['profileImage'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.deepPurple[900],
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.deepPurple[900],
                                ),
                        ),
                      ),
                      // Online Status
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.circle,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Profile Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lawyerData?['name'] ?? 'Lawyer',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // Specialization Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _lawyerData?['specialization'] ??
                                'General Practice',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Rating and Reviews
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 5),
                            Text(
                              _rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '($_totalReviews reviews)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Profile Completion
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Profile Completion',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${(_profileCompletion * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: _profileCompletion,
                              backgroundColor: Colors.deepPurple[700],
                              color: _profileCompletion >= 0.8
                                  ? Colors.green
                                  : _profileCompletion >= 0.5
                                      ? Colors.orange
                                      : Colors.red,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Stats Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.5,
            children: [
              _buildProfileStatCard(
                'Total Clients',
                _totalClients.toString(),
                Icons.group,
                Colors.blue,
              ),
              _buildProfileStatCard(
                'Active Sessions',
                _acceptedRequests.toString(),
                Icons.chat,
                Colors.green,
              ),
              _buildProfileStatCard(
                'Pending Requests',
                _pendingRequests.toString(),
                Icons.notifications,
                Colors.orange,
              ),
              _buildProfileStatCard(
                'Total Earnings',
                'Rs. ${_earnings.toStringAsFixed(0)}',
                Icons.attach_money,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: const Color.fromARGB(255, 227, 195, 195),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showEnhancedEditProfileDialog,
            ),
          ),

          const SizedBox(height: 20),

          // Personal Information Card
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
                      Icon(Icons.person_outline, color: Colors.deepPurple),
                      SizedBox(width: 10),
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Information Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 3,
                    children: [
                      _buildProfileField(
                          'Full Name', _lawyerData?['name'] ?? 'N/A'),
                      _buildProfileField(
                          'Email', _lawyerData?['email'] ?? 'N/A'),
                      _buildProfileField(
                          'Phone', _lawyerData?['phone'] ?? 'N/A'),
                      _buildProfileField('City', _lawyerData?['city'] ?? 'N/A'),
                      _buildProfileField('Experience',
                          _lawyerData?['experience'] ?? 'Not specified'),
                      _buildProfileField(
                          'Bar License', _lawyerData?['barLicense'] ?? 'N/A'),
                      _buildProfileField('Consultation Fee',
                          'Rs. ${_lawyerData?['consultationFee'] ?? '2000'}'),
                      _buildProfileField('Specialization',
                          _lawyerData?['specialization'] ?? 'General Practice'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Professional Bio Card
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
                      Icon(Icons.description, color: Colors.deepPurple),
                      SizedBox(width: 10),
                      Text(
                        'Professional Bio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _lawyerData?['bio'] ??
                          'No bio provided. Add a professional bio to attract more clients.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard(
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
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Column(
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (label == 'Email' || label == 'Phone')
                IconButton(
                  icon: Icon(
                    label == 'Email' ? Icons.email : Icons.phone,
                    color: Colors.deepPurple,
                    size: 18,
                  ),
                  onPressed: () {
                    // Add email/phone action
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEnhancedEditProfileDialog() {
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(25),
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit, color: Colors.deepPurple, size: 30),
                    SizedBox(width: 10),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Form Fields
                Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: specializationController,
                        decoration: const InputDecoration(
                          labelText: 'Specialization',
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: experienceController,
                        decoration: const InputDecoration(
                          labelText: 'Experience (e.g., 5 years)',
                          prefixIcon: Icon(Icons.timeline),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: licenseController,
                        decoration: const InputDecoration(
                          labelText: 'Bar License Number',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: feeController,
                        decoration: const InputDecoration(
                          labelText: 'Consultation Fee (Rs.)',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Bio Field
                TextField(
                  controller: bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Professional Bio',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
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
                            'specialization':
                                specializationController.text.trim(),
                            'experience': experienceController.text.trim(),
                            'barLicense': licenseController.text.trim(),
                            'consultationFee':
                                int.tryParse(feeController.text) ?? 2000,
                            'bio': bioController.text.trim(),
                          });

                          await _getLawyerProfile();
                          _calculateProfileCompletion();

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Profile updated successfully'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade700,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.gavel,
                        size: 40,
                        color: Colors.white,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lawyerData?['specialization'] ??
                                'General Practice',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Last Login: Today, ${DateFormat('hh:mm a').format(DateTime.now())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.2,
              children: [
                _buildDashboardStatCard(
                  'Pending',
                  _pendingRequests.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
                _buildDashboardStatCard(
                  'Active Chats',
                  _acceptedRequests.toString(),
                  Icons.chat,
                  Colors.green,
                ),
                _buildDashboardStatCard(
                  'Scheduled',
                  _scheduledSessions.toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildDashboardStatCard(
                  'Earnings',
                  'Rs. ${_earnings.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Quick Actions Title
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 15),

            // Quick Actions Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.8,
              children: [
                _buildDashboardActionCard(
                  'View Requests',
                  Icons.notifications,
                  Colors.deepPurple,
                  () => setState(() => _selectedIndex = 2),
                ),
                _buildDashboardActionCard(
                  'Check Schedule',
                  Icons.calendar_today,
                  Colors.blue,
                  () => setState(() => _selectedIndex = 3),
                ),
                _buildDashboardActionCard(
                  'Start Chat',
                  Icons.chat,
                  Colors.green,
                  () => setState(() => _selectedIndex = 4),
                ),
                _buildDashboardActionCard(
                  'Update Profile',
                  Icons.edit,
                  Colors.orange,
                  () => setState(() => _selectedIndex = 1),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Recent Requests Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, color: Colors.deepPurple, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Recent Requests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildRecentRequests(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Upcoming Sessions
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.upcoming,
                            color: Colors.deepPurple, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Upcoming Sessions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildUpcomingSessions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
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
        .take(3)
        .toList();

    if (recentRequests.isEmpty) {
      return const Column(
        children: [
          Icon(Icons.notifications_off, size: 60, color: Colors.grey),
          SizedBox(height: 15),
          Text(
            "No recent requests",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      );
    }

    return Column(
      children: recentRequests.map((request) {
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: const Icon(Icons.person, color: Colors.deepPurple),
            ),
            title: Text(
              request['clientName'] ?? 'Client',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                'Status: ${request['status']?.toUpperCase() ?? 'PENDING'}'),
            trailing: Chip(
              label: Text(
                request['status'] == 'pending' ? 'New' : 'Active',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor:
                  request['status'] == 'pending' ? Colors.orange : Colors.green,
            ),
            onTap: () => setState(() => _selectedIndex = 2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUpcomingSessions() {
    final upcomingSessions = _allRequests
        .where((req) => req['status'] == 'scheduled')
        .take(3)
        .toList();

    if (upcomingSessions.isEmpty) {
      return const Column(
        children: [
          Icon(Icons.calendar_today, size: 60, color: Colors.grey),
          SizedBox(height: 15),
          Text(
            "No upcoming sessions",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      );
    }

    return Column(
      children: upcomingSessions.map((session) {
        final scheduledDate = session['scheduledDate'] as Timestamp?;
        final scheduledTime = session['scheduledTime'];
        final clientName = session['clientName'] ?? 'Client';

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.calendar_today, color: Colors.blue),
            ),
            title: Text(
              clientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: scheduledDate != null
                ? Text('${_formatDate(scheduledDate)} ${scheduledTime ?? ''}')
                : const Text('Date not set'),
            trailing: IconButton(
              icon: const Icon(Icons.chat, color: Colors.green),
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
            onTap: () => setState(() => _selectedIndex = 3),
          ),
        );
      }).toList(),
    );
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

  Widget _buildErrorScreen() {
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
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("Go to Login"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _updateOnlineStatus(false);
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('hh:mm a').format(date);
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
}
