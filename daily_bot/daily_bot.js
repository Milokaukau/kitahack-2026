const admin = require('firebase-admin');
const { GoogleGenAI } = require("@google/genai");

// 1. IMPORT PROMPT FILE
const { dailyPrompt } = require('./daily_prompt');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

// 2. Initialize the client
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function runBot() {
  console.log("🤖 Bot Waking Up...");

  try {
    // --- MEMORY CHECK ---
    const todayStr = new Date().toISOString().split('T')[0];
    const trackerRef = db.collection('bot_memory').doc('daily_tracker');
    const trackerDoc = await trackerRef.get();

    if (trackerDoc.exists && trackerDoc.data().lastSentDate === todayStr) {
      console.log(`💤 Already sent a message today (${todayStr}). Going back to sleep.`);
      return;
    }

    // --- DICE ROLL ---
    const currentHourUTC = new Date().getUTCHours();
    const isLastChance = (currentHourUTC >= 13);
    const shouldSend = Math.random() < 1.0;

    console.log(`Hour: ${currentHourUTC} | Last Chance: ${isLastChance} | Should Send: ${shouldSend}`);

    if (!shouldSend && !isLastChance) {
      console.log("Not sending. Trying again next hour.");
      return;
    }

    console.log("Sending message now...");

    // --- STEP 3: GENERATE CONTENT WITH SEARCH ---
    const response = await ai.models.generateContent({
      model: "gemini-2.5-flash",
      contents: dailyPrompt,
      tools: [
        { googleSearch: {} }
      ],
      config: {
        responseMimeType: 'text/plain',
        temperature: 1.0,
      }
    });

    const messageText = response.text ? response.text.trim() : "";

    if (!messageText) {
      console.error("❌ Error: Received empty response from Gemini.");
      return;
    }

    console.log(`📝 Gemini generated: "${messageText}"`);

    // --- STEP 4: FETCH ALL USERS FROM FIREBASE AUTH ---
    console.log("🔍 Fetching all registered users...");
    let allUserIds = [];
    let nextPageToken;

    // We use a loop to handle pagination in case you get thousands of users!
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      listUsersResult.users.forEach((userRecord) => {
        allUserIds.push(userRecord.uid);
      });
      nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);

    if (allUserIds.length === 0) {
      console.log("⚠️ No users found. Exiting without sending.");
      return;
    }

    console.log(`👥 Found ${allUserIds.length} users. Broadcasting message...`);

    // --- STEP 5: SAVE TO DB FOR EVERY USER ---
    // Create an array of database-write promises
    const sendPromises = allUserIds.map(uid => {
      return db.collection('chats').doc(uid).collection('messages').add({
        text: messageText,
        sender: "AI Companion",
        isUser: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // Execute all database writes concurrently
    await Promise.all(sendPromises);

    // Update the tracker so it doesn't run again today
    await trackerRef.set({ lastSentDate: todayStr });
    console.log("✅ Success! Message sent to all users.");

  } catch (error) {
    console.error("❌ Error running bot:", error);
    process.exit(1);
  }
}

runBot();