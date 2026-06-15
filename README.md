# RentGo

Peer-to-peer vehicle rental app (cars, motorcycles, scooters, vans) for Tunisia.
Flutter + Firebase + Riverpod, payments via Konnect.

## How it works

- Anyone can **list a vehicle** with a daily price, an included-km-per-day
  allowance, and a price per extra km.
- Renters must complete **identity verification** (CIN number + photos of the
  ID card and driving licence) before they can book.
- **Booking lifecycle:**
  `pending → accepted → paid → ongoing → returned → completed`
  - The owner accepts the request, then the renter pays the base price
    (days × daily price) with Konnect.
  - At pickup the owner records the odometer (`ongoing`).
  - At return the owner records the odometer again; kilometres beyond the
    allowance are billed at the listed extra-km price. The booking completes
    when the extra charge is paid (or immediately if nothing extra is due).

## Setup

1. **Create a Firebase project** at <https://console.firebase.google.com>, then:

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure        # generates lib/firebase_options.dart
   ```

2. **Enable products** in the Firebase console:
   - Authentication → Email/Password
   - Cloud Firestore (deploy rules + indexes)

   ```powershell
   firebase deploy --only firestore
   ```

   Photos (vehicle pictures, KYC documents) are stored as compressed base64
   data URIs inside Firestore documents, so **Firebase Storage is not
   required** and the app runs fully on the free Spark plan. Images are
   picked at reduced size (max width 900 px, quality 50) and capped at
   200 KB each / 3 photos per vehicle to respect Firestore's 1 MiB document
   limit. If the app outgrows this, swap `ImageService` for a real object
   store (Firebase Storage, Supabase, Cloudinary) — display code already
   handles both data URIs and network URLs via the `AppImage` widget.

3. **Run the app** (payments are mocked by default so the full flow works
   without any payment setup):

   ```powershell
   flutter run
   ```

## Real payments (Konnect)

1. Create an account at <https://konnect.network> and get an API key + wallet ID.
2. Deploy the functions:

   ```powershell
   cd functions
   npm install
   firebase functions:secrets:set KONNECT_API_KEY
   firebase functions:secrets:set KONNECT_WALLET_ID
   firebase deploy --only functions
   ```

3. Run the app with mock payments off:

   ```powershell
   flutter run --dart-define=MOCK_PAYMENTS=false
   ```

`functions/index.js` uses the Konnect **sandbox** URL — switch `KONNECT_BASE`
to `https://api.konnect.network/api/v2` for production.

## KYC review

Documents are stored on the user document in Firestore (`idCardImageUrl` /
`licenseImageUrl` as base64 data URIs) and the account is marked
`kycStatus: pending`. Review them and set `kycStatus: "verified"` on the user
document from the Firebase console (security rules prevent users from
verifying themselves).

## Tests

```powershell
flutter test
```
