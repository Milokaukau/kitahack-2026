const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require("@google/generative-ai");

// 1. Setup Keys
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function runBot() {
  console.log("🤖 Bot Waking Up...");

  try {
    // --- STEP 1: MEMORY CHECK ---
    const todayStr = new Date().toISOString().split('T')[0];
    const trackerRef = db.collection('bot_memory').doc('daily_tracker');
    const trackerDoc = await trackerRef.get();

    if (trackerDoc.exists && trackerDoc.data().lastSentDate === todayStr) {
      console.log(`💤 Already sent a message today (${todayStr}). Going back to sleep.`);
      return;
    }

    // --- STEP 2: THE DICE ROLL ---
    // Get current hour in UTC.
    // Malaysia 9 PM = 13:00 UTC. This is our deadline.
    const currentHourUTC = new Date().getUTCHours();
    const isLastChance = (currentHourUTC >= 13);

    // 100% chance to send now to test if the AI integration works.
    const shouldSend = Math.random() < 1.0;

    console.log(`Hour (UTC): ${currentHourUTC} | Last Chance: ${isLastChance} | Should Send: ${shouldSend}`);

    // If the dice lost AND it is not the last chance -> Sleep
    if (!shouldSend && !isLastChance) {
      console.log("Not sending. Trying again next hour.");
      return; // STOP HERE.
    }

    console.log("Sending message now...");

    // --- STEP 3: GENERATE SIMPLE CONTENT ---
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // SUPER SIMPLE PROMPT
    const prompt = "Write a short, friendly 'Hello' message to a friend. No hashtags.";

    const result = await model.generateContent(prompt);
    const messageText = result.response.text().trim();

    console.log(`📝 Gemini generated: "${messageText}"`);

    // --- STEP 4: SAVE TO DB ---
    await db.collection('chats').doc('test_user').collection('messages').add({
      text: messageText,
      sender: "AI Companion",
      isUser: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    // --- STEP 5: UPDATE MEMORY ---
    await trackerRef.set({ lastSentDate: todayStr });
    console.log("✅ Success! Message sent.");

  } catch (error) {
    console.error("❌ Error running bot:", error);
    process.exit(1);
  }
}

runBot();