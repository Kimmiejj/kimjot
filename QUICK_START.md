# ⚡ QUICK START GUIDE (5 Minutes)

## 🎯 Goal
Run Flutter app with Gemini AI analyzing slip amounts automatically.

---

## 🚀 Step 1: Start Gemini Proxy (2 minutes)

### Option A: Windows PowerShell

Open PowerShell and navigate to the proxy folder:
```powershell
cd "C:\Users\ChisanuchaK\OneDrive\Desktop\New folder\kimjod\gemini-proxy"
npm install
npm start
```

You should see:
```
✅ Gemini AI Proxy running on http://localhost:3000
```

**Keep this terminal open!** (It's running the proxy server)

---

## 📱 Step 2: Run Flutter App (Open NEW terminal/tab)

```powershell
cd "C:\Users\ChisanuchaK\OneDrive\Desktop\New folder\kimjod"
flutter run `
  --dart-define=EXTERNAL_AI_URL="http://localhost:3000/predict" `
  --dart-define=EXTERNAL_AI_KEY="gemini-proxy"
```

---

## ✨ Step 3: Test It!

1. **In the Flutter app** → tap **Scan** → **Import from gallery**
2. **Select a slip image** (e.g., one of your 4 training images)
3. **Wait for OCR** → you'll see the slip summary
4. **Check for "High Confidence" card** (if AI detected amount with > 85% confidence)
5. **Tap "ยอมรับ & บันทึก"** to auto-save, or review/edit manually

---

## ✅ Verify It's Working

In **another** PowerShell terminal, test the proxy:

```powershell
$body = @{
    text = "ธนาคาร SCB จำนวนเงิน 396.00 บาท"
    candidates = @(396.0, 40, 15, 25)
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:3000/predict" `
  -Method POST `
  -ContentType "application/json" `
  -Body $body
```

Expected output:
```json
{"chosen": 396.0, "confidence": 0.95}
```

---

## 🎓 Train Local AI (Optional)

Before using external AI, train the device-local classifier:

1. **Scan** → **Sync Album** → select folder with 4 slip images
2. **Click "ฝึก" button** → enter: `40,396.00,15.00,25.00`
3. **Wait** → system trains and saves weights to device

This improves accuracy over time!

---

## 🚀 Deploy to Cloud (When Ready)

Skip for now if testing locally. When you want to share/deploy:

### Vercel (Easiest)
```bash
cd gemini-proxy
npm install -g vercel
vercel
# Follow prompts → get URL like https://gemini-proxy-xyz.vercel.app
```

Then update Flutter command:
```powershell
flutter run `
  --dart-define=EXTERNAL_AI_URL="https://gemini-proxy-xyz.vercel.app/predict" `
  --dart-define=EXTERNAL_AI_KEY="your-secret"
```

See `README.md` for other platforms (Railway, Render, Firebase).

---

## 🐛 Troubleshooting

### "npm not found"
- Install Node.js from https://nodejs.org/
- Restart PowerShell after installing

### "Connection refused"
- Make sure proxy terminal is still running (`npm start`)
- Check URL is exactly `http://localhost:3000/predict`

### "AI not showing confidence"
- Check proxy logs for errors
- Try with a clearer slip image
- Make sure flutter app terminal shows no errors

---

## 📋 Summary

| What | Where | Status |
|------|-------|--------|
| Local AI Classifier | Device memory (trained) | ✅ Ready |
| Gemini Proxy | `gemini-proxy/` folder | ✅ Ready |
| API Key | In `.env` file | ✅ Ready |
| Flutter App | `lib/` folder | ✅ Ready |

---

## 🎉 That's It!

Your app now has:
- ✅ Local ML classifier (trained on your slips)
- ✅ Gemini AI analyzing amounts (with confidence)
- ✅ Auto-accept for confident predictions (> 85%)
- ✅ Manual review fallback
- ✅ Reset/manage AI in Settings

Enjoy! 🚀

