import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_design.dart'; // <--- Connect to the Design file

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --- 1. SETUP ---
  final String userId = "demo_user_1"; // Change this if you want
  final TextEditingController _controller = TextEditingController();
  final CollectionReference _messagesRef = FirebaseFirestore.instance.collection('messages');

  // --- 2. LOGIC: Smart Reply ---
  String getSmartReply(String input) {
    String lowerInput = input.toLowerCase();
    if (lowerInput.contains("hi") || lowerInput.contains("hello")) {
      return "Hi there! How is the hackathon going? 😊";
    } else if (lowerInput.contains("help")) {
      return "I can help! What do you need to know?";
    } else if (lowerInput.contains("bye")) {
      return "Good luck! See you later! 🚀";
    } else {
      return "That's interesting! Tell me more.";
    }
  }

  // --- 3. LOGIC: Send Message ---
  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    String userText = _controller.text;

    // Save User Message
    _messagesRef.add({
      "text": userText,
      "isUser": true,
      "timestamp": FieldValue.serverTimestamp(),
      "userId": userId,
    });

    _controller.clear();

    // Generate Smart Reply (Bot)
    String botReply = getSmartReply(userText);

    // Save Bot Message (Delay 1 sec)
    Future.delayed(const Duration(seconds: 1), () {
      _messagesRef.add({
        "text": botReply,
        "isUser": false,
        "timestamp": FieldValue.serverTimestamp(),
        "userId": userId,
      });
    });
  }

  // --- 4. BUILD (Combine Logic + Design) ---
  @override
  Widget build(BuildContext context) {
    return ChatDesign(
      userId: userId,
      // We pass the Stream so the Design knows what to display
      messageStream: _messagesRef.where('userId', isEqualTo: userId).snapshots(),
      controller: _controller,
      onSendPressed: _sendMessage,
    );
  }
}