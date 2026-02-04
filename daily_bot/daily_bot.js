const admin = require('firebase-admin');

// 1. Setup Keys (Reads from GitHub Secret)
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function runBot() {
  console.log("🤖 Starting Simple Bot...");

  try {
    // 2. The Task: Just write "Hi" to a test user
    // We use 'test_user' so we don't mess up your real chat history
    const docRef = await db.collection('chats').doc('test_user').collection('messages').add({
      text: "Hi! This is a test from GitHub Actions.",
      sender: "Bot",
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log("✅ Success! Document written with ID: " + docRef.id);

  } catch (error) {
    console.error("❌ Error writing to DB:", error);
    process.exit(1); // This makes the GitHub Action turn Red so you know it failed
  }
}

runBot();