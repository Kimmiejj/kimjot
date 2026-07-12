# ✅ SETUP VERIFICATION CHECKLIST

Before you start, verify everything is in place:

## 🔍 Check 1: Project Structure

```powershell
# Navigate to your project root
cd "C:\Users\ChisanuchaK\OneDrive\Desktop\New folder\kimjod"

# Verify key files exist
Test-Path "pubspec.yaml"                    # Should be TRUE
Test-Path "lib\features\scan\slip_amount_classifier.dart"  # Should be TRUE
Test-Path "lib\features\scan\external_ai_client.dart"       # Should be TRUE
Test-Path "gemini-proxy\server.js"          # Should be TRUE
Test-Path "gemini-proxy\.env"               # Should be TRUE
```

If all show TRUE, continue. If any are FALSE, contact support.

---

## 🔍 Check 2: Flutter & Dependencies

```powershell
# Check Flutter version
flutter --version
# Should show: Flutter 3.x or higher

# Get dependencies
flutter pub get
# Should complete without errors

# Check for build errors
flutter analyze
# Should show: "... issues found" (mostly warnings, no hard errors)
```

---

## 🔍 Check 3: Node.js & Proxy

```powershell
# Check Node.js installed
node --version
# Should show: v14.x or higher

# Check npm installed
npm --version
# Should show: 6.x or higher

# Navigate to proxy folder
cd gemini-proxy

# Install dependencies
npm install
# Should complete, create node_modules/ folder

# Verify .env exists
Test-Path ".env"
# Should be TRUE

# Check .env content
Get-Content ".env"
# Should contain: GEMINI_API_KEY=AQ.Ab8RN6LDKT5AFuLKAQtBI8MCg0zfS0g9ghjXxftMnsDrtwsQlw
```

---

## 🔍 Check 4: Files to Read

Before running, skim these documentation files:

```
✅ Read:  QUICK_START.md              (5 min intro)
✅ Read:  SYSTEM_OVERVIEW.md          (understand architecture)
✅ Skim:  EXTERNAL_AI_SETUP.md        (deployment options)
✅ Skim:  gemini-proxy/README.md      (proxy details)
```

---

## 🚀 Ready to Run?

### Terminal 1: Start the proxy

```powershell
cd "C:\Users\ChisanuchaK\OneDrive\Desktop\New folder\kimjod\gemini-proxy"
npm start
```

Expected output:
```
✅ Gemini AI Proxy running on http://localhost:3000
📝 POST /predict - Analyze slip amounts
💓 GET /health - Health check
🔑 Using API Key: AQ.Ab8RN6LDK...
```

✅ **Keep this terminal open!**

---

### Terminal 2: Test the proxy (optional)

```powershell
# In a NEW PowerShell window, navigate to gemini-proxy
cd "C:\Users\ChisanuchaK\OneDrive\Desktop\New folder\kimjod\gemini-proxy"

# Run tests
.\test.ps1
```

Expected: All tests pass ✅

---

### Terminal 3: Run Flutter app

```powershell
# In another NEW terminal
cd "C:\Users\ChisanuchaK\OneDrive\Desktop\New folder\kimjod"

# Run with Gemini AI enabled
flutter run `
  --dart-define=EXTERNAL_AI_URL="http://localhost:3000/predict" `
  --dart-define=EXTERNAL_AI_KEY="gemini-proxy"
```

Expected:
- Flutter compiles successfully
- App opens on emulator/device
- "Hot reload" works (r to reload)

---

## 🧪 Sanity Checks

### Check 1: Proxy responds

```powershell
# In any terminal, run:
curl http://localhost:3000/health
# or
Invoke-WebRequest http://localhost:3000/health

# Expected: {"status": "ok"}
```

### Check 2: AI analyzes

```powershell
$body = @{
  text = "amount 396 baht"
  candidates = @(396, 40, 15)
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:3000/predict `
  -Method POST `
  -ContentType application/json `
  -Body $body

# Expected: {"chosen": 396.0, "confidence": 0.x}
```

### Check 3: Flutter connects

- Open app → Scan → Import from gallery
- Select a slip image
- Wait ~2 seconds for OCR + AI analysis
- Check if "High Confidence" card appears (if confidence > 85%)
- Check app logs for any "connection refused" errors

---

## ❌ If Something Goes Wrong

| Problem | Solution |
|---------|----------|
| `npm: command not found` | Install Node.js from https://nodejs.org/ |
| `Cannot GET /predict` | Make sure `npm start` is running in Terminal 1 |
| `[ERR] Port 3000 in use` | Kill existing process: `lsof -ti:3000` then `kill -9 <pid>` |
| Flutter won't connect | Check EXTERNAL_AI_URL is exactly `http://localhost:3000/predict` |
| "Invalid API key" | Verify .env file has correct key starting with `AQ.` |
| App crashes on import | Check logs in Flutter terminal for full error message |

---

## 📞 Need Help?

1. **Check logs** - Both proxy terminal and Flutter terminal show detailed errors
2. **Verify URLs** - Copy-paste exact URLs, watch for typos
3. **Restart everything** - Kill terminals and start fresh often fixes issues
4. **Network issues** - Make sure no firewall is blocking port 3000

---

## ✨ Success Indicators

You'll know it's working when:

✅ Proxy terminal shows:
```
✅ Gemini AI Proxy running on http://localhost:3000
```

✅ Flutter app opens and doesn't crash

✅ When you import a slip image:
- OCR text appears
- Amount is detected
- Confidence > 85% → "High Confidence" card shows

✅ You can click "ยอมรับ & บันทึก" and transaction saves

✅ Settings page shows "AI Model" with Reset button

---

## 🎉 You're Good to Go!

All systems operational. Proceed with QUICK_START.md in 5 minutes!

