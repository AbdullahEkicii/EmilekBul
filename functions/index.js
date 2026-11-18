const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const GEMINI_MODELS = [
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.0-flash-lite",
];

/**
 * Verifies Firebase Auth ID token and optional App Check token,
 * then forwards quiz generation requests to Gemini without exposing keys on clients.
 */
exports.aiGenerateQuestions = onRequest(
  {
    region: "europe-west1",
    secrets: [geminiApiKey],
    timeoutSeconds: 30,
    cors: false,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    const authHeader = req.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
      res.status(401).json({ error: "missing_auth_token" });
      return;
    }

    try {
      const idToken = authHeader.slice("Bearer ".length).trim();
      await admin.auth().verifyIdToken(idToken);
    } catch (err) {
      res.status(401).json({ error: "invalid_auth_token" });
      return;
    }

    const appCheckToken = req.get("X-Firebase-AppCheck");
    if (appCheckToken) {
      try {
        await admin.appCheck().verifyToken(appCheckToken);
      } catch (err) {
        res.status(401).json({ error: "invalid_app_check_token" });
        return;
      }
    }

    const { prompt, maxOutputTokens = 4096, responseMimeType = "application/json" } =
      req.body || {};
    if (typeof prompt !== "string" || !prompt.trim()) {
      res.status(400).json({ error: "missing_prompt" });
      return;
    }

    const apiKey = geminiApiKey.value() || process.env.GEMINI_API_KEY;
    if (!apiKey) {
      res.status(500).json({ error: "gemini_key_unconfigured" });
      return;
    }

    for (const model of GEMINI_MODELS) {
      try {
        const endpoint =
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens,
              responseMimeType,
            },
          }),
        });

        if (!response.ok) {
          continue;
        }
        const payload = await response.json();
        const text = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          res.status(200).json({ text });
          return;
        }
      } catch (_) {
        // Try next fallback model
      }
    }

    res.status(502).json({ error: "ai_generation_failed" });
  }
);

/**
 * Sends a push notification when a player receives a new 1v1 duel invite.
 */
exports.onDuelInviteCreated = onDocumentCreated(
  {
    document: "users/{targetUid}/duel_invites/{inviteId}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const targetUid = event.params.targetUid;
    const userDoc = await admin.firestore().doc(`users/${targetUid}`).get();
    const token = userDoc.get("fcmToken");
    if (!token || typeof token !== "string") return;

    const senderName = data.senderName || "Player";
    const category = data.category || "Quiz";
    await admin.messaging().send({
      token,
      notification: {
        title: `${senderName} -> 1v1`,
        body: category,
      },
      data: {
        type: "duel_invite",
        roomCode: String(data.roomCode || ""),
        inviteId: event.params.inviteId,
      },
    });
  }
);

/**
 * Notifies invited friends when a friend tournament is created.
 */
exports.onTournamentCreated = onDocumentCreated(
  {
    document: "tournaments/{tournamentId}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const creatorUid = data.creatorUid;
    const memberUids = Array.isArray(data.memberUids) ? data.memberUids : [];
    const recipientUids = memberUids.filter((uid) => uid && uid !== creatorUid);
    if (recipientUids.length === 0) return;

    const tokenDocs = await Promise.all(
      recipientUids.map((uid) => admin.firestore().doc(`users/${uid}`).get())
    );
    const tokens = tokenDocs
      .map((doc) => doc.get("fcmToken"))
      .filter((t) => typeof t === "string" && t.length > 0);
    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: String(data.title || "Friend Tournament"),
        body: String(data.category || "Quiz"),
      },
      data: {
        type: "tournament_invite",
        tournamentId: event.params.tournamentId,
      },
    });
  }
);
