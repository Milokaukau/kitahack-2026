# 💕 Kawan AI
An AI-powered companion designed to break the "Cycle of Isolation." By acting as a proactive friend, this app helps individuals with social anxiety regain confidence through judgment-free, real-world interactions.

# Project Overview
**The Problem: The Cycle of Isolation**

- Many individuals experience a fear of judgment that leads to chronic loneliness. This results in:
- Mental Health Decline: Increased risks of depression and anxiety.
- Skill Loss: Atrophy of basic communication skills like "small talk."
- Information Gap: Falling "out of the loop" regarding casual real-world knowledge.

**Our Solution**

We built an AI friend that takes the lead. Unlike standard bots, it initiates check-ins and shares authentic stories, creating a safe practice space for users to rebuild their social muscles.

**SDG Alignment**
- SDG 3 (Good Health): Reducing loneliness through proactive companionship.
- SDG 4 (Quality Education): Teaching digital safety and life skills through casual storytelling.
- SDG 10 (Reduced Inequalities): Using diverse AI personas to foster empathy and reduce discrimination.

# Key Features
- 📢 Proactive Interaction: The AI initiates conversations at random times daily—it doesn't just wait for you.
- 🎭 Human-Like Personas: Interact with grounded characters, like a 21-year-old programmer from KL.
- 🌍 Real-Time Context: Integrated with world events to ensure conversations feel authentic and current.

# Tech Stack
**Google Technologies**

- Gemini AI (gemini-2.5-flash): High-speed, context-aware dialogue engine.
- Cloud Firestore: Real-time NoSQL database for instant chat synchronization.
- Firebase Console: Infrastructure management and security rule enforcement.
- Android Studio: Primary development environment.

**Supporting Tools**

- Flutter: Cross-platform UI framework.
- Google Generative AI Package: Bridge between Flutter and the LLM.

# Implementation Details

**System Architecture**

The app utilizes a Real-Time Stream Architecture:
- Frontend: Flutter UI listens to a Firestore Stream for instant rendering.
- Persistence: Every message is indexed with userId and timestamp.
- Intelligence: The GenerativeModel processes history to generate persona-driven responses.

**Workflow**

- Input: User message is saved to Firestore.
- Processing: Message history is sent to the Gemini ChatSession.
- Response: Gemini generates a reply based on its specific "System Instruction."
- Update: The response writes back to Firestore, auto-updating the UI.

# Challenges Faced
- Composite Indexing: Solved FAILED_PRECONDITION errors by manually creating composite indexes in Firebase for userId and timestamp.
- API Configuration: Resolved v1beta version mismatches by standardizing on the stable gemini-2.5-flash model.
- Security: Implemented .env management to ensure GEMINI_API_KEY is never leaked to public repositories.

# Installation & Setup ?
download APK (only available for Android) https://drive.google.com/drive/folders/19U3gFJY9off4gC8dlIOacGqI_-5kjaVZ?usp=sharing

# Future Roadmap
- 📊 Mood Analytics: Summarize weekly sentiment to provide mental health insights.
- 🎙️ Voice Personas: Integrate Google Text-to-Speech for auditory companionship.
- 📍 Location-Based Suggestions: Real-world venue suggestions via Google Maps integration.
- 🌐 Global Expansion: More diverse personas and multi-language support.
