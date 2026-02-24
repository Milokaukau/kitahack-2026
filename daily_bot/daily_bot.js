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
    // --- STEP 1: MEMORY CHECK ---
    const todayStr = new Date().toISOString().split('T')[0];
    const trackerRef = db.collection('bot_memory').doc('daily_tracker');
    const trackerDoc = await trackerRef.get();

    if (trackerDoc.exists && trackerDoc.data().lastSentDate === todayStr) {
      console.log(`💤 Already sent a message today (${todayStr}). Going back to sleep.`);
      return;
    }

    // --- STEP 2: DICE ROLL ---
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
      contents: dailyPrompt(),
      tools: [{ googleSearch: {} }],
      config: { responseMimeType: 'text/plain', temperature: 1.0 }
    });

    const messageText = response.text ? response.text.trim() : "";

    if (!messageText) {
      console.error("❌ Error: Received empty response from Gemini.");
      return;
    }

    console.log(`📝 Gemini generated: "${messageText}"`);

    // --- STEP 4: FETCH ALL USERS ---
    console.log("Fetching all users from database...");
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log("⚠️ No users found in the database. Exiting.");
      return;
    }

    const dbWrites = [];
    const fcmTokens = [];

    // --- STEP 5: SAVE MESSAGE TO EVERY USER'S CHAT ---
    usersSnapshot.forEach((userDoc) => {
      const userId = userDoc.id; 
      const userData = userDoc.data();

      // Save to this specific user's chat subcollection
      const writePromise = db.collection('chats').doc(userId).collection('messages').add({
        text: messageText,
        sender: "Kawan Ai", 
        isUser: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      dbWrites.push(writePromise);

      // Collect their phone token for the notification blast
      if (userData.fcmToken) {
        fcmTokens.push(userData.fcmToken);
      }
    });

    // Execute all database writes at once
    await Promise.all(dbWrites);
    console.log(`✅ Success! Message saved to ${dbWrites.length} user(s).`);

    // --- STEP 6: SEND MASS PUSH NOTIFICATION ---
    if (fcmTokens.length > 0) {
      console.log(`Sending notifications to ${fcmTokens.length} device(s)...`);
      
      const payload = {
        notification: {
          title: "Kawan Ai",
          body: "You have 1 new message! 🤖",
        },
        android: {
          priority: "high",
          notification: {
            icon: "bot_icon", 
            color: "#9D7CFF",
            defaultSound: true
          }
        },
        tokens: fcmTokens // Notice the plural 'tokens' here!
      };

      const pushResponse = await admin.messaging().sendEachForMulticast(payload);
      console.log(`🔔 Push notifications finished! (${pushResponse.successCount} succeeded, ${pushResponse.failureCount} failed)`);
    } else {
      console.log("⚠️ No FCM tokens found. Messages saved, but no notifications sent.");
    }

    // --- STEP 7: UPDATE MEMORY TRACKER ---
    await trackerRef.set({ lastSentDate: todayStr });
    console.log("✅ Bot sequence complete.");

  } catch (error) {
    console.error("❌ Error running bot:", error);
    process.exit(1);
  }
}

runBot();
