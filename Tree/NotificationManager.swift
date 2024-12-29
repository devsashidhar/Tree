import FirebaseFirestore
import UserNotifications
import FirebaseAuth

class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    func checkLikesAndNotifyUser(postId: String) {
        print("[Debug] Checking likes for postId: \(postId)")

        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(postId)
        let trackingRef = db.collection("user_like_tracking").document(postId)

        // Fetch post data
        postRef.getDocument { document, error in
            if let error = error {
                print("[Error] Failed to fetch post \(postId): \(error.localizedDescription)")
                return
            }

            guard let data = document?.data() else {
                print("[Warning] No data found for postId: \(postId)")
                return
            }

            let currentLikes = (data["likes"] as? [String])?.count ?? 0
            let uploaderId = data["userId"] as? String ?? "" // Fetch uploader ID

            if uploaderId.isEmpty {
                print("[Error] Uploader ID is missing or invalid for post \(postId).")
                return
            }

            print("[Debug] Current likes for post \(postId): \(currentLikes)")
            print("[Debug] Uploader ID for post \(postId): \(uploaderId)")

            // Fetch tracking data
            trackingRef.getDocument { trackingDoc, error in
                if let error = error {
                    print("[Error] Failed to fetch tracking data for \(postId): \(error.localizedDescription)")
                }

                let lastLikeCount = trackingDoc?.data()?["lastLikeCount"] as? Int ?? 0
                let lastNotificationDate = trackingDoc?.data()?["lastNotificationDate"] as? Timestamp

                print("[Debug] lastLikeCount: \(lastLikeCount), lastNotificationDate: \(String(describing: lastNotificationDate))")

                // Initialize lastNotificationDate if missing
                if lastNotificationDate == nil {
                    print("[Warning] Missing or invalid lastNotificationDate for post \(postId). Initializing...")
                    trackingRef.setData([
                        "lastLikeCount": currentLikes,
                        "lastNotificationDate": Timestamp(date: Date())
                    ], merge: true)
                    return
                }

                let timeSinceLastNotification = Date().timeIntervalSince(lastNotificationDate!.dateValue())
                print("[Debug] Time since last notification: \(timeSinceLastNotification)s")

                // Check if notification should be sent
                if currentLikes != lastLikeCount && timeSinceLastNotification > 60 {
                    // Fetch uploader's FCM token
                    let userRef = db.collection("users").document(uploaderId)
                    print("[Debug] Fetching FCM token for uploaderId: \(uploaderId)")

                    userRef.getDocument { userDoc, error in
                        if let error = error {
                            print("[Error] Failed to fetch uploader user data: \(error.localizedDescription)")
                            self.retryFetchingTokens(uploaderId: uploaderId, currentLikes: currentLikes) // Start retry mechanism
                            return
                        }

                        guard let userData = userDoc?.data(), let fcmTokens = userData["fcmTokens"] as? [String] else {
                            print("[Warning] Uploader does not have valid FCM tokens.")
                            self.retryFetchingTokens(uploaderId: uploaderId, currentLikes: currentLikes)
                            return
                        }

                        print("[Debug] Retrieved FCM token for uploader \(uploaderId): \(fcmTokens)")
                        print("[Debug] Sending notification to uploader with FCM token: \(fcmTokens)")

                        // Send notification to each token
                        for token in fcmTokens {
                            print("[Debug] Sending notification to uploader with FCM token: \(token)")
                            self.sendLikeNotification(totalLikes: currentLikes, fcmToken: token, uploaderId: uploaderId)
                        }

                        // Update tracking data immediately after sending notification
                        trackingRef.setData([
                            "lastLikeCount": currentLikes,
                            "lastNotificationDate": Timestamp(date: Date())
                        ], merge: true)
                        print("[Success] Notification sent and tracking data updated for post \(postId).")
                    }
                } else if currentLikes == lastLikeCount {
                    print("[Info] Like count hasn't changed for post \(postId). No notification needed.")
                } else {
                    print("[Info] Notification too soon for post \(postId).")
                }
            }
        }
    }



    func sendLikeNotification(totalLikes: Int, fcmToken: String, uploaderId: String) {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        print("[Debug] Sending notification for totalLikes: \(totalLikes), currentUserId: \(currentUserId), fcmToken: \(fcmToken)")

        // Prevent local notifications for non-uploaders
        if currentUserId != uploaderId {
            print("[Info] Current user is not the uploader. Sending notification to uploader only.")
            
            // FCM Notification for the uploader
            let payload: [String: Any] = [
                "to": fcmToken,
                "notification": [
                    "title": "Your photo is gaining attention!",
                    "body": "Your photo has received a total of \(totalLikes) likes!",
                    "sound": "default"
                ],
                "content_available": true,
                "priority": "high"
            ]
            
            let url = URL(string: "https://fcm.googleapis.com/fcm/send")!
            var notificationRequest = URLRequest(url: url)
            notificationRequest.httpMethod = "POST"
            notificationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            notificationRequest.setValue("key=78FLVHZZLK", forHTTPHeaderField: "Authorization")
            notificationRequest.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
            
            let task = URLSession.shared.dataTask(with: notificationRequest) { data, response, error in
                if let error = error {
                    print("[Error] Failed to send FCM notification: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[Debug] HTTP status code: \(httpResponse.statusCode)")
                }
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("[Debug] FCM response body: \(responseBody)")
                }
            }
            task.resume()
            return
        }

        // Local Notification for Testing (Uploader Only)
        print("[Info] Current user is the uploader. Sending local notification for testing.")
        let content = UNMutableNotificationContent()
        content.title = "Your photo is gaining attention!"
        content.body = "Your photo has received a total of \(totalLikes) likes!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Error] Failed to send local notification: \(error.localizedDescription)")
            } else {
                print("[Success] Local notification sent successfully.")
            }
        }
    }
    
    
    func retryFetchingTokens(uploaderId: String, currentLikes: Int, retries: Int = 3) {
        guard retries > 0 else {
            print("[Error] Retries exhausted for fetching FCM tokens for uploaderId: \(uploaderId)")
            return
        }

        Firestore.firestore().collection("users").document(uploaderId).getDocument { userDoc, error in
            if let error = error {
                print("[Error] Failed to fetch uploader user data: \(error.localizedDescription). Retrying...")
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self.retryFetchingTokens(uploaderId: uploaderId, currentLikes: currentLikes, retries: retries - 1)
                }
                return
            }

            guard let userData = userDoc?.data(), let fcmTokens = userData["fcmTokens"] as? [String] else {
                print("[Warning] Uploader does not have valid FCM tokens. Retrying...")
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self.retryFetchingTokens(uploaderId: uploaderId, currentLikes: currentLikes, retries: retries - 1)
                }
                return
            }

            print("[Debug] Successfully retrieved FCM tokens for uploader \(uploaderId): \(fcmTokens)")

            // Proceed with notification
            if let firstToken = fcmTokens.first {
                print("[Debug] Using FCM token for notification: \(firstToken)")
                self.sendLikeNotification(totalLikes: currentLikes, fcmToken: firstToken, uploaderId: uploaderId) // Include uploaderId
            }
        }
    }


}
