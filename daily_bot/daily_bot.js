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
      model: "gemini-2.5-flash",

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
      sender: "AI Companion",
      isUser: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    await trackerRef.set({ lastSentDate: todayStr });
    console.log("✅ Success! Message sent.");

  } catch (error) {
    console.error("❌ Error running bot:", error);
    process.exit(1);
  }
}

runBot();