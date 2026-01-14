import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Lawyer Chat Screen
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

  String get chatId => "${widget.clientId}_${widget.lawyerId}";

  @override
  void initState() {
    super.initState();
    _setLawyerOnline(true);
  }

  void _setLawyerOnline(bool online) async {
    await FirebaseFirestore.instance
        .collection('lawyers')
        .doc(widget.lawyerId)
        .update({'isOnline': online});
  }

  void _updateTyping(bool typing) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .set({'lawyerTyping': typing}, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': widget.lawyerId,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });

    _messageController.clear();
    _updateTyping(false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _setLawyerOnline(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.clientName),
            const SizedBox(width: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clients')
                  .doc(widget.clientId)
                  .snapshots(),
              builder: (context, snapshot) {
                final isOnline = snapshot.hasData && snapshot.data!.exists
                    ? (snapshot.data!.data() as Map<String, dynamic>)['isOnline'] ?? false
                    : false;
                return CircleAvatar(
                  radius: 5,
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container();

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == widget.lawyerId;
                    final seen = msg['seen'] ?? false;

                    // Mark message as seen if it belongs to client
                    if (!isMe && !seen) {
                      FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .collection('messages')
                          .doc(messages[index].id)
                          .update({'seen': true});
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
            builder: (context, snapshot) {
              bool typing = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                typing = data['clientTyping'] ?? false;
              }
              return Column(
                children: [
                  if (typing)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Client is typing...",
                          style: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic),
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
      color: Colors.white,
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
