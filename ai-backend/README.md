# Kimjod AI backend

Vercel-hosted Gemini backend for the Kimjod Android app. It keeps the Gemini
credential off the phone, verifies Firebase ID tokens, applies a daily quota,
caches financial analysis, and returns every AI result to the Kimjod UI.

## Required environment variables

- `GEMINI_API_KEY`: a server-only Gemini API key. Rotate any key that has been
  pasted into a chat or committed anywhere before using it here.
- `gemini_key`: supported as a compatibility fallback for the existing Vercel
  project; new deployments should prefer `GEMINI_API_KEY`.
- `GEMINI_MODEL_POOL`: optional comma-separated routing pool. The default uses
  `gemini-3.1-flash-lite`, `gemini-3.5-flash`, `gemini-2.5-flash-lite`, and
  `gemini-2.5-flash`. Models that time out or return 429/5xx enter a temporary
  cooldown while requests continue through the remaining pool.
- `GEMINI_MODEL` and `GEMINI_FALLBACK_MODEL`: optional compatibility values;
  when present they are prepended to the routing pool.
- `FIREBASE_PROJECT_ID`: Firebase project ID; defaults to `kimjot`. This is
  enough to verify signed-in users for the mobile AI routes.
- `FIREBASE_SERVICE_ACCOUNT_JSON`: optional complete service-account JSON. Add
  it only if persistent quota/caching and the read-only MCP summary are needed.
- `AI_ALLOWED_EMAILS`: comma-separated Firebase emails allowed to use AI;
  set to `kim59153@gmail.com` for this private deployment.
- `AI_DAILY_LIMIT`: optional; defaults to `300` authenticated requests/user/day.
  Set it to `0` to disable the app-level cap; Gemini's own project quotas still
  apply and are handled by the dynamic model pool.
- `RECOVERY_ESCROW_MASTER_KEY`: server-only 32-byte key encoded as base64 or
  64 hexadecimal characters. It encrypts recovery keys with AES-256-GCM before
  Firestore storage. Generate it once, back it up outside the repository, and
  do not rotate it without first migrating existing escrow records.
- `RESEND_API_KEY`: server-only Resend API key used only by the recovery-email
  route.
- `RECOVERY_FROM_EMAIL`: sender on a Resend-verified domain, for example
  `Kimjod <recovery@your-domain.example>`.

The default `onboarding@resend.dev` sender is test-only and can deliver only to
the email address that owns the Resend account. Production recovery email must
use a verified custom domain in `RECOVERY_FROM_EMAIL`.

Recovery routes require the three recovery variables above. They use the
signed-in user's Firebase token for narrowly scoped Firestore REST access, so
they do not require a long-lived Firebase Admin private key. Firestore stores
only AES-GCM ciphertext; `RECOVERY_ESCROW_MASTER_KEY` stays on the backend.
The routes accept any Firebase-authenticated user whose token contains a
verified email; `AI_ALLOWED_EMAILS` remains scoped to AI routes.

Generate a suitable escrow master key with:

```powershell
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
```

The app uses `https://kimjot.vercel.app` automatically. `AI_BACKEND_URL` is a
non-secret Flutter `--dart-define` override for development or a different
deployment; end users never need to enter a URL.

`RECOVERY_BACKEND_URL` is the equivalent non-secret Flutter `--dart-define`
override for recovery-key escrow and email requests. It defaults to the same
production origin.

Never put secret values in `vercel.json`, source files, Flutter dart-defines,
or the repository.

## Local verification

```powershell
npm install
npm run check
npm start
```

To test against a different backend, override the production origin when
running Flutter:

```powershell
flutter run --dart-define=AI_BACKEND_URL=https://your-kimjod-ai.vercel.app
```

The `/mcp` endpoint is intentionally read-only. It supports initialization,
tool discovery, `get_financial_summary`, and `draft_transaction`. Kimjod's
mobile AI features use the authenticated `/v1/*` routes and Gemini.
