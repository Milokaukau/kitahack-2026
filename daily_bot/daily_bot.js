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
    // --- STEP 1: THE MEMORY CHECK ---
    // We check a specific document to see if we already finished the job for today.
    const todayStr = new Date().toISOString().split('T')[0]; // Returns "2026-02-05"
    const trackerRef = db.collection('bot_memory').doc('daily_tracker');
    const trackerDoc = await trackerRef.get();

    if (trackerDoc.exists && trackerDoc.data().lastSentDate === todayStr) {
      console.log(`💤 Already sent a message today (${todayStr}). Going back to sleep.`);
      return; // STOP HERE. Exit the function.
    }

    // --- STEP 2: THE DICE ROLL ---
    // Get current hour in UTC.
    // Malaysia 9 PM = 13:00 UTC. This is our deadline.
    const currentHourUTC = new Date().getUTCHours();
    const isLastChance = (currentHourUTC >= 13);

    // 30% chance to send now.
    const shouldSend = Math.random() < 0.30;

    console.log(`Hour (UTC): ${currentHourUTC} | Last Chance: ${isLastChance} | Dice Win: ${shouldSend}`);

    // If the dice lost AND it is not the last chance -> Sleep
    if (!shouldSend && !isLastChance) {
      console.log("Not sending. Trying again next hour.");
      return; // STOP HERE.
    }

    console.log("Sending message now...");

    // --- STEP 3: THE ACTION (Send "Hi") ---
    // Writing to the same test user as before
    await db.collection('chats').doc('test_user').collection('messages').add({
      text: "Hi! This is a RANDOMIZED message from the bot.",
      sender: "Bot",
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    // --- STEP 4: UPDATE MEMORY ---
    // Mark today as done so we don't send again until tomorrow
    await trackerRef.set({ lastSentDate: todayStr });
    console.log("✅ Success! Message sent and memory updated.");

  } catch (error) {
    console.error("❌ Error running bot:", error);
    process.exit(1);
  }
}

runBot();