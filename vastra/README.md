# Vastra

AI digital wardrobe & virtual styling. YouCam try-on is the core moment.

**Stack:** Next.js (Vercel, manual) · Firebase Auth / Firestore / Storage / Cloud Functions · Gemini · Weatherstack · Perfect Corp YouCam

## Quick start

```bash
cd vastra
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

`.env.local` should include Firebase client config, API keys (server-only), and:

```
NEXT_PUBLIC_FUNCTIONS_URL=https://europe-west1-mcurio-main.cloudfunctions.net
```

Restart `npm run dev` after changing any `NEXT_PUBLIC_*` value.

## Deployed Cloud Functions (europe-west1)

| Function | URL |
|----------|-----|
| health | `/health` |
| getWeather | `/getWeather` |
| startTryOn | `/startTryOn` |
| pollTryOn | `/pollTryOn` |
| dressMeToday | `/dressMeToday` |
| analyzeInspiration | `/analyzeInspiration` |

Secrets in Secret Manager: `YOUCAM_API_KEY`, `GEMINI_API_KEY`, `WEATHERSTACK_API_KEY`

Redeploy:

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions --force
```

## Working product flows

1. **Sign up / sign in** (email + password)
2. **Onboarding** — city + try-on photo
3. **Closet** — upload, live sync, filter, delete
4. **Dress me today** — occasion + Weatherstack + Gemini suggestions from closet
5. **Inspiration Studio** — Gemini vision components + closet match status
6. **Virtual Try-On** — real YouCam cloth-v4 (incl. full_body), poll, persist result, save look
7. **Saved Looks** — synced try-on results

## Firebase Console checklist

- Auth → Email/Password enabled
- Firestore + Storage rules deployed
- Billing/Blaze for Functions (already required for deploy)
