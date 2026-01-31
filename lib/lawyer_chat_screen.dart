import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LawyerChatScreen extends StatefulWidget {
  final String lawyerId;
  final String clientId;
  final String clientName;

  const LawyerChatScreen({
    super.key,
    required this.lawyerId,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<LawyerChatScreen> createState() => _LawyerChatScreenState();
}

class _LawyerChatScreenState extends State<LawyerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _messages = [];
  bool _isClientOnline = false;
  bool _isClientTyping = false;
  late String _chatId;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _chatSubscription;
  StreamSubscription<DocumentSnapshot>? _clientSubscription;

  @override
  void initState() {
    super.initState();
    _chatId = "${widget.clientId}_${widget.lawyerId}";
    _setupOnlineStatus();
    _setupChatListeners();
    _setupClientListener();
    _setLawyerOnline(true);
    _markAllMessagesAsSeen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _setLawyerOnline(bool online) async {
    try {
      await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(widget.lawyerId)
          .update({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error setting lawyer online: $e");
    }
  }

  void _setupOnlineStatus() async {
    try {
      await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(widget.lawyerId)
          .update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error setting lawyer online: $e");
    }
  }

  void _setupChatListeners() {
    // Listen to messages
    _messagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _messages = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        _markClientMessagesAsSeen();
      }
    });

    // Listen to chat typing status
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _isClientTyping = data['clientTyping'] ?? false;
        });
      }
    });
  }

  void _setupClientListener() {
    _clientSubscription = FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _isClientOnline = data['isOnline'] ?? false;
        });
      }
    });
  }

  void _markAllMessagesAsSeen() async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.clientId)
          .where('seen', isEqualTo: false)
          .get();

      for (var doc in messagesSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .doc(doc.id)
            .update({'seen': true});
      }
    } catch (e) {
      print("Error marking messages as seen: $e");
    }
  }

  void _markClientMessagesAsSeen() async {
    try {
      for (var message in _messages) {
        if (message['senderId'] == widget.clientId &&
            !(message['seen'] ?? false)) {
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatId)
              .collection('messages')
              .doc(message['id'])
              .update({'seen': true});
        }
      }
    } catch (e) {
      print("Error marking client messages: $e");
    }
  }

  void _updateTyping(bool typing) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .set({'lawyerTyping': typing}, SetOptions(merge: true));
    } catch (e) {
      print("Error updating typing status: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Update chat metadata
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'lawyerId': widget.lawyerId,
        'clientId': widget.clientId,
        'lawyerName': 'Lawyer', // Update with actual name
        'clientName': widget.clientName,
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Send message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'senderId': widget.lawyerId,
        'senderName': 'Lawyer', // Update with actual name
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
        'type': 'text',
      });

      _messageController.clear();
      _updateTyping(false);
      _focusNode.unfocus();
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send message"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _clientSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();

    _setLawyerOnline(false);

    FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .set({'lawyerTyping': false}, SetOptions(merge: true));

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                widget.clientName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clientName,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  _isClientOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isClientOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hello to ${widget.clientName}!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['senderId'] == widget.lawyerId;
                      final seen = message['seen'] ?? false;
                      final timestamp = message['timestamp'] as Timestamp?;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.teal.shade100,
                                  child: Text(
                                    widget.clientName
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isMe ? Colors.teal : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['message'] ?? '',
                                      style: TextStyle(
                                        color:
                                            isMe ? Colors.white : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white.withOpacity(0.8)
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            seen ? Icons.done_all : Icons.done,
                                            size: 12,
                                            color: seen
                                                ? Colors.blue.shade200
                                                : Colors.white.withOpacity(0.8),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Typing indicator
          if (_isClientTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Client is typing...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            onChanged: (value) {
                              _updateTyping(value.isNotEmpty);
                            },
                            decoration: const InputDecoration(
                              hintText: "Type a message...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _messageController.text.trim().isNotEmpty
                      ? Colors.teal
                      : Colors.grey,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _messageController.text.trim().isNotEmpty
                        ? _sendMessage
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
