import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService(); // Use our new service
  bool _isLoading = true;

  // Define Users for UI
  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'Me');
  final ChatUser _aiUser = ChatUser(
    id: '2',
    firstName: 'Daily Bot',
    profileImage: "https://cdn-icons-png.flaticon.com/512/4712/4712027.png",
  );

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  Future<void> _setupChat() async {
    await _chatService.initialize();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Daily Companion")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _chatService.getMessagesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Convert Firestore docs to DashChat Messages
          List<ChatMessage> messages = snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return ChatMessage(
              user: (data['isUser'] ?? false) ? _currentUser : _aiUser,
              text: data['text'] ?? '',
              createdAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();

          return DashChat(
            currentUser: _currentUser,
            messages: messages,
            onSend: (ChatMessage m) {
              _chatService.sendMessage(m.text); // Just call the service!
            },
            inputOptions: InputOptions(
              inputDecoration: InputDecoration(
                hintText: "Reply to your AI friend...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          );
        },
      ),
    );
  }
}