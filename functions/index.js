/**
 * RentGo payment functions (Konnect — https://docs.konnect.network).
 *
 * Setup:
 *   firebase functions:secrets:set KONNECT_API_KEY
 *   firebase functions:secrets:set KONNECT_WALLET_ID
 *   firebase deploy --only functions
 *
 * Switch KONNECT_BASE to https://api.konnect.network/api/v2 for production.
 */
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

admin.initializeApp();

const KONNECT_API_KEY = defineSecret("KONNECT_API_KEY");
const KONNECT_WALLET_ID = defineSecret("KONNECT_WALLET_ID");
const KONNECT_BASE = "https://api.sandbox.konnect.network/api/v2";

/**
 * Sends a push notification whenever a document is written to /notifications.
 * The FCM token is stored at /users/{uid}.fcmToken by the Flutter app on login.
 */
exports.pushOnNotification = onDocumentCreated(
  { document: "notifications/{id}", region: "europe-west1" },
  async (event) => {
    const { userId, title, body } = event.data.data();
    if (!userId || !title) return;

    const userSnap = await admin.firestore().collection("users").doc(userId).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) return;

    try {
      await admin.messaging().send({
        token,
        notification: { title, body: body ?? "" },
        android: {
          notification: {
            channelId: "rentgo_default",
            priority: "high",
            sound: "default",
          },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });
    } catch (err) {
      // Token may be stale (app uninstalled) — log and continue.
      console.warn("FCM send failed for user", userId, err.code);
    }
  }
);

/**
 * Called by the app to start a payment. Amounts are validated against the
 * booking document so the client cannot pay less than what is due.
 * Returns { payUrl, paymentRef }.
 */
exports.initKonnectPayment = onCall(
  { secrets: [KONNECT_API_KEY, KONNECT_WALLET_ID], region: "europe-west1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }
    const { bookingId, isExtraCharge } = request.data;
    if (typeof bookingId !== "string") {
      throw new HttpsError("invalid-argument", "bookingId is required.");
    }

    const bookingRef = admin.firestore().collection("bookings").doc(bookingId);
    const snap = await bookingRef.get();
    if (!snap.exists) throw new HttpsError("not-found", "Booking not found.");
    const booking = snap.data();

    if (booking.renterId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Only the renter can pay.");
    }
    const expectedStatus = isExtraCharge ? "returned" : "accepted";
    if (booking.status !== expectedStatus) {
      throw new HttpsError("failed-precondition", `Booking is not ${expectedStatus}.`);
    }
    const amountTnd = isExtraCharge ? booking.extraKmCharge : booking.basePrice;
    const amountMillimes = Math.round(amountTnd * 1000);
    if (amountMillimes <= 0) {
      throw new HttpsError("failed-precondition", "Nothing to pay.");
    }

    const res = await fetch(`${KONNECT_BASE}/payments/init-payment`, {
      method: "POST",
      headers: {
        "x-api-key": KONNECT_API_KEY.value(),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        receiverWalletId: KONNECT_WALLET_ID.value(),
        token: "TND",
        amount: amountMillimes,
        type: "immediate",
        description: `RentGo booking ${bookingId}${isExtraCharge ? " (extra km)" : ""}`,
        acceptedPaymentMethods: ["bank_card", "e-DINAR", "wallet"],
        lifespan: 30,
        webhook: `https://europe-west1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/konnectWebhook`,
      }),
    });
    if (!res.ok) {
      console.error("Konnect init failed", res.status, await res.text());
      throw new HttpsError("internal", "Payment initialization failed.");
    }
    const data = await res.json();

    // Remember which booking this payment belongs to, for the webhook.
    await bookingRef.update({
      pendingPaymentRef: data.paymentRef,
      pendingIsExtra: !!isExtraCharge,
    });

    return { payUrl: data.payUrl, paymentRef: data.paymentRef };
  }
);

/**
 * Konnect calls this with ?payment_ref=... when a payment changes state.
 * We verify the payment server-side, then move the booking forward.
 */
exports.konnectWebhook = onRequest(
  { secrets: [KONNECT_API_KEY], region: "europe-west1" },
  async (req, res) => {
    const paymentRef = req.query.payment_ref;
    if (!paymentRef) {
      res.status(400).send("Missing payment_ref");
      return;
    }

    const verify = await fetch(`${KONNECT_BASE}/payments/${paymentRef}`, {
      headers: { "x-api-key": KONNECT_API_KEY.value() },
    });
    if (!verify.ok) {
      res.status(502).send("Could not verify payment");
      return;
    }
    const { payment } = await verify.json();
    if (payment.status !== "completed") {
      res.status(200).send("Payment not completed yet");
      return;
    }

    const bookings = await admin
      .firestore()
      .collection("bookings")
      .where("pendingPaymentRef", "==", paymentRef)
      .limit(1)
      .get();
    if (bookings.empty) {
      res.status(404).send("No booking for this payment");
      return;
    }

    const doc = bookings.docs[0];
    const isExtra = doc.data().pendingIsExtra === true;
    await doc.ref.update(
      isExtra
        ? { status: "completed", extraPaymentRef: paymentRef, pendingPaymentRef: null }
        : { status: "paid", paymentRef: paymentRef, pendingPaymentRef: null }
    );
    res.status(200).send("OK");
  }
);
