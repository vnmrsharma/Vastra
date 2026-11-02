# Vastra (Flutter — iOS, Android, Web)

Your AI wardrobe: dress for the day from your own closet, try anything on with YouCam, and keep every look.
One codebase runs on iPhone, Android and the web; the web version looks identical to the mobile app.

Backend: Firebase project `mcurio-main` (Auth, Firestore, Storage) + Cloud Functions in `../vastra/functions`
(YouCam cloth-v4 try-on, Gemini styling/tagging, Weatherstack weather).

## Run on a phone or simulator

```bash
cd vastra_app
flutter pub get
flutter run                 # debug, needs the cable
flutter run --release       # installs a build that keeps working after unplugging
```

## Web version (share a link with anyone)

```bash
flutter build web --release
```

`build/web` is a static site and already contains `vercel.json` (routes every path to the app, allows the camera).
Deploy that folder with Vercel, for example:

```bash
cd build/web && npx vercel --prod
```

- **On a phone:** opens full-screen like the app. On iPhone: Share → *Add to Home Screen* for an app icon.
- **On a laptop:** shows the same phone-sized app in a frame, with a QR code to open it on a phone.

## What a day with Vastra looks like

1. **Sign up → onboarding** (saved as you go, resumes if closed): city (or *Detect my city*) → aesthetic
   (cottagecore, minimal, grunge…), colours, presentation → your week → try-on portrait → snap a few favourites.
2. **Today:** live weather, occasion chips, up to three looks from your closet styled in your aesthetic.
   *Wear today* logs the outfit; Dress me rotates pieces you haven’t worn recently.
3. **Closet:** *Snap clothes* opens an in-app camera — every shot saves instantly and Gemini names and sorts it.
   Wear counts, a *Rarely worn* filter, and tap any piece to edit, try on or remove.
4. **Try on:** a closet piece or any photo; the YouCam garment type is picked automatically.
   Press and hold the result to compare with your original photo.
5. **Dress up:** you (background removed) on a little stage with a *Try a new look* shelf below.
   *Mix & match* tops, bottoms, dresses, layers and shoes, or take a *Styled* look / *Surprise me*;
   *See it on me* layers the whole outfit onto your portrait with chained YouCam try-ons (cached per combo).
   Every closet photo gets its background removed automatically (YouCam), so pieces look clean everywhere.
6. **Recreate a look** (from Today or Closet): snap or upload any outfit; Gemini matches each piece to the
   closest item in your closet (perfect match / close / clever swap / missing) with a score and Pip's tips.
   Wear your version today, try it on, or have YouCam put the original outfit on your portrait.
7. **Looks:** every try-on saved automatically; ♥ your favourites.
8. **You (avatar):** edit name, city, aesthetic, portrait; delete your account and every photo.

## Tests

End-to-end test on the iOS simulator against the live backend (creates and deletes a throwaway account):

```bash
flutter test integration_test/app_flow_test.dart -d <simulator id>                          # includes 1 YouCam try-on (2 units)
flutter test integration_test/app_flow_test.dart -d <simulator id> --dart-define=SKIP_TRYON=true
```

Backend-only smoke test: `cd ../vastra && python3 scripts/smoke_test.py [--skip-tryon]`.

## Pip, the mascot

Pip (a safety pin who holds every outfit together) lives in `lib/widgets/pip.dart`: animated `Pip` poses
(float / bounce / strut, tap for a wiggle and a quip), `PipSays` speech bubbles, `PipSceneCard` illustrations,
`VastraLogo`, and `celebrateWithPip` (confetti overlay).

Optimized Pip art ships in `assets/pip/`. To regenerate cutouts from new source poses:

```bash
cd ../vastra && python3 scripts/pip_cutouts.py        # YouCam AI Background Removal
cd ../vastra_app && flutter test tool/process_pip_test.dart
dart run flutter_launcher_icons && dart run flutter_native_splash:create
```
