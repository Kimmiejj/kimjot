# Gemini AI Proxy Setup & Flutter Integration

This folder contains a Node.js proxy server that connects your Flutter app to Google Gemini AI for slip amount analysis.

## 🚀 Quick Start (Local)

### Prerequisites
- Node.js 14+ installed (download from https://nodejs.org/)
- API Key: `AQ.Ab8RN6LDKT5AFuLKAQtBI8MCg0zfS0g9ghjXxftMnsDrtwsQlw` (already in `.env`)

### Run Locally

1. **Open Terminal in this folder** (`gemini-proxy/`)

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Start the proxy server**:
   ```bash
   npm start
   ```

   You should see:
   ```
   ✅ Gemini AI Proxy running on http://localhost:3000
   📝 POST /predict - Analyze slip amounts
   💓 GET /health - Health check
   🔑 Using API Key: AQ.Ab8RN6LDK...
   ```

4. **Test it works** (in another terminal):
   ```bash
   curl -X POST http://localhost:3000/predict \
     -H "Content-Type: application/json" \
     -d '{
       "text": "ธนาคาร SCB จำนวนเงิน 396.00 บาท",
       "candidates": [396.0, 40, 15, 25]
     }'
   ```

   Expected response:
   ```json
   {"chosen": 396.0, "confidence": 0.95}
   ```

---

## 🎯 Use with Flutter App

### Option 1: Local Testing (Development)

**Terminal 1 - Run proxy:**
```bash
cd gemini-proxy
npm start
```

**Terminal 2 - Run Flutter app:**
```bash
cd .. (back to kimjod root)
flutter run \
  --dart-define=EXTERNAL_AI_URL="http://localhost:3000/predict" \
  --dart-define=EXTERNAL_AI_KEY="dummy-key"
```

### Option 2: Deploy to Production

Choose one platform below:

---

### **Deploy Option A: Vercel (Easiest)**

1. **Create Vercel account**: https://vercel.com/signup

2. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

3. **Deploy from `gemini-proxy/` folder**:
   ```bash
   cd gemini-proxy
   vercel
   ```

4. **Follow prompts** (select `Node.js`, use default settings)

5. **Set environment variable**:
   - Go to Vercel dashboard → Project → Settings → Environment Variables
   - Add: `GEMINI_API_KEY` = `AQ.Ab8RN6LDKT5AFuLKAQtBI8MCg0zfS0g9ghjXxftMnsDrtwsQlw`
   - Redeploy

6. **Get your URL**:
   - You'll get something like: `https://gemini-proxy-xyz.vercel.app`

7. **Run Flutter with your Vercel URL**:
   ```bash
   flutter run \
     --dart-define=EXTERNAL_AI_URL="https://gemini-proxy-xyz.vercel.app/predict" \
     --dart-define=EXTERNAL_AI_KEY="your-secret-key"
   ```

---

### **Deploy Option B: Railway**

1. **Create Railway account**: https://railway.app

2. **Connect your GitHub** (or upload this folder as a repo)

3. **Create new project** → Import repo → Select `gemini-proxy` folder

4. **Add environment variable**:
   - `GEMINI_API_KEY` = `AQ.Ab8RN6LDKT5AFuLKAQtBI8MCg0zfS0g9ghjXxftMnsDrtwsQlw`

5. **Deploy** (Railway auto-deploys on push)

6. **Get public URL** from Railway dashboard

---

### **Deploy Option C: Render**

1. **Create Render account**: https://render.com

2. **Create "New Web Service"**

3. **Connect GitHub repo** (containing `gemini-proxy/`)

4. **Configure**:
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Add environment: `GEMINI_API_KEY=AQ.Ab8RN6LDKT5AFuLKAQtBI8MCg0zfS0g9ghjXxftMnsDrtwsQlw`

5. **Deploy** and get your URL

---

### **Deploy Option D: Firebase Cloud Functions**

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Create `functions/index.js`** (convert server.js):
   ```javascript
   const functions = require("firebase-functions");
   const express = require("express");
   const axios = require("axios");

   const app = express();
   app.use(express.json());

   app.post("/predict", async (req, res) => {
     // ... (use same logic as server.js)
   });

   exports.predict = functions.https.onRequest(app);
   ```

3. **Deploy**:
   ```bash
   firebase deploy --only functions
   ```

4. **Get URL** from Firebase console

---

## 📲 Flutter App Configuration

### Step 1: Update Flutter App Settings

**In your Flutter app, you can:**

**Option A - Run with environment variables** (recommended):
```powershell
flutter run `
  --dart-define=EXTERNAL_AI_URL="https://your-deployed-url.com/predict" `
  --dart-define=EXTERNAL_AI_KEY="your-secret-key"
```

**Option B - Hard-code in app** (for testing only):
Edit `lib/features/scan/external_ai_client.dart`:
```dart
final _url = "https://your-deployed-url.com/predict";
final _key = "your-secret-key";
```

### Step 2: Test the Integration

1. **Open app** → go to `Scan` → `Import from gallery`
2. **Select a slip image**
3. **Wait for analysis** → should show "High Confidence" card if AI confident (> 85%)
4. **Check logs** for any errors

---

## 🐛 Troubleshooting

### **Error: "Failed to connect to proxy"**
- Make sure proxy is running (`npm start` in terminal)
- Check URL is correct (http vs https, localhost vs deployed)
- Ensure firewall isn't blocking port 3000

### **Error: "Invalid API key"**
- Check `.env` file has correct key
- Regenerate key from https://aistudio.google.com/apikey

### **Error: "JSON parsing failed"**
- Gemini response format changed
- Update prompt in `server.js` to match new format

### **Proxy returns null/low confidence**
- Try with clearer slip images
- Check OCR text is complete (not cropped/blurry)

---

## 📊 Monitoring

### Check proxy health:
```bash
curl http://localhost:3000/health
# or
curl https://your-deployed-url.com/health
```

### View logs (deployed):
- **Vercel**: Dashboard → Function logs
- **Railway**: Deployments tab → View logs
- **Render**: Logs section

---

## 💡 How It Works

1. **Flutter App** extracts OCR text + numeric candidates from slip image
2. **App sends** `POST /predict` with `{"text": "...", "candidates": [...]}`
3. **Proxy server** calls Google Gemini API with structured prompt
4. **Gemini** analyzes and returns `{"chosen": 396.0, "confidence": 0.95}`
5. **Proxy returns** to Flutter app
6. **App displays** "High Confidence" card if confidence > 85%
7. **User** can auto-save or manually review

---

## 🔐 Security Notes

- API key is server-side only (not exposed in Flutter app)
- Proxy can add rate limiting, IP whitelist, etc.
- Consider adding authentication if deploying publicly
- Monitor API usage to avoid unexpected costs

---

## 📞 Support

- **Gemini API docs**: https://ai.google.dev/docs
- **Flutter docs**: https://flutter.dev/docs
- **Proxy errors**: Check server.js logs for details

---

## ✅ Checklist Before Production

- [ ] Proxy deployed to stable hosting
- [ ] API key stored in environment (not hardcoded)
- [ ] Flutter app configured with correct proxy URL
- [ ] Tested with real slip images
- [ ] Confidence threshold adjusted (currently 0.85)
- [ ] Error handling in place (fallback to local AI)
- [ ] Rate limiting configured (if needed)
- [ ] Monitoring/logging enabled

