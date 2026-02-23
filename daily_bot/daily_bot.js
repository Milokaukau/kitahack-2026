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

    // --- STEP 4: FETCH USERS FROM FIRESTORE ---
        console.log("🔍 Fetching users from database...");

        // Fetch from the 'users' collection instead of Auth so we get the FCM tokens instantly!
        const usersSnapshot = await db.collection('users').get();

        if (usersSnapshot.empty) {
          console.log("⚠️ No users found in database. Exiting without sending.");
          return;
        }

        console.log(`👥 Found ${usersSnapshot.size} users. Broadcasting messages & notifications...`);

        // --- STEP 5: SAVE TO DB AND SEND PUSH NOTIFICATIONS ---
        const sendPromises = usersSnapshot.docs.map(async (userDoc) => {
          const userId = userDoc.id;
          const fcmToken = userDoc.data().fcmToken;

          // 1. Add the chat message to the user's Firestore history
          const dbPromise = db.collection('chats').doc(userId).collection('messages').add({
            text: messageText,
            sender: "AI Companion",
            isUser: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });

          // 2. Send the Push Notification via Firebase Cloud Messaging
          let pushPromise = Promise.resolve(); // Fallback in case a user hasn't generated a token yet

          if (fcmToken) {
            const payload = {
              notification: {
                title: "AI Companion",
                body: "You have 1 new message!"
              },
              token: fcmToken
            };

            pushPromise = admin.messaging().send(payload)
              .then(() => console.log(`🔔 Notification sent to ${userId}`))
              .catch((err) => console.log(`⚠️ Failed to push to ${userId} (Token might be old):`, err.message));
          }

          // Execute both the database write and the push notification concurrently!
          return Promise.all([dbPromise, pushPromise]);
        });

        // Wait for all messages and notifications to finish processing
        await Promise.all(sendPromises);

  } catch (error) {
    console.error("❌ Error running bot:", error);
    process.exit(1);
  }
}

runBot();