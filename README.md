# Vastra

Cher's *Clueless* closet, made real. Vastra is an AI digital wardrobe and personal stylist — photograph the clothes you already own, get outfits for your day, mix and match on a Snap-style stage, recreate any look from your closet, and try it all on with **YouCam** virtual try-on.

**Live demo:** [https://vastra-sigma-pearl.vercel.app](https://vastra-sigma-pearl.vercel.app)

**Demo login (for judges):** `maya.demo@vastra-demo.dev` / `VastraDemo!2026`

Devpost screenshots live in [`devpost-screenshots/`](devpost-screenshots/).

## What's in this repo

| Path | What it is |
|------|------------|
| `vastra_app/` | Flutter app (iOS, Android, Web) — the product judges use |
| `vastra/` | Next.js shell + Firebase Cloud Functions (YouCam, Gemini, weather) |
| `vastra/functions/` | Backend: try-on, dress-up, cutouts, Today looks, recreate |
| `devpost-screenshots/` | Submission gallery (01–38) |

## Stack

- **Flutter** — one UI for phone and web
- **Firebase** — Auth, Firestore, Storage, Cloud Functions (europe-west1)
- **YouCam** — `cloth-v4` virtual try-on + SOD background removal
- **Gemini 2.5 Flash** — garment tagging, Today styling, recreate matching
- **Vercel** — hosts the Flutter web build

## Run locally

### Backend / functions

```bash
cd vastra
cp .env.example .env.local   # fill Firebase client + leave API keys for Functions secrets
npm install
cd functions && npm install && npm run build
```

Secrets (`YOUCAM_API_KEY`, `GEMINI_API_KEY`, `WEATHERSTACK_API_KEY`) live in Firebase Secret Manager — never in the client.

### Flutter app

```bash
cd vastra_app
flutter pub get
flutter run                 # device / simulator
flutter build web --release # static site in build/web
```

## Features

1. **Today** — weather + occasion looks from your own closet  
2. **Closet** — snap pieces; Gemini tags them; backgrounds removed  
3. **Dress up** — mix & match or styled outfits on your portrait  
4. **Try on** — YouCam single-garment try-on with before/after  
5. **Recreate a look** — upload any outfit photo; match it from what you own  
6. **Looks** — saved try-ons and favourites  

Built for the YouCam × Perfect Corp hackathon.
