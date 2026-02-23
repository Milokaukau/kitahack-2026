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
    // --- MEMORY CHECK (Same as before) ---
    const todayStr = new Date().toISOString().split('T')[0];
    const trackerRef = db.collection('bot_memory').doc('daily_tracker');
    const trackerDoc = await trackerRef.get();

    if (trackerDoc.exists && trackerDoc.data().lastSentDate === todayStr) {
      console.log(`💤 Already sent a message today (${todayStr}). Going back to sleep.`);
      return;
    }

    // --- DICE ROLL (Same as before) ---
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
      model: "gemini-2.5-flash-lite",

      // 1. Pass your specific prompt here
      contents: dailyPrompt(),

      // 2. ENABLE GOOGLE SEARCH (Critical for Step 3 of your prompt)
      tools: [
        { googleSearch: {} }
      ],

      // 3. Configuration
      config: {
        responseMimeType: 'text/plain',
        // Optional: Temperature controls creativity (0.0 - 2.0)
        temperature: 1.0,
      }
    });

    // --- STEP 4: HANDLE RESPONSE ---
    // The response might contain "groundingMetadata" (citations),
    // but your prompt asks the AI to remove them. We trust the AI,
    // but we can also trim just in case.
    const messageText = response.text ? response.text.trim() : "";

    if (!messageText) {
      console.error("❌ Error: Received empty response from Gemini.");
      return;
    }

    console.log(`📝 Gemini generated: "${messageText}"`);

    // --- STEP 5: SAVE TO DB ---
        await db.collection('chats').doc('test_user').collection('messages').add({
          text: messageText,
          sender: "Kawan Ai", // <-- Updated to match your new persona!
          isUser: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log("✅ Success! Message saved to database.");

        // --- STEP 6: SEND PUSH NOTIFICATION (The Missing Code!) ---
        // Fetch the token from the users collection
        const userDoc = await db.collection('users').doc('test_user').get();

        if (userDoc.exists && userDoc.data().fcmToken) {
          const fcmToken = userDoc.data().fcmToken;

          const payload = {
            notification: {
              title: "Kawan Ai",
              body: "You have 1 new message! 🤖",
            },
            android: {
              priority: "high", // Forces the heads-up pop-up
              notification: {
                icon: "bot_icon", // Your transparent stencil!
                color: "#9D7CFF", // Your custom purple circle
                defaultSound: true
              }
            },
            token: fcmToken
          };

          // Send it to the phone!
          await admin.messaging().send(payload);
          console.log("🔔 Push notification sent to test_user!");
        } else {
          console.log("⚠️ No FCM token found. Message saved, but no notification sent.");
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
