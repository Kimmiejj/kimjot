# External AI Setup Guide

This app supports calling external AI services (OpenAI, Gemini, or your own proxy) to analyze slip amounts using ML/LLM.

## Option 1: Using OpenAI (Chat Completions)

### Prerequisites
- OpenAI API key: https://platform.openai.com/account/api-keys

### Run Command (PowerShell)
```powershell
flutter run `
  --dart-define=EXTERNAL_AI_PROVIDER=openai `
  --dart-define=EXTERNAL_AI_KEY="sk-YOUR_OPENAI_KEY_HERE" `
  --dart-define=OPENAI_MODEL="gpt-3.5-turbo"
```

The app will send OCR text + candidate amounts to OpenAI, which returns the detected amount + confidence.

---

## Option 2: Using Google Gemini (Vertex AI Proxy)

Google Gemini doesn't support direct auth from a mobile app (requires OAuth/service accounts). Instead, use a proxy server.

### Example Node.js Proxy (Firebase Cloud Functions or Vercel)

```javascript
// api/gemini-proxy.js or similar
const { GoogleGenerativeAI } = require("@google/generative-ai");

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { text, candidates } = req.body;
  if (!text || !candidates) {
    return res.status(400).json({ error: "Missing text or candidates" });
  }

  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const prompt = `You are an expert OCR and invoice analyzer.
You will be given OCR text from a payment slip and a list of numeric candidates.
Return ONLY a JSON object (no markdown, no explanation) with:
- "chosen": the numeric value from the candidates list that is the payment amount (or null if unsure)
- "confidence": a number between 0 and 1 representing confidence

OCR Text:
${text}

Candidates: ${candidates.join(", ")}

Return ONLY the JSON object.`;

  try {
    const result = await model.generateContent(prompt);
    const responseText = result.response.text();
    
    // Try to parse JSON
    const parsed = JSON.parse(responseText);
    return res.status(200).json({
      chosen: parsed.chosen,
      confidence: parsed.confidence ?? 0.5,
    });
  } catch (error) {
    console.error("Gemini error:", error);
    return res.status(500).json({ error: error.message });
  }
}
```

### Deploy Proxy Options

1. **Firebase Cloud Functions** (Free tier available):
   - Create `functions/index.js` with the code above
   - Deploy: `firebase deploy --only functions`
   - Get URL: https://REGION-PROJECT.cloudfunctions.net/gemini-proxy
   - Add API key to environment: `firebase functions:config:set gemini.api_key=YOUR_KEY`

2. **Vercel** (Free tier available):
   - Add to `api/gemini-proxy.js`
   - Deploy: `vercel deploy`
   - Create `.env.local`: `GEMINI_API_KEY=YOUR_KEY`
   - Get URL: https://your-project.vercel.app/api/gemini-proxy

3. **Railway or Render** (Free tier available):
   - Similar deployment, URL provided by platform

### Run Flutter App with Proxy

```powershell
flutter run `
  --dart-define=EXTERNAL_AI_URL="https://your-proxy.example.com/api/gemini-proxy" `
  --dart-define=EXTERNAL_AI_KEY="your-proxy-api-key"
```

---

## Option 3: Using Claude (Anthropic) Proxy

Similar to Gemini, create a proxy that calls Claude API:

```javascript
// Example (similar structure to Gemini proxy)
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { text, candidates } = req.body;

  const prompt = `You are an OCR analyzer. Given this slip text and numeric candidates, identify the payment amount.
Return ONLY JSON: {"chosen": <number|null>, "confidence": <0-1>}

Text: ${text}
Candidates: ${candidates.join(", ")}`;

  try {
    const message = await client.messages.create({
      model: "claude-3-5-sonnet-20241022",
      max_tokens: 300,
      messages: [{ role: "user", content: prompt }],
    });

    const responseText = message.content[0].type === "text" ? message.content[0].text : "";
    const parsed = JSON.parse(responseText);
    return res.status(200).json({ chosen: parsed.chosen, confidence: parsed.confidence ?? 0.5 });
  } catch (error) {
    console.error("Claude error:", error);
    return res.status(500).json({ error: error.message });
  }
}
```

---

## Option 4: Using Local LLM (Ollama, LM Studio)

If running a local LLM server (e.g., Ollama on localhost:11434):

Create a simple Node.js/Python proxy and expose it:

```python
# Python example with Ollama
from flask import Flask, request, jsonify
import requests
import json

app = Flask(__name__)

@app.route("/predict", methods=["POST"])
def predict():
    data = request.json
    text = data.get("text", "")
    candidates = data.get("candidates", [])

    prompt = f"""You are an OCR analyzer. Given this slip text and numeric candidates, identify the payment amount.
Return ONLY JSON: {{"chosen": <number|null>, "confidence": <0-1>}}

Text: {text}
Candidates: {", ".join(map(str, candidates))}"""

    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={"model": "mistral", "prompt": prompt, "stream": False},
            timeout=30,
        )
        result = response.json()
        text_response = result.get("response", "")
        parsed = json.loads(text_response)
        return jsonify({"chosen": parsed.get("chosen"), "confidence": parsed.get("confidence", 0.5)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(port=5000)
```

Then run Flutter with:
```powershell
flutter run `
  --dart-define=EXTERNAL_AI_URL="http://localhost:5000/predict" `
  --dart-define=EXTERNAL_AI_KEY="dummy"
```

---

## How the App Uses External AI

When you import a slip (take/select image):

1. **OCR Reading**: App extracts text from image using ML Kit
2. **Candidate Extraction**: App finds all numeric values in text
3. **External AI Call** (if configured):
   - Sends: `{ "text": "<OCR text>", "candidates": [40, 396, 15, ...] }`
   - Receives: `{ "chosen": 396, "confidence": 0.95 }`
4. **Auto-Accept** (if confidence > 0.85):
   - Shows "High Confidence" card with amount + confidence %
   - User can click "Accept & Save" to auto-save transaction
5. **Fallback**: If no external AI configured, uses local device ML classifier

---

## Privacy & Cost Considerations

- **OpenAI**: ~$0.001-0.002 per request (chat completions). Text sent to OpenAI servers.
- **Gemini**: Free tier (50 req/min); paid usage $0.075/1M tokens. Text sent to Google.
- **Claude**: ~$0.003 per request. Text sent to Anthropic.
- **Local LLM**: Free (runs on your hardware). Text stays on your device or local network.

**Recommendation**: Use a proxy server you control and position it as a privacy-preserving middle layer.

---

## Testing

1. Train local classifier first (without external AI):
   - Go to Scan → Sync Album → select 4 images
   - Click "Train" → enter amounts: `40,396.00,15.00,25.00`
   - This trains the device-local model (no external calls)

2. Test with external AI enabled:
   - Run app with `--dart-define` flags above
   - Import a slip → check if "High Confidence" card appears
   - Check logs for any API errors

3. Fallback test:
   - Run without external AI flags → app uses local classifier
   - Should still work (confidence may be lower)

