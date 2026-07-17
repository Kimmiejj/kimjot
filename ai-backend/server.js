const crypto = require("node:crypto");
const express = require("express");
const axios = require("axios");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
require("dotenv").config();

const app = express();
app.use(express.json({ limit: "6mb" }));

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.env.gemini_key;
const GEMINI_MODEL_POOL = uniqueModels([
  process.env.GEMINI_MODEL,
  ...String(process.env.GEMINI_MODEL_POOL || "").split(","),
  process.env.GEMINI_FALLBACK_MODEL,
  "gemini-3.1-flash-lite",
  "gemini-3.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
]);
const GEMINI_MODEL = GEMINI_MODEL_POOL[0];
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || "kimjot";
const FIREBASE_SERVICE_ACCOUNT_JSON = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const RECOVERY_ESCROW_MASTER_KEY = parseEscrowMasterKey(
  process.env.RECOVERY_ESCROW_MASTER_KEY,
);
const RECOVERY_SMTP_USER = String(process.env.RECOVERY_SMTP_USER || "").trim();
const RECOVERY_SMTP_APP_PASSWORD = String(
  process.env.RECOVERY_SMTP_APP_PASSWORD || "",
).replace(/\s/g, "");
const RECOVERY_EMAIL_COOLDOWN_MS = 5 * 60 * 1000;
const DAILY_LIMIT = Number.parseInt(process.env.AI_DAILY_LIMIT || "300", 10);
const ALLOWED_EMAILS = new Set(
  String(process.env.AI_ALLOWED_EMAILS || "")
    .split(",")
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean),
);

if (!GEMINI_API_KEY) {
  console.warn("GEMINI_API_KEY is missing; AI routes will return 503.");
}

initializeFirebase();
const db = FIREBASE_SERVICE_ACCOUNT_JSON ? admin.firestore() : null;
const localUsage = new Map();
const modelHealth = new Map();
const recoveryEmailTransport = RECOVERY_SMTP_USER && RECOVERY_SMTP_APP_PASSWORD
  ? nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: RECOVERY_SMTP_USER,
        pass: RECOVERY_SMTP_APP_PASSWORD,
      },
    })
  : null;

app.get("/health", (_request, response) => {
  response.json({
    status: GEMINI_API_KEY ? "ready" : "setup_required",
    recovery: RECOVERY_ESCROW_MASTER_KEY && recoveryEmailTransport
      ? "ready"
      : "setup_required",
    provider: "gemini",
    model: GEMINI_MODEL,
    models: GEMINI_MODEL_POOL,
  });
});

app.use(async (request, response, next) => {
  if (request.path === "/health") return next();
  const token = request.headers.authorization?.replace(/^Bearer\s+/i, "");
  if (!token) return response.status(401).json({ error: "authentication_required" });

  try {
    request.user = await admin.auth().verifyIdToken(token);
    request.firebaseToken = token;
    const email = String(request.user.email || "").toLowerCase();
    const isRecoveryRoute = request.path.startsWith("/v1/recovery-key/");
    const isAccountRoute = request.path === "/v1/account";
    if (
      !isRecoveryRoute &&
      !isAccountRoute &&
      ALLOWED_EMAILS.size > 0 &&
      !ALLOWED_EMAILS.has(email)
    ) {
      return response.status(403).json({ error: "account_not_allowed" });
    }
    next();
  } catch (_error) {
    response.status(401).json({ error: "invalid_firebase_token" });
  }
});

app.delete("/v1/account", async (request, response) => {
  if (!db) {
    return response.status(503).json({ error: "account_deletion_not_configured" });
  }

  const authTime = Number(request.user.auth_time || 0) * 1000;
  if (!authTime || Date.now() - authTime > 5 * 60 * 1000) {
    return response.status(401).json({ error: "recent_login_required" });
  }

  try {
    await deleteUserAccount(request.user.uid);
    response.json({ deleted: true });
  } catch (error) {
    console.error(request.path, error.code || error.message);
    response.status(500).json({ error: "account_deletion_failed" });
  }
});

app.post("/v1/recovery-key/escrow", recoveryRoute(async (request) => {
  const { uid, email } = verifiedRecoveryIdentity(request.user);
  const recoveryKey = String(request.body.recoveryKey || "").trim();
  const keyVersion = request.body.keyVersion;
  const escrowId = String(request.body.escrowId || "");
  if (recoveryKey.length < 12 || recoveryKey.length > 256) {
    return httpError(400, "invalid_recovery_key");
  }
  if (!Number.isSafeInteger(keyVersion) || keyVersion < 1) {
    return httpError(400, "invalid_key_version");
  }
  if (
    escrowId.length < 16 ||
    escrowId.length > 128 ||
    !/^[A-Za-z0-9_-]+={0,2}$/.test(escrowId)
  ) {
    return httpError(400, "invalid_escrow_id");
  }

  const aad = escrowAssociatedData(uid, email, keyVersion, escrowId);
  const encrypted = encryptEscrow(recoveryKey, RECOVERY_ESCROW_MASTER_KEY, aad);
  await writeFirestoreDocument(
    `recovery_key_escrow/${uid}/keys/${escrowId}`,
    request.firebaseToken,
    {
      ...encrypted,
      algorithm: "aes-256-gcm",
      keyVersion,
      emailHash: sha256(email),
      createdAt: new Date(),
    },
  );
  return { stored: true };
}));

app.post("/v1/recovery-key/email", recoveryRoute(async (request) => {
  const { uid, email } = verifiedRecoveryIdentity(request.user);
  const [config, metadata] = await Promise.all([
    readFirestoreDocument(
      `users/${uid}/security/transactionEncryption`,
      request.firebaseToken,
    ),
    readFirestoreDocument(
      `recovery_key_escrow/${uid}`,
      request.firebaseToken,
    ),
  ]);
  const keyVersion = config?.keyVersion;
  const escrowId = config?.escrowId;
  if (!Number.isSafeInteger(keyVersion) || typeof escrowId !== "string") {
    return httpError(404, "recovery_key_not_found");
  }

  const lastSent = metadata?.lastEmailSentAt instanceof Date
    ? metadata.lastEmailSentAt.getTime()
    : 0;
  if (Date.now() - lastSent < RECOVERY_EMAIL_COOLDOWN_MS) {
    return httpError(429, "recovery_email_rate_limited");
  }

  const escrow = await readFirestoreDocument(
    `recovery_key_escrow/${uid}/keys/${escrowId}`,
    request.firebaseToken,
  );
  if (!escrow || escrow.keyVersion !== keyVersion || escrow.emailHash !== sha256(email)) {
    return httpError(404, "recovery_key_not_found");
  }
  const aad = escrowAssociatedData(uid, email, keyVersion, escrowId);
  const recoveryKey = decryptEscrow(escrow, RECOVERY_ESCROW_MASTER_KEY, aad);
  try {
    await recoveryEmailTransport.sendMail({
      from: `Kimjod <${RECOVERY_SMTP_USER}>`,
      to: email,
      subject: "Kimjod recovery key",
      text: [
        "You requested your Kimjod recovery key.",
        "",
        recoveryKey,
        "",
        "Keep this key private. If you did not request this email, sign in to Kimjod and change the recovery key.",
      ].join("\n"),
    });
  } catch (error) {
    throw recoveryEmailProviderError(error);
  }
  await writeFirestoreDocument(
    `recovery_key_escrow/${uid}`,
    request.firebaseToken,
    { lastEmailSentAt: new Date() },
  );
  return { email: maskEmail(email) };
}));

app.get("/v1/models", (request, response) => {
  response.json({
    selected: {
      fast: selectModel("fast", "chat"),
      balanced: selectModel("balanced", "chat"),
      deep: selectModel("deep", "chat"),
      auto: {
        slip: selectModel("auto", "slip"),
        voice: selectModel("auto", "voice"),
        analysis: selectModel("auto", "analysis"),
      },
    },
    transcription: selectModel("fast", "voice"),
    pool: modelPoolStatus(),
    dailyLimit: DAILY_LIMIT,
  });
});

app.post("/v1/slip/amount", aiRoute(async (request) => {
  const candidates = Array.isArray(request.body.candidates)
    ? request.body.candidates.filter(Number.isFinite).slice(0, 24)
    : [];
  if (!request.body.rawText || candidates.length === 0) {
    return httpError(400, "invalid_slip_amount_input");
  }

  return callGemini({
    model: selectModel(request.body.mode, "slip"),
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        chosen: { type: ["number", "null"] },
        confidence: { type: "number", minimum: 0, maximum: 1 },
      },
      required: ["chosen", "confidence"],
    },
    instructions: "Select the actual transferred amount from the supplied candidates. Return no amount outside the candidate list.",
    content: [{
      type: "input_text",
      text: `OCR:\n${String(request.body.rawText).slice(0, 6000)}\n\nCandidates: ${candidates.join(", ")}`,
    }],
    maxOutputTokens: 80,
  });
}));

app.post("/v1/slip/analyze", aiRoute(async (request) => {
  const allowed = Array.isArray(request.body.allowedCategoryIds)
    ? request.body.allowedCategoryIds.map(String).slice(0, 40)
    : [];
  if (!request.body.rawText || allowed.length === 0) {
    return httpError(400, "invalid_slip_input");
  }

  const content = [{
    type: "input_text",
    text: [
      `OCR:\n${String(request.body.rawText).slice(0, 8000)}`,
      `Extracted: ${JSON.stringify(request.body.extracted || {})}`,
      `Allowed categories: ${allowed.join(", ")}`,
      "Classify names person-agnostically: never rely on a specific known user's name.",
      "Compare sender and recipient first names after removing Thai/English titles, spacing, and OCR noise. Treat a one-character or Thai-diacritic OCR difference as the same name when the rest clearly matches.",
      "Use internal_transfer when those normalized first names are the same. Never override a deterministic or high-confidence same-first-name match with expense.",
    ].join("\n\n"),
  }];
  if (typeof request.body.imageBase64 === "string") {
    content.push({
      type: "input_image",
      image_url: `data:image/jpeg;base64,${request.body.imageBase64}`,
    });
  }

  return callGemini({
    model: selectModel(request.body.mode, "slip"),
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        type: { type: "string", enum: ["expense", "internal_transfer"] },
        categoryId: { type: "string", enum: allowed },
        note: { type: ["string", "null"] },
        amount: { type: ["number", "null"] },
        dateText: { type: ["string", "null"] },
        timeText: { type: ["string", "null"] },
        sender: { type: ["string", "null"] },
        recipient: { type: ["string", "null"] },
        reference: { type: ["string", "null"] },
        confidence: { type: "number", minimum: 0, maximum: 1 },
      },
      required: [
        "type", "categoryId", "note", "amount", "dateText", "timeText",
        "sender", "recipient", "reference", "confidence",
      ],
    },
    instructions: "Extract and classify a Thai or English payment slip. Keep notes factual and short. Do not include full account numbers or personal names in notes.",
    content,
    maxOutputTokens: 180,
  });
}));

app.post("/v1/voice/transcribe", aiRoute(async (request) => {
  const encoded = request.body.audioBase64;
  if (typeof encoded !== "string" || encoded.length === 0) {
    return httpError(400, "missing_audio");
  }
  const audio = Buffer.from(encoded, "base64");
  if (audio.length === 0 || audio.length > 4 * 1024 * 1024) {
    return httpError(400, "invalid_audio_size");
  }

  return callGemini({
    model: GEMINI_MODEL,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: { transcript: { type: "string" } },
      required: ["transcript"],
    },
    instructions: "Transcribe the supplied speech accurately. Return only what was spoken and do not add commentary.",
    content: [
      {
        type: "input_audio",
        mimeType: request.body.mimeType || "audio/mp4",
        data: encoded,
      },
      {
        type: "input_text",
        text: request.body.language === "th"
          ? "The recording is expected to be Thai."
          : "The recording is expected to be English.",
      },
    ],
    maxOutputTokens: 500,
    timeout: 30000,
  });
}));

app.post("/v1/voice/transaction", aiRoute(async (request) => {
  if (!request.body.transcript) return httpError(400, "missing_transcript");
  const categories = [
    "food", "drink", "groceries", "transport", "shopping", "bills",
    "rent", "health", "education", "entertainment", "travel", "family",
    "insurance", "tax", "donation", "transfer", "salary", "side_job",
    "business", "bonus", "investment", "interest", "sale", "allowance",
    "gift", "refund", "internal_transfer", "other",
  ];
  return callGemini({
    model: selectModel(request.body.mode, "voice"),
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        transactions: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              amount: { type: "number", minimum: 0.01 },
              type: { type: "string", enum: ["expense", "income", "internal_transfer"] },
              categoryId: { type: "string", enum: categories },
              categoryName: { type: "string" },
              note: { type: ["string", "null"] },
              transactionDate: { type: "string" },
            },
            required: ["amount", "type", "categoryId", "categoryName", "note", "transactionDate"],
          },
        },
      },
      required: ["transactions"],
    },
    instructions: "Turn a Thai or English spoken money note into transaction drafts. Detect every distinct transaction and return one array item per transaction; never combine separate purchases or incomes. If the speaker says KFC 200 and a tree 129, return two items. If there is only one transaction, return one item. Preserve the merchant or item in a short note, resolve relative dates from the supplied current time, and never invent an amount.",
    content: [{
      type: "input_text",
      text: `Current time: ${request.body.now}\nTranscript: ${String(request.body.transcript).slice(0, 1500)}`,
    }],
    maxOutputTokens: 700,
  });
}));

app.post("/v1/analysis", aiRoute(async (request) => {
  const summary = request.body.summary;
  if (!summary || typeof summary !== "object") return httpError(400, "missing_summary");

  const mode = request.body.mode || "auto";
  const model = selectModel(mode, "analysis");
  const cacheKey = crypto
    .createHash("sha256")
    .update(JSON.stringify({ uid: request.user.uid, summary, mode, model }))
    .digest("hex");
  const cacheRef = db?.collection("ai_analysis_cache").doc(cacheKey);
  if (cacheRef) {
    const cached = await cacheRef.get();
    if (cached.exists) {
      const data = cached.data();
      const createdAt = data?.createdAt?.toDate?.();
      if (createdAt && Date.now() - createdAt.getTime() < 6 * 60 * 60 * 1000) {
        return { ...data.result, model: data.result?.model || model, cached: true };
      }
    }
  }

  const result = await callGemini({
    model,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        headline: { type: "string" },
        strengths: { type: "array", items: { type: "string" }, maxItems: 4 },
        risks: { type: "array", items: { type: "string" }, maxItems: 4 },
        recommendations: { type: "array", items: { type: "string" }, maxItems: 4 },
        suggestedMonthlyCut: { type: "number", minimum: 0 },
      },
      required: ["headline", "strengths", "risks", "recommendations", "suggestedMonthlyCut"],
    },
    instructions: "Analyze only the aggregated personal-finance facts supplied. Respond in concise Thai. Give practical budgeting observations, not investment, tax, legal, or credit advice. Never fabricate missing income or goals.",
    content: [{
      type: "input_text",
      text: JSON.stringify(summary).slice(0, 12000),
    }],
    maxOutputTokens: mode === "deep" ? 650 : 420,
  });
  if (cacheRef) {
    await cacheRef.set({
      uid: request.user.uid,
      result,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return { ...result, model: result.model || model, cached: false };
}));

app.post("/v1/chat", aiRoute(async (request) => {
  const message = String(request.body.message || "").trim().slice(0, 2000);
  if (!message) return httpError(400, "missing_message");

  const history = Array.isArray(request.body.history)
    ? request.body.history
      .slice(-12)
      .map((item) => ({
        role: item?.role === "assistant" ? "assistant" : "user",
        content: String(item?.content || "").trim().slice(0, 2000),
      }))
      .filter((item) => item.content)
    : [];
  const mode = request.body.mode || "auto";
  const model = selectModel(mode, "chat");
  const context = request.body.context && typeof request.body.context === "object"
    ? JSON.stringify(request.body.context).slice(0, 5000)
    : "{}";

  const result = await callGemini({
    model,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        answer: { type: "string" },
        suggestions: {
          type: "array",
          items: { type: "string" },
          maxItems: 3,
        },
      },
      required: ["answer", "suggestions"],
    },
    instructions: [
      "You are Kimjod AI, a concise and friendly personal-finance assistant inside a Thai expense-tracking app.",
      "Answer in the user's language. Use supplied aggregate facts when relevant and clearly say when data is missing.",
      "Do not invent transactions, balances, income, goals, or account details.",
      "Give educational budgeting help, not personalized investment, legal, tax, lending, or medical advice.",
      "Never claim that an action or transaction was saved; this chat is read-only.",
    ].join(" "),
    content: [{
      type: "input_text",
      text: [
        `Current time: ${new Date().toISOString()}`,
        `Aggregate app context: ${context}`,
        `Recent conversation: ${JSON.stringify(history)}`,
        `User message: ${message}`,
      ].join("\n\n"),
    }],
    maxOutputTokens: mode === "deep" ? 700 : 450,
  });
  return { ...result, model: result.model || model };
}));

app.post("/mcp", async (request, response) => {
  const { id, method, params } = request.body || {};
  const ok = (result) => response.json({ jsonrpc: "2.0", id, result });
  if (method === "initialize") {
    return ok({
      protocolVersion: "2025-06-18",
      capabilities: { tools: {} },
      serverInfo: { name: "kimjod", version: "1.0.0" },
    });
  }
  if (method === "tools/list") {
    return ok({ tools: mcpTools() });
  }
  if (method === "tools/call") {
    try {
      const result = await callMcpTool(request.user.uid, params?.name, params?.arguments || {});
      return ok({ content: [{ type: "text", text: JSON.stringify(result) }], structuredContent: result });
    } catch (error) {
      return response.json({
        jsonrpc: "2.0",
        id,
        error: { code: -32602, message: error.message || "Tool failed" },
      });
    }
  }
  response.json({ jsonrpc: "2.0", id, error: { code: -32601, message: "Method not found" } });
});

function aiRoute(handler) {
  return async (request, response) => {
    if (!GEMINI_API_KEY) return response.status(503).json({ error: "ai_not_configured" });
    const startedAt = Date.now();
    try {
      await consumeQuota(request.user.uid);
      const result = await handler(request);
      if (result?.httpStatus) {
        await recordAiUsage(request, {
          success: false,
          latencyMs: Date.now() - startedAt,
        });
        return response.status(result.httpStatus).json({ error: result.error });
      }
      const telemetry = result?._telemetry || {};
      await recordAiUsage(request, {
        success: true,
        latencyMs: Date.now() - startedAt,
        model: telemetry.model || result?.model,
        inputTokens: telemetry.inputTokens,
        outputTokens: telemetry.outputTokens,
        cached: result?.cached === true,
      });
      if (result && typeof result === "object") delete result._telemetry;
      response.json(result);
    } catch (error) {
      const status = error.httpStatus || 500;
      console.error(request.path, error.response?.data || error.message);
      if (status !== 429) {
        await recordAiUsage(request, {
          success: false,
          latencyMs: Date.now() - startedAt,
        });
      }
      response.status(status).json({ error: status === 429 ? "daily_quota_reached" : "ai_request_failed" });
    }
  };
}

function recoveryRoute(handler) {
  return async (request, response) => {
    if (!RECOVERY_ESCROW_MASTER_KEY || !recoveryEmailTransport) {
      return response.status(503).json({ error: "recovery_service_not_configured" });
    }
    try {
      const result = await handler(request);
      if (result?.httpStatus) {
        return response.status(result.httpStatus).json({ error: result.error });
      }
      response.json(result);
    } catch (error) {
      const status = error.httpStatus || 500;
      const publicError = error.publicError || "recovery_service_failed";
      console.error(request.path, error.code || error.message);
      response.status(status).json({ error: publicError });
    }
  };
}

function verifiedRecoveryIdentity(user) {
  const email = String(user.email || "").trim().toLowerCase();
  if (!email || user.email_verified !== true) {
    throw Object.assign(new Error("A verified email is required"), {
      httpStatus: 403,
      publicError: "verified_email_required",
    });
  }
  return { uid: user.uid, email };
}

function recoveryEmailProviderError(error) {
  if (error.code === "EAUTH" || error.responseCode === 535) {
    return Object.assign(new Error(error.message), {
      httpStatus: 503,
      publicError: "recovery_email_auth_failed",
    });
  }
  if (error.code === "EENVELOPE" || error.responseCode === 550) {
    return Object.assign(new Error(error.message), {
      httpStatus: 422,
      publicError: "recovery_email_rejected",
    });
  }
  return error;
}

function parseEscrowMasterKey(value) {
  if (!value) return null;
  const normalized = String(value).trim();
  const key = /^[0-9a-fA-F]{64}$/.test(normalized)
    ? Buffer.from(normalized, "hex")
    : Buffer.from(normalized, "base64");
  if (key.length !== 32) {
    throw new Error("RECOVERY_ESCROW_MASTER_KEY must decode to exactly 32 bytes");
  }
  return key;
}

function escrowAssociatedData(uid, email, keyVersion, escrowId) {
  return `kimjod.recovery-escrow.v1|${uid}|${email}|${keyVersion}|${escrowId}`;
}

function encryptEscrow(clearText, masterKey, associatedData) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", masterKey, iv);
  cipher.setAAD(Buffer.from(associatedData, "utf8"));
  const ciphertext = Buffer.concat([
    cipher.update(clearText, "utf8"),
    cipher.final(),
  ]);
  return {
    iv: iv.toString("base64"),
    ciphertext: ciphertext.toString("base64"),
    tag: cipher.getAuthTag().toString("base64"),
  };
}

function decryptEscrow(envelope, masterKey, associatedData) {
  const decipher = crypto.createDecipheriv(
    "aes-256-gcm",
    masterKey,
    Buffer.from(envelope.iv, "base64"),
  );
  decipher.setAAD(Buffer.from(associatedData, "utf8"));
  decipher.setAuthTag(Buffer.from(envelope.tag, "base64"));
  return Buffer.concat([
    decipher.update(Buffer.from(envelope.ciphertext, "base64")),
    decipher.final(),
  ]).toString("utf8");
}

function sha256(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function maskEmail(email) {
  const [local, domain] = email.split("@");
  if (!domain) return "***";
  const visible = local.slice(0, Math.min(2, local.length));
  return `${visible}${"*".repeat(Math.max(3, local.length - visible.length))}@${domain}`;
}

async function readFirestoreDocument(path, firebaseToken) {
  const response = await fetch(firestoreDocumentUrl(path), {
    headers: { authorization: `Bearer ${firebaseToken}` },
    signal: AbortSignal.timeout(10000),
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    throw Object.assign(
      new Error(`Firestore read failed (${response.status})`),
      { code: "firestore_read_failed" },
    );
  }
  return decodeFirestoreDocument(await response.json());
}

async function writeFirestoreDocument(path, firebaseToken, data) {
  const response = await fetch(firestoreDocumentUrl(path), {
    method: "PATCH",
    headers: {
      authorization: `Bearer ${firebaseToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ fields: encodeFirestoreFields(data) }),
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) {
    throw Object.assign(
      new Error(`Firestore write failed (${response.status})`),
      { code: "firestore_write_failed" },
    );
  }
}

function firestoreDocumentUrl(path) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}/databases/(default)/documents/${encodedPath}`;
}

function encodeFirestoreFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => {
    if (value instanceof Date) {
      return [key, { timestampValue: value.toISOString() }];
    }
    if (Number.isSafeInteger(value)) {
      return [key, { integerValue: String(value) }];
    }
    if (typeof value === "string") {
      return [key, { stringValue: value }];
    }
    throw new Error(`Unsupported Firestore field: ${key}`);
  }));
}

function decodeFirestoreDocument(document) {
  if (!document?.fields) return null;
  return Object.fromEntries(Object.entries(document.fields).map(([key, value]) => {
    if ("stringValue" in value) return [key, value.stringValue];
    if ("integerValue" in value) return [key, Number(value.integerValue)];
    if ("timestampValue" in value) return [key, new Date(value.timestampValue)];
    if ("booleanValue" in value) return [key, value.booleanValue];
    return [key, null];
  }));
}

async function consumeQuota(uid) {
  if (DAILY_LIMIT <= 0) return;
  const day = new Date().toISOString().slice(0, 10);
  if (!db) {
    const key = `${uid}_${day}`;
    const count = localUsage.get(key) || 0;
    if (count >= DAILY_LIMIT) throw Object.assign(new Error("quota"), { httpStatus: 429 });
    localUsage.set(key, count + 1);
    return;
  }
  const ref = db.collection("ai_usage").doc(`${uid}_${day}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const count = snapshot.data()?.count || 0;
    if (count >= DAILY_LIMIT) throw Object.assign(new Error("quota"), { httpStatus: 429 });
    transaction.set(ref, {
      uid,
      day,
      count: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}

async function deleteUserAccount(uid) {
  const [dailyUsage, aiUsage, analysisCache] = await Promise.all([
    db.collectionGroup("daily_users").where("uid", "==", uid).get(),
    db.collection("ai_usage")
      .where(admin.firestore.FieldPath.documentId(), ">=", `${uid}_`)
      .where(admin.firestore.FieldPath.documentId(), "<", `${uid}_\uf8ff`)
      .get(),
    db.collection("ai_analysis_cache").where("uid", "==", uid).get(),
  ]);

  const bulkWriter = db.bulkWriter();
  bulkWriter.delete(db.collection("usage_users").doc(uid));
  for (const snapshot of [dailyUsage, aiUsage, analysisCache]) {
    for (const document of snapshot.docs) bulkWriter.delete(document.ref);
  }

  await Promise.all([
    db.recursiveDelete(db.collection("users").doc(uid)),
    db.recursiveDelete(db.collection("recovery_key_escrow").doc(uid)),
    bulkWriter.close(),
  ]);

  for (const key of localUsage.keys()) {
    if (key.startsWith(`${uid}_`)) localUsage.delete(key);
  }

  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }
}

async function recordAiUsage(request, telemetry) {
  if (!db || !request.user?.uid) return;
  try {
    const day = new Date().toISOString().slice(0, 10);
    const route = String(request.path || "unknown")
      .replace(/^\/v1\//, "")
      .replace(/[^A-Za-z0-9_-]/g, "_") || "unknown";
    const model = String(telemetry.model || "").replace(/[^A-Za-z0-9_.-]/g, "_");
    const increment = admin.firestore.FieldValue.increment;
    const update = {
      successCount: increment(telemetry.success ? 1 : 0),
      failureCount: increment(telemetry.success ? 0 : 1),
      inputTokens: increment(Number(telemetry.inputTokens || 0)),
      outputTokens: increment(Number(telemetry.outputTokens || 0)),
      totalLatencyMs: increment(Number(telemetry.latencyMs || 0)),
      latencySamples: increment(1),
      cachedCount: increment(telemetry.cached ? 1 : 0),
      routes: { [route]: increment(1) },
      lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (model) update.models = { [model]: increment(1) };
    await db.collection("ai_usage").doc(`${request.user.uid}_${day}`).set(update, { merge: true });
  } catch (error) {
    console.warn("AI telemetry write failed:", error.message);
  }
}

async function callGemini({ model, schema, instructions, content, maxOutputTokens, timeout = 28000 }) {
  const parts = content.map((item) => {
    if (item.type === "input_text") return { text: item.text };
    if (item.type === "input_audio") {
      return { inlineData: { mimeType: item.mimeType, data: item.data } };
    }
    if (item.type === "input_image") {
      const match = /^data:([^;]+);base64,(.+)$/s.exec(item.image_url || "");
      if (!match) throw new Error("Invalid image data URL");
      return { inlineData: { mimeType: match[1], data: match[2] } };
    }
    throw new Error(`Unsupported Gemini input type: ${item.type}`);
  });
  const requestBody = {
    systemInstruction: { parts: [{ text: instructions }] },
    contents: [{ role: "user", parts }],
    generationConfig: {
      maxOutputTokens,
      responseFormat: {
        text: {
          mimeType: "APPLICATION_JSON",
          schema,
        },
      },
    },
  };
  const models = modelCandidates(model);
  const deadline = Date.now() + timeout;
  let lastError;
  for (let index = 0; index < models.length; index++) {
    const candidateModel = models[index];
    const remaining = deadline - Date.now();
    if (remaining < 1200) break;
    try {
      const attemptsLeft = models.length - index;
      const attemptTimeout = Math.max(
        1200,
        Math.min(7000, Math.floor((remaining - (attemptsLeft - 1) * 250) / attemptsLeft)),
      );
      const response = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(candidateModel)}:generateContent`,
        requestBody,
        {
          headers: {
            "x-goog-api-key": GEMINI_API_KEY,
            "content-type": "application/json",
          },
          timeout: attemptTimeout,
        },
      );
      const text = response.data?.candidates?.[0]?.content?.parts
        ?.map((part) => part.text)
        .filter(Boolean)
        .join("");
      if (!text) {
        throw Object.assign(new Error("Gemini returned no structured output"), {
          invalidModelOutput: true,
        });
      }
      const result = JSON.parse(text);
      markModelSuccess(candidateModel);
      const usage = response.data?.usageMetadata || {};
      return {
        ...result,
        model: candidateModel,
        _telemetry: {
          model: candidateModel,
          inputTokens: Number(usage.promptTokenCount || 0),
          outputTokens: Number(usage.candidatesTokenCount || 0),
        },
      };
    } catch (error) {
      lastError = error;
      const status = error.response?.status;
      const timedOut = error.code === "ECONNABORTED" || error.code === "ETIMEDOUT";
      const retryable = error instanceof SyntaxError ||
        error.invalidModelOutput ||
        timedOut ||
        status === 404 ||
        status === 408 ||
        status === 429 ||
        status >= 500;
      if (!retryable) throw error;
      markModelFailure(candidateModel, error);
      const nextModel = models[index + 1];
      if (nextModel) {
        console.warn(`Gemini ${candidateModel} unavailable; retrying with ${nextModel}.`);
      }
    }
  }
  throw lastError || Object.assign(new Error("All Gemini models are cooling down"), { httpStatus: 503 });
}

function selectModel(mode, task) {
  const qualityFirst = mode === "deep" || mode === "balanced" || task === "analysis";
  const preferred = qualityFirst
    ? ["gemini-3.5-flash", "gemini-2.5-flash"]
    : ["gemini-3.1-flash-lite", "gemini-2.5-flash-lite"];
  return preferred.find((model) => GEMINI_MODEL_POOL.includes(model)) || GEMINI_MODEL;
}

function uniqueModels(models) {
  return [...new Set(models.map((model) => String(model || "").trim()).filter(Boolean))];
}

function modelCandidates(preferredModel) {
  const ordered = uniqueModels([preferredModel, ...GEMINI_MODEL_POOL]);
  const now = Date.now();
  const ready = ordered.filter((model) => (modelHealth.get(model)?.cooldownUntil || 0) <= now);
  if (ready.length > 0) return ready;
  return ordered.sort(
    (left, right) =>
      (modelHealth.get(left)?.cooldownUntil || 0) -
      (modelHealth.get(right)?.cooldownUntil || 0),
  );
}

function markModelSuccess(model) {
  modelHealth.set(model, {
    failures: 0,
    cooldownUntil: 0,
    lastSuccessAt: Date.now(),
    lastError: null,
  });
}

function markModelFailure(model, error) {
  const previous = modelHealth.get(model) || { failures: 0 };
  const failures = previous.failures + 1;
  const status = error.response?.status;
  const retryAfter = Number.parseInt(error.response?.headers?.["retry-after"] || "0", 10) * 1000;
  const baseCooldown = status === 429
    ? 2 * 60 * 1000
    : status === 404
      ? 15 * 60 * 1000
      : 30 * 1000;
  const cooldown = Math.max(
    retryAfter,
    Math.min(baseCooldown * 2 ** Math.min(failures - 1, 3), 15 * 60 * 1000),
  );
  modelHealth.set(model, {
    failures,
    cooldownUntil: Date.now() + cooldown,
    lastSuccessAt: previous.lastSuccessAt || null,
    lastError: status || error.code || error.message,
  });
}

function modelPoolStatus() {
  const now = Date.now();
  return GEMINI_MODEL_POOL.map((model) => {
    const health = modelHealth.get(model);
    return {
      model,
      available: !health || health.cooldownUntil <= now,
      cooldownSeconds: health ? Math.max(0, Math.ceil((health.cooldownUntil - now) / 1000)) : 0,
      lastError: health?.lastError || null,
    };
  });
}

function httpError(httpStatus, error) {
  return { httpStatus, error };
}

function initializeFirebase() {
  if (admin.apps.length > 0) return;
  if (FIREBASE_SERVICE_ACCOUNT_JSON) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)),
      projectId: FIREBASE_PROJECT_ID,
    });
    return;
  }
  admin.initializeApp({ projectId: FIREBASE_PROJECT_ID });
}

function mcpTools() {
  return [
    {
      name: "get_financial_summary",
      description: "Read the signed-in Kimjod user's aggregated income and expense summary. Read-only.",
      inputSchema: {
        type: "object",
        properties: { months: { type: "integer", enum: [6, 12, 36] } },
        required: ["months"],
        additionalProperties: false,
      },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false },
    },
    {
      name: "draft_transaction",
      description: "Create a transaction draft from natural language. This never writes data.",
      inputSchema: {
        type: "object",
        properties: { text: { type: "string", maxLength: 1500 } },
        required: ["text"],
        additionalProperties: false,
      },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false },
    },
  ];
}

async function callMcpTool(uid, name, args) {
  if (name === "draft_transaction") {
    return { draftOnly: true, text: String(args.text || "").slice(0, 1500), instruction: "Open Kimjod to review before saving." };
  }
  if (name !== "get_financial_summary") throw new Error("Unknown tool");
  if (!db) throw new Error("Financial summary requires FIREBASE_SERVICE_ACCOUNT_JSON");
  const months = [6, 12, 36].includes(args.months) ? args.months : 6;
  const start = new Date();
  start.setMonth(start.getMonth() - months + 1, 1);
  start.setHours(0, 0, 0, 0);
  const snapshot = await db.collection("users").doc(uid).collection("transactions")
    .where("transactionDate", ">=", admin.firestore.Timestamp.fromDate(start))
    .get();
  let income = 0;
  let expense = 0;
  const categories = {};
  for (const document of snapshot.docs) {
    const data = document.data();
    const amount = Number(data.amount || 0);
    if (data.type === "income") income += amount;
    if (data.type === "expense") {
      expense += amount;
      const key = data.categoryId || "other";
      categories[key] = (categories[key] || 0) + amount;
    }
  }
  return { months, income, expense, balance: income - expense, categories, transactionCount: snapshot.size };
}

const port = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(port, () => console.log(`Kimjod AI backend listening on ${port}`));
}

module.exports = app;
module.exports._test = {
  decodeFirestoreDocument,
  encodeFirestoreFields,
  GEMINI_MODEL_POOL,
  decryptEscrow,
  encryptEscrow,
  escrowAssociatedData,
  markModelFailure,
  markModelSuccess,
  maskEmail,
  modelCandidates,
  parseEscrowMasterKey,
  recoveryEmailProviderError,
  selectModel,
};
