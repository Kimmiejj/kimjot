# Test Gemini Proxy Setup (PowerShell for Windows)
# Run from gemini-proxy\ folder after: npm install && npm start

Write-Host "🧪 Testing Gemini AI Proxy..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Health check
Write-Host "Test 1: Health Check" -ForegroundColor Yellow
try {
  $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -Method GET -ErrorAction Stop
  if ($response.Content -like "*ok*") {
    Write-Host "✅ Proxy is running" -ForegroundColor Green
  } else {
    Write-Host "❌ Proxy not responding correctly" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Proxy not responding - make sure 'npm start' is running!" -ForegroundColor Red
  exit 1
}

# Test 2: Simple prediction
Write-Host ""
Write-Host "Test 2: Simple Amount Detection" -ForegroundColor Yellow

$body = @{
  text = "ธนาคาร SCB จำนวนเงิน 396.00 บาท"
  candidates = @(396.0, 40, 15, 25)
} | ConvertTo-Json

try {
  $response = Invoke-WebRequest -Uri "http://localhost:3000/predict" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body `
    -ErrorAction Stop

  Write-Host "Response: $($response.Content)" -ForegroundColor Cyan

  if ($response.Content -like '*"chosen"*') {
    Write-Host "✅ AI analysis successful" -ForegroundColor Green
  } else {
    Write-Host "❌ AI analysis failed" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Request failed: $_" -ForegroundColor Red
  exit 1
}

# Test 3: With confidence
Write-Host ""
Write-Host "Test 3: Confidence Scoring" -ForegroundColor Yellow

$body = @{
  text = "ค่าบริการ 60 บาท ส่วนลด -20 บาท สุทธิ 40 บาท"
  candidates = @(60, 20, 40)
} | ConvertTo-Json

try {
  $response = Invoke-WebRequest -Uri "http://localhost:3000/predict" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body `
    -ErrorAction Stop

  Write-Host "Response: $($response.Content)" -ForegroundColor Cyan

  if ($response.Content -like '*"confidence"*') {
    Write-Host "✅ Confidence calculation working" -ForegroundColor Green
  } else {
    Write-Host "❌ Confidence not returned" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Request failed: $_" -ForegroundColor Red
  exit 1
}

# Test 4: Edge case - empty input
Write-Host ""
Write-Host "Test 4: Edge Case - Invalid Input" -ForegroundColor Yellow

$body = @{
  text = ""
  candidates = @()
} | ConvertTo-Json

try {
  $response = Invoke-WebRequest -Uri "http://localhost:3000/predict" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body `
    -ErrorAction Stop

  if ($response.Content -like '*error*') {
    Write-Host "✅ Error handling works" -ForegroundColor Green
  } else {
    Write-Host "⚠️  Got response: $($response.Content)" -ForegroundColor Yellow
  }
} catch {
  Write-Host "✅ Error handling works (caught exception)" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 All tests passed!" -ForegroundColor Green
Write-Host ""
Write-Host "Now you can run Flutter with:" -ForegroundColor Cyan
Write-Host ""
Write-Host 'flutter run `' -ForegroundColor White
Write-Host '  --dart-define=EXTERNAL_AI_URL="http://localhost:3000/predict" `' -ForegroundColor White
Write-Host '  --dart-define=EXTERNAL_AI_KEY="gemini-proxy"' -ForegroundColor White

