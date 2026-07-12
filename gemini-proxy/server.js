/**
 * Simple Gemini AI Proxy for Slip Amount Analysis
 *
 * Usage:
 * 1. npm install express axios dotenv
 * 2. Create .env: GEMINI_API_KEY=your_key
 * 3. node server.js
 * 4. Runs on http://localhost:3000/predict
 */

const express = require("express");
const axios = require("axios");
require("dotenv").config();

const app = express();
app.use(express.json());

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
if (!GEMINI_API_KEY) {
  throw new Error("Missing GEMINI_API_KEY in environment");
}
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

app.post("/predict", async (req, res) => {
  try {
    const { text, candidates } = req.body;

    if (!text || !candidates || candidates.length === 0) {
      return res.status(400).json({ error: "Missing text or candidates" });
    }

    const prompt = `You are an expert OCR and invoice analyzer.
You will analyze a payment slip and identify the correct payment amount.

OCR Text from slip:
${text}

Numeric candidates found: ${candidates.join(", ")}

Your task:
1. Identify which candidate is the payment amount
2. Return ONLY a JSON object (no markdown, no explanation):
{"chosen": <number from candidates or null>, "confidence": <0.0 to 1.0>}

Examples:
{"chosen": 396.0, "confidence": 0.95}
{"chosen": null, "confidence": 0.1}

Return ONLY JSON, nothing else.`;

    const response = await axios.post(GEMINI_URL, {
      contents: [
        {
          parts: [
            {
              text: prompt,
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 100,
      },
    });

    const result = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!result) {
      return res.status(500).json({ error: "No response from Gemini" });
    }

    // Parse JSON from response
    const jsonMatch = result.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error("Could not parse JSON from:", result);
      return res.status(500).json({ error: "Invalid response format" });
    }

    const parsed = JSON.parse(jsonMatch[0]);
    return res.json({
      chosen: parsed.chosen,
      confidence: Math.max(0, Math.min(1, parsed.confidence ?? 0.5)),
    });
  } catch (error) {
    console.error("Error:", error.message);
    return res.status(500).json({
      error: error.message,
      chosen: null,
      confidence: 0.0,
    });
  }
});

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅ Gemini AI Proxy running on http://localhost:${PORT}`);
  console.log(`📝 POST /predict - Analyze slip amounts`);
  console.log(`💓 GET /health - Health check`);
  console.log(`🔑 Using API Key: ${GEMINI_API_KEY.substring(0, 10)}...`);
});

