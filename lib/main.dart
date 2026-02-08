import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_options.dart'; // Make sure you ran 'flutterfire configure'!
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load the secret file
  // Note: We use a try-catch in case you forgot the file!
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily AI Bot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 2. Setup Gemini Model
  // REPLACE WITH YOUR ACTUAL KEY
  final ChatSession _chatSession = GenerativeModel(
    model: 'gemini-2.5-flash',
    // accessing the key securely
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? "",
  ).startChat();

  // Define Users for the UI
  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'Me');
  final ChatUser _aiUser = ChatUser(
      id: '2',
      firstName: 'Daily Bot',
      profileImage: "https://cdn-icons-png.flaticon.com/512/4712/4712027.png" // AI Icon
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Daily Companion")),
      // 3. LISTEN TO FIRESTORE
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc('test_user') // Must match your JS Bot's user ID
            .collection('messages')
            .orderBy('timestamp', descending: true) // Newest at bottom
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Convert Firestore data to DashChat messages
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
              _handleSendMessage(m);
            },
            inputOptions: InputOptions(
              inputDecoration: InputDecoration(
                hintText: "Reply to your AI friend...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. HANDLE SENDING
  Future<void> _handleSendMessage(ChatMessage chatMessage) async {
    // A. Save User Message to Firestore
    await FirebaseFirestore.instance
        .collection('chats')
        .doc('test_user')
        .collection('messages')
        .add({
      'text': chatMessage.text,
      'isUser': true,
      'timestamp': FieldValue.serverTimestamp(),
      'sender': "User",
    });

    try {
      // B. Send to Gemini (With History!)
      // Note: _chatSession keeps history in memory as long as app is open.
      // For a hackathon, this is fine. For production, you'd rebuild history from DB.
      final response = await _chatSession.sendMessage(
        Content.text(chatMessage.text),
      );

      final aiReply = response.text ?? "I'm speechless!";

      // C. Save AI Reply to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc('test_user')
          .collection('messages')
          .add({
        'text': aiReply,
        'isUser': false, // It's the AI
        'timestamp': FieldValue.serverTimestamp(),
        'sender': "AI Companion",
      });

    } catch (e) {
      print("Error talking to Gemini: $e");
    }
  }
}