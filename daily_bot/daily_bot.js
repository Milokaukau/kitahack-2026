const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require("@google/generative-ai");

// 1. Setup Keys (We will inject these from GitHub Secrets later)
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const fcm = admin.messaging();

async function runBot() {
  // 2. The Logic: Pick a random persona/topic
  const topics = ["local food", "traffic jam", "coding struggle", "weird weather"];
  const randomTopic = topics[Math.floor(Math.random() * topics.length)];

  // 3. The AI: Generate the message
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
  const prompt = `You are Alex, a 21yo friend. Send me a short text (1 sentence) about ${randomTopic} in Singapore. Be casual.`;

  const result = await model.generateContent(prompt);
  const messageText = result.response.text();

  console.log("AI Generated:", messageText);

  // 4. The Database: Save the message so it appears in the chat history
  // Replace 'user_123' with a loop if you have multiple users
  await db.collection('chats').doc('user_123').collection('messages').add({
    text: messageText,
    sender: 'Alex (AI)',
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  });

  // 5. The Notification: Wake up the phone!
  // You need the user's "FCM Token" stored in your DB to do this
  const userDoc = await db.collection('users').doc('user_123').get();
  const userToken = userDoc.data().fcmToken;

  if (userToken) {
    await fcm.send({
      token: userToken,
      notification: {
        title: "New Message from Alex",
        body: messageText,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    });
    console.log("Notification sent!");
  }
}

runBot();