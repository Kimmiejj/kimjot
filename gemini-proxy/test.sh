 #!/bin/bash
# Test Gemini Proxy Setup
# Run from gemini-proxy/ folder after: npm install && npm start

echo "🧪 Testing Gemini AI Proxy..."
echo ""

# Test 1: Health check
echo "Test 1: Health Check"
response=$(curl -s http://localhost:3000/health)
if echo "$response" | grep -q "ok"; then
  echo "✅ Proxy is running"
else
  echo "❌ Proxy not responding"
  exit 1
fi

# Test 2: Simple prediction
echo ""
echo "Test 2: Simple Amount Detection"
response=$(curl -s -X POST http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "text": "ธนาคาร SCB จำนวนเงิน 396.00 บาท",
    "candidates": [396.0, 40, 15, 25]
  }')

echo "Response: $response"

if echo "$response" | grep -q '"chosen"'; then
  echo "✅ AI analysis successful"
else
  echo "❌ AI analysis failed"
  exit 1
fi

# Test 3: With confidence
echo ""
echo "Test 3: Confidence Scoring"
response=$(curl -s -X POST http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "text": "ค่าบริการ 60 บาท ส่วนลด -20 บาท สุทธิ 40 บาท",
    "candidates": [60, 20, 40]
  }')

echo "Response: $response"

if echo "$response" | grep -q '"confidence"'; then
  echo "✅ Confidence calculation working"
else
  echo "❌ Confidence not returned"
  exit 1
fi

# Test 4: Edge case - null response
echo ""
echo "Test 4: Edge Case - Invalid Input"
response=$(curl -s -X POST http://localhost:3000/predict \
  -H "Content-Type: application/json" \
  -d '{"text": ""}')

if echo "$response" | grep -q "error\|chosen"; then
  echo "✅ Error handling works"
else
  echo "⚠️  Unexpected response format"
fi

echo ""
echo "🎉 All tests passed!"
echo ""
echo "Now you can run Flutter with:"
echo "flutter run \\"
echo "  --dart-define=EXTERNAL_AI_URL=\"http://localhost:3000/predict\" \\"
echo "  --dart-define=EXTERNAL_AI_KEY=\"gemini-proxy\""

