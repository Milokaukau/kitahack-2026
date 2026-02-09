import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load the secret file securely
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }

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
  // VARIABLES
  late ChatSession _chatSession;
  bool _isLoadingHistory = true; // Shows spinner while loading history

  // SETUP GEMINI (SECURELY)
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? "",
  );

  // USER PROFILES
  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'Me');
  final ChatUser _aiUser = ChatUser(
      id: '2',
      firstName: 'Daily Bot',
      profileImage: "https://cdn-icons-png.flaticon.com/512/4712/4712027.png"
  );

  @override
  void initState() {
    super.initState();
    // Start to load past context immediately when app opens
    _loadMemoryFromDB();
  }

  // --- LOADING PREVIOUS CONTEXT INTO THIS CHAT SESSION ---
  Future<void> _loadMemoryFromDB() async {
    print("🧠 Loading AI Memory...");

    try {
      // 1. Fetch last 10 messages from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc('test_user')
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10) // Limit to save tokens
          .get();

      // 2. Convert Firestore data to Gemini 'Content' objects
      List<Content> history = [];

      if (snapshot.docs.isNotEmpty) {
        history = snapshot.docs.map((doc) {
          final data = doc.data();
          final text = data['text'] ?? '';
          final isUser = data['isUser'] ?? false;

          if (isUser) {
            return Content.text(text);
          } else {
            return Content.model([TextPart(text)]);
          }
        }).toList().reversed.toList(); // REVERSE: Gemini needs Oldest -> Newest
      }

      // 3. Start the chat with this history!
      _chatSession = _model.startChat(history: history);
      print("✅ AI Memory Loaded with ${history.length} messages.");

    } catch (e) {
      print("❌ Error loading memory: $e");
      // Fallback: Start empty chat if DB fails
      _chatSession = _model.startChat();
    } finally {
      setState(() {
        _isLoadingHistory = false; // Stop spinner
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Daily Companion")),

      // IF LOADING: Show Spinner
      // IF READY: Show Chat
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc('test_user')
            .collection('messages')
            .orderBy('timestamp', descending: true)
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

  // SEND MESSAGE LOGIC
  Future<void> _handleSendMessage(ChatMessage chatMessage) async {
    // 1. Save User Message to Firestore
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
      // 2. Send to Gemini (Now knows history!)
      final response = await _chatSession.sendMessage(
        Content.text(chatMessage.text),
      );

      final aiReply = response.text ?? "I'm speechless!";

      // 3. Save AI Reply to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc('test_user')
          .collection('messages')
          .add({
        'text': aiReply,
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': "AI Companion",
      });

    } catch (e) {
      print("Error talking to Gemini: $e");
    }
  }
}