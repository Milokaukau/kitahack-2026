import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_bubble.dart'; // We use your bubble component here

class ChatDesign extends StatelessWidget {
  // These are the "tools" we receive from the Logic file
  final String userId;
  final Stream<QuerySnapshot> messageStream;
  final TextEditingController controller;
  final VoidCallback onSendPressed;

  const ChatDesign({
    super.key,
    required this.userId,
    required this.messageStream,
    required this.controller,
    required this.onSendPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF2FA), // Soft Blue Background

      // --- 1. PRETTY HEADER ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=33"), // Bot Avatar
              radius: 18,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Proactive Friend", style: TextStyle(color: Colors.black87, fontSize: 16)),
                Text("Chat ID: $userId", style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
      ),

      // --- 2. MESSAGE LIST ---
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messageStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.toList();

                // Sort messages by time (Newest first)
                docs.sort((a, b) {
                  final t1 = a['timestamp'] as Timestamp?;
                  final t2 = b['timestamp'] as Timestamp?;
                  if (t1 == null || t2 == null) return 0;
                  return t2.compareTo(t1);
                });

                return ListView.builder(
                  reverse: true, // Auto-scroll to bottom
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    return ChatBubble(
                      message: data['text'] ?? '',
                      isUser: data['isUser'] ?? true,
                    );
                  },
                );
              },
            ),
          ),

          // --- 3. FLOATING INPUT AREA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => onSendPressed(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send Button
                GestureDetector(
                  onTap: onSendPressed,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent, blurRadius: 10, offset: Offset(0, 4))
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
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