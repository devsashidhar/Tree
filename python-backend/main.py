import firebase_admin
from firebase_admin import credentials, messaging, firestore
from flask import Flask, request, jsonify

# Initialize Firebase Admin SDK
print("[Debug] Initializing Firebase Admin SDK...")
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
print("[Debug] Firebase Admin SDK initialized.")

db = firestore.client()

# Initialize Flask app
app = Flask(__name__)
print("[Debug] Flask app initialized.")

# Function to send a notification via FCM
def send_fcm_notification(fcm_token, title, body):
    try:
        print(f"[Debug] Preparing to send FCM notification to token: {fcm_token}")
        # Build the notification message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=fcm_token,
        )

        # Send the notification via FCM
        response = messaging.send(message)
        print(f"[FCM Response] Successfully sent notification: {response}")
        return {"status": "success", "message": "Notification sent successfully."}

    except Exception as e:
        print(f"[Error] Failed to send FCM notification: {e}")
        return {"status": "error", "message": str(e)}

# Function to send a like notification
def send_like_notification(post_id):
    try:
        print(f"[Debug] Fetching post data for post_id: {post_id}")
        # Fetch the post details
        post_doc = db.collection("posts").document(post_id).get()
        if not post_doc.exists:
            print(f"[Error] Post {post_id} does not exist.")
            return {"status": "error", "message": f"Post {post_id} does not exist."}

        post_data = post_doc.to_dict()
        print(f"[Debug] Post data fetched: {post_data}")

        # Get the post owner's user_id
        owner_id = post_data.get("userId")
        if not owner_id:
            print(f"[Error] Post {post_id} does not have an associated owner.")
            return {"status": "error", "message": f"Post {post_id} does not have an owner."}
        print(f"[Debug] Post owner user_id: {owner_id}")

        # Fetch the owner's FCM token
        print(f"[Debug] Fetching user data for owner_id: {owner_id}")
        owner_doc = db.collection("users").document(owner_id).get()
        if not owner_doc.exists:
            print(f"[Error] Owner {owner_id} does not exist.")
            return {"status": "error", "message": f"Owner {owner_id} does not exist."}

        owner_data = owner_doc.to_dict()
        print(f"[Debug] Owner data fetched: {owner_data}")
        fcm_token = owner_data.get("fcmToken")
        if not fcm_token:
            print(f"[Error] Owner {owner_id} does not have an FCM token.")
            return {"status": "error", "message": f"Owner {owner_id} does not have an FCM token."}

        # Calculate the number of likes
        likes_count = len(post_data.get("likes", []))
        print(f"[Debug] Post has {likes_count} likes.")
        if likes_count == 0:
            print(f"[Info] Post {post_id} has no likes.")
            return {"status": "info", "message": f"Post {post_id} has no likes."}

        # Prepare the notification content
        title = "New Like on Your Post!"
        body = f"Your post now has {likes_count} likes!"
        print(f"[Debug] Notification title: {title}, body: {body}")

        # Send the notification via FCM
        return send_fcm_notification(fcm_token, title, body)

    except Exception as e:
        print(f"[Error] Exception in send_like_notification: {e}")
        return {"status": "error", "message": str(e)}


@app.route("/like-notification", methods=["POST"])
def like_notification():
    """
    Endpoint to handle like notifications.
    """
    data = request.json
    post_id = data.get("postId")
    user_id = data.get("userId")

    print(f"[Debug] Received postId: {post_id}, userId: {user_id}")

    if not post_id or not user_id:
        return jsonify({"status": "error", "message": "Missing 'postId' or 'userId' in request."}), 400

    # Call the function to send the notification
    result = send_like_notification(post_id, user_id)
    return jsonify(result)


if __name__ == "__main__":
    print("[Debug] Starting Flask app...")
    app.run(debug=True, port=8000)
