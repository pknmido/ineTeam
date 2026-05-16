const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK to interact with FCM and other services
admin.initializeApp();

/**
 * Cloud Function: sendPushNotification
 * Type: Callable (Modern v2 Syntax)
 * 
 * Securely sends a push notification to a specific device token.
 * By using a Cloud Function, we avoid exposing sensitive FCM Server Keys 
 * or OAuth tokens inside the mobile app.
 */
exports.sendPushNotification = onCall(async (request) => {
  // Extract data from the request
  const { targetToken, title, body, data } = request.data;

  // 1. Basic validation of required fields
  if (!targetToken || !title || !body) {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with 'targetToken', 'title', and 'body'."
    );
  }

  // 2. Optional: Authentication check
  // Ensure only logged-in users can trigger notifications
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  try {
    // 3. Construct the message payload (Modern FCM HTTP v1 format)
    const message = {
      token: targetToken,
      notification: {
        title: title,
        body: body,
      },
      data: formattedData, 
      android: {
        // CRUCIAL: Must be uppercase "HIGH" for HTTP v1 API
        priority: "HIGH", 
        notification: {
          channelId: "high_importance_channel",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        headers: {
          // CRUCIAL FOR iOS: 10 means immediate delivery, 5 means background/low power
          "apns-priority": "10", 
        },
        payload: {
          aps: {
            contentAvailable: true,
            badge: 1,
            sound: "default",
          },
        },
      },
    };

    // 4. Send the message via the Admin SDK
    const response = await admin.messaging().send(message);
    
    console.log(`Successfully sent message to ${targetToken}:`, response);
    
    return {
      success: true,
      messageId: response,
    };
  } catch (error) {
    console.error("Error sending push notification:", error);
    
    // Throw a structured error back to the Flutter client
    throw new HttpsError(
      "internal",
      "Failed to send push notification via FCM.",
      error.message
    );
  }
});
