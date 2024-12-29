const {getFirestore} = require("firebase-admin/firestore");
const admin = require("firebase-admin");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");

admin.initializeApp(); // Initialize Firebase Admin SDK
const db = getFirestore(); // Get Firestore instance

// Trigger on updates to the likes array in the posts collection
exports.sendLikeNotification = onDocumentUpdated("posts/{postId}", async (event) => {
  console.log("Firestore onUpdate triggered.");

  const postId = event.params.postId;
  const after = event.data.after.data();
  const before = event.data.before.data();

  console.log("Post ID:", postId);
  console.log("After data:", after);
  console.log("Before data:", before);

  // Ensure likes array exists and has increased
  const afterLikes = (after && after.likes) || [];
  const beforeLikes = (before && before.likes) || [];
  console.log("After likes:", afterLikes);
  console.log("Before likes:", beforeLikes);

  if (afterLikes.length <= beforeLikes.length) {
    console.log(`No new likes for post: ${postId}`);
    return null;
  }

  const newLikeCount = afterLikes.length;
  const userId = after.userId; // Owner of the post
  const locationName = after.locationName || "an unknown location"; // Get location name from Firestore
  console.log(`New like count for post ${postId}: ${newLikeCount}`);
  console.log(`User ID of the post owner: ${userId}`);

  try {
    // Fetch the user's FCM tokens
    const userDocRef = db.collection("users").doc(userId);
    const docSnapshot = await userDocRef.get();

    if (!docSnapshot.exists) {
      console.log(`User not found for userId: ${userId}`);
      return null;
    }

    const userData = docSnapshot.data();
    console.log("User data:", userData);
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens found for userId: ${userId}`);
      return null;
    }

    // Filter invalid tokens from the database
    const validTokens = [];
    const invalidTokens = [];

    const tokenValidationResults = await Promise.allSettled(
        fcmTokens.map((token) =>
          admin.messaging().send({
            token,
            data: {validation: "check"}, // Use data instead of notifications
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  "content-available": 1,
                },
              },
            },
          }),
        ),
    );


    tokenValidationResults.forEach((result, index) => {
      if (result.status === "fulfilled") {
        validTokens.push(fcmTokens[index]);
      } else if (
        result.reason.errorInfo &&
        result.reason.errorInfo.code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(fcmTokens[index]);
        console.log(`Invalid token found and removed: ${fcmTokens[index]}`);
      }
    });

    // Update Firestore with only valid tokens
    if (invalidTokens.length > 0) {
      await userDocRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }

    if (validTokens.length === 0) {
      console.log(`No valid FCM tokens left for userId: ${userId}`);
      return null;
    }

    // Create the notification payload
    const payload = {
      notification: {
        title: "New Like on Your Post!",
        body: `Your post of ${locationName} now has ${newLikeCount} likes.`,
      },
      android: {
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    console.log("Notification payload:", payload);

    // Send notifications to all valid tokens
    const notificationResults = await Promise.all(
        validTokens.map((token) =>
          admin.messaging().send({
            token,
            notification: payload.notification,
            android: payload.android,
            apns: payload.apns,
          }),
        ),
    );

    console.log(`Notifications sent for post: ${postId} to userId: ${userId}`);
    console.log("Responses:", notificationResults);

    return notificationResults;
  } catch (error) {
    console.error(`Error processing notification for post: ${postId} to userId: ${userId}`, error);
    return null;
  }
});

// Trigger when a user's "following" array is updated
exports.sendFollowNotification = onDocumentUpdated("users/{userId}", async (event) => {
  console.log("Firestore onUpdate triggered for user follow.");

  const userId = event.params.userId; // Person who is following others
  const after = event.data.after.data();
  const before = event.data.before.data();

  console.log("User ID:", userId);
  console.log("After data:", after);
  console.log("Before data:", before);

  // Get the new "following" array and compare with the old one
  const afterFollowing = (after && after.following) || [];
  const beforeFollowing = (before && before.following) || [];
  console.log("After following:", afterFollowing);
  console.log("Before following:", beforeFollowing);

  // Find the new follower
  const newFollowers = afterFollowing.filter((id) => !beforeFollowing.includes(id));
  if (newFollowers.length === 0) {
    console.log("No new followers detected.");
    return null;
  }

  // There should only be one new follower at a time
  const followedUserId = newFollowers[0];
  console.log(`New follower detected: ${userId} is now following ${followedUserId}`);

  try {
    // Fetch the followed user's FCM tokens
    const followedUserDocRef = db.collection("users").doc(followedUserId);
    const followedUserSnapshot = await followedUserDocRef.get();

    if (!followedUserSnapshot.exists) {
      console.log(`User not found for userId: ${followedUserId}`);
      return null;
    }

    const followedUserData = followedUserSnapshot.data();
    console.log("Followed user data:", followedUserData);

    const fcmTokens = followedUserData.fcmTokens || [];
    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens found for userId: ${followedUserId}`);
      return null;
    }

    // Fetch the username of the follower
    const followerUserDocRef = db.collection("users").doc(userId);
    const followerUserSnapshot = await followerUserDocRef.get();

    if (!followerUserSnapshot.exists) {
      console.log(`User not found for follower userId: ${userId}`);
      return null;
    }

    const followerUserData = followerUserSnapshot.data();
    const followerUsername = followerUserData.username || "Someone";

    console.log(`Follower username: ${followerUsername}`);

    // Add this code in sendFollowNotification before sending notifications to FCM
    const notificationRef = db.collection("users").doc(followedUserId).collection("notifications");
    await notificationRef.add({
      type: "follow",
      message: `${followerUsername} is now following you.`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false, // Add the read field
    });
    console.log(`Notification written to Firestore for userId: ${followedUserId}`);

    // Create the notification payload
    const payload = {
      notification: {
        title: "You have a new follower!",
        body: `${followerUsername} is now following you.`,
      },
      android: {
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    console.log("Notification payload:", payload);

    // Send notifications to all valid FCM tokens
    const notificationResults = await Promise.all(
        fcmTokens.map((token) =>
          admin.messaging().send({
            token,
            notification: payload.notification,
            android: payload.android,
            apns: payload.apns,
          }),
        ),
    );

    console.log(`Notifications sent for follow action to userId: ${followedUserId}`);
    console.log("Responses:", notificationResults);

    return notificationResults;
  } catch (error) {
    console.error(`Error processing follow notification for userId: ${followedUserId}`, error);
    return null;
  }
});

exports.sendMessageNotification = onDocumentUpdated("chats/{chatId}/messages/{messageId}", async (event) => {
  console.log("Firestore onCreate triggered for new message.");

  const messageData = event.data.data(); // Get the newly created message data
  const chatId = event.params.chatId;
  const messageId = event.params.messageId;

  console.log("Chat ID:", chatId);
  console.log("Message ID:", messageId);
  console.log("Message Data:", messageData);

  const {receiverId, senderId, text} = messageData;

  try {
    // Fetch the receiver's user document
    const receiverDocRef = db.collection("users").doc(receiverId);
    const receiverSnapshot = await receiverDocRef.get();

    if (!receiverSnapshot.exists) {
      console.log(`Receiver not found for userId: ${receiverId}`);
      return null;
    }

    const receiverData = receiverSnapshot.data();
    const fcmTokens = receiverData.fcmTokens || [];

    // Validate FCM tokens
    const validTokens = [];
    const invalidTokens = [];

    const tokenValidationResults = await Promise.allSettled(
        fcmTokens.map((token) =>
          admin.messaging().send({
            token,
            data: {validation: "check"},
            android: {priority: "high"},
            apns: {payload: {aps: {"content-available": 1}}},
          }),
        ),
    );

    tokenValidationResults.forEach((result, index) => {
      if (result.status === "fulfilled") {
        validTokens.push(fcmTokens[index]);
      } else if (
        result.reason.errorInfo &&
        result.reason.errorInfo.code === "messaging/registration-token-not-registered"
      ) {
        invalidTokens.push(fcmTokens[index]);
        console.log(`Invalid token removed: ${fcmTokens[index]}`);
      }
    });

    // Update Firestore with valid tokens only
    if (invalidTokens.length > 0) {
      await receiverDocRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }

    if (validTokens.length === 0) {
      console.log(`No valid FCM tokens found for receiver ID: ${receiverId}`);
      return null;
    }

    // Fetch the sender's username
    const senderDocRef = db.collection("users").doc(senderId);
    const senderSnapshot = await senderDocRef.get();

    if (!senderSnapshot.exists) {
      console.log(`Sender not found for userId: ${senderId}`);
      return null;
    }

    const senderData = senderSnapshot.data();
    const senderUsername = senderData.username || "Someone";

    console.log(`Sender username: ${senderUsername}`);

    // Create notification payload
    const payload = {
      notification: {
        title: "New Message",
        body: `${senderUsername}: ${text}`,
      },
      android: {
        notification: {sound: "default"},
      },
      apns: {
        payload: {
          aps: {sound: "default"},
        },
      },
    };

    console.log("Notification payload:", payload);

    // Send notifications to all valid FCM tokens
    const notificationResults = await Promise.all(
        validTokens.map((token) =>
          admin.messaging().send({
            token,
            notification: payload.notification,
            android: payload.android,
            apns: payload.apns,
          }),
        ),
    );

    console.log(`Notifications sent for message to receiver ID: ${receiverId}`);
    console.log("Responses:", notificationResults);

    return notificationResults;
  } catch (error) {
    console.error(`Error processing message notification for userId: ${receiverId}`, error);
    return null;
  }
});
