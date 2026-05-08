# 🧠 TradeGuard Pro: Project Master Brain

This document is the "Source of Truth" for the TradeGuard Pro project. It serves as a persistent memory for the AI agent to ensure continuity across sessions.

---

## 🚀 Core Mission
TradeGuard Pro is a premium financial utility designed to protect retail traders from **Pattern Day Trader (PDT)** violations. It tracks trade "strikes" across rolling 5-business-day windows and provides a functional lockdown to prevent account freezes.

## 🛠️ Technical Stack
- **Framework**: Flutter (v3.0+)
- **Platforms**: Android (Primary), Web, iOS
- **State Management**: Riverpod
- **Backend**: Firebase (Auth, Firestore)
- **Deployment**: Google Play Console

---

## 🔑 Key Identifiers & Credentials
- **Application ID**: `com.one_terminal.tradeguardpro`
- **Firebase Project ID**: `tradeguardpro5`
- **Web App URL**: `tradeguardpro5.web.app`
- **Brand Domain**: Financial Store brand site (handles legal/verification).
- **Google Sign-In Client ID**: `118109513018-7ivqfotsk4umcmggvnnfli2blvj8f5r8.apps.googleusercontent.com`

---

## 📂 Critical File Map
- **`lib/main.dart`**: Core PDT Logic Engine & US Market Holidays list.
- **`lib/firebase_options.dart`**: Firebase configuration.
- **`lib/legal_screens.dart`**: Privacy, TOS, and Refund policy UI.
- **`android/app/build.gradle.kts`**: Android build config & versioning.
- **`android/key.properties`**: Keystore credentials for production signing.
- **`brand_website/`**: Static site for brand verification and marketing.

---

## 📜 Business Logic (The "Needles")
- **T+1 Settlement**: Logic handles US Market T+1 rules for strike clearance.
- **Rolling 5-Day Window**: Unlike a simple counter, strikes expire based on *business days* (skipping weekends and market holidays).
- **Hardcoded Holidays**: The `usHolidays` list in `main.dart` must be updated annually to maintain accuracy.
- **Pro Features**: Subscription-based cloud sync. Users without Pro store data locally via `SharedPreferences`.

---

## 🕒 Recent History & Context (2026)
- **Billing Errors**: Investigated "Developer Error" in Play Store billing. Identified fingerprint mismatches between Firebase and Play Console.
- **Keystore Migration**: Generated a clean production keystore (`tradeguard_production.jks`) to resolve signing issues.
- **UI Refinement**: Implemented "Inter" font and fixed button overflow issues for high-resolution screens.
- **Legal Compliance**: Created dedicated internal screens for Privacy and Refund policies to pass Google review.
- **SnapTrade Incident (May 2026)**: Attempted to integrate SnapTrade for margin monitoring (Rule 4210 roadmap). The integration caused significant stability issues and was rolled back.
- **Restoration**: Successfully restored the app to the stable PDT-only logic (April 19 baseline) while retaining premium aesthetic improvements and legal screen updates. Added conditional imports to support both Web (Paddle) and Android builds.


---

## 🛡️ Future Continuity Notes
- **Next Steps**: Monitor Play Console closed testing (14-day requirement).
- **Verification**: Ensure SHA256 from Play Console "App Integrity" is always synced with Firebase Fingerprints.
- **FINRA Rule 4210 Update**: PDT rules are scheduled to change in June 2026. TradeGuard Pro v2.0 will need to transition from "Strike Tracking" to "Real-time Margin Excess" monitoring.
- **Maintenance**: Update `usHolidays` for 2027 in Q4 2026.

---
*Created on 2026-05-01 by Antigravity AI.*
