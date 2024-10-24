import FirebaseFirestore
import UserNotifications

class NotificationManager {
    
    static let shared = NotificationManager()
    
    private init() {}
    
    // Function to check likes and notify the user about the total likes
    func checkLikesAndNotifyUser(postId: String) {
        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(postId)
        let trackingRef = db.collection("user_like_tracking").document(postId)

        // Fetch current like count
        postRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                let currentLikes = (data?["likes"] as? [String])?.count ?? 0
                
                // Fetch last known like count
                trackingRef.getDocument { trackingDoc, error in
                    if let trackingDoc = trackingDoc, trackingDoc.exists {
                        let trackingData = trackingDoc.data()
                        let lastLikeCount = trackingData?["lastLikeCount"] as? Int ?? 0
                        let lastNotificationDate = trackingData?["lastNotificationDate"] as? Timestamp ?? Timestamp(date: Date(timeIntervalSince1970: 0))

                        // Check if 20 seconds have passed since the last notification
                        let currentTime = Date()
                        let secondsSinceLastNotification = currentTime.timeIntervalSince(lastNotificationDate.dateValue())

                        if currentLikes != lastLikeCount && secondsSinceLastNotification > 20 {
                            // Send notification with the total number of likes
                            self.sendLikeNotification(totalLikes: currentLikes)
                            
                            // Update the lastLikeCount and lastNotificationDate in Firestore
                            trackingRef.setData([
                                "lastLikeCount": currentLikes,
                                "lastNotificationDate": Timestamp(date: Date())
                            ], merge: true)
                        }
                    } else {
                        // If no tracking data exists, create it
                        trackingRef.setData([
                            "lastLikeCount": currentLikes,
                            "lastNotificationDate": Timestamp(date: Date())
                        ], merge: true)
                    }
                }
            } else {
                print("Error fetching post data: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    // Function to send a notification with the total number of likes
    public func sendLikeNotification(totalLikes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Your image is gaining attention!"
        content.body = "Your photos have received a total of \(totalLikes) likes!"
        content.sound = .default

        // Trigger notification after 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }
}
