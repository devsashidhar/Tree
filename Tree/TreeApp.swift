import SwiftUI
import FirebaseCore
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import BackgroundTasks
import FirebaseMessaging
//import GoogleSignIn // Required for OAuth

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[Debug] Application didFinishLaunchingWithOptions started.")

        // Initialize Firebase
        FirebaseApp.configure()
        print("[Debug] Firebase configured successfully.")

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[Debug] Notification permission granted.")
            } else if let error = error {
                print("[Error] Failed to request notification permissions: \(error.localizedDescription)")
            } else {
                print("[Warning] Notification permission denied by the user.")
            }
        }

        // Set delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        // Add Firebase auth state listener
        _ = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                print("[Debug] User logged in: \(user.uid). Checking FCM token...")
                self?.handleUserLogin()
            } else {
                print("[Warning] No authenticated user.")
            }
        }
        UserDefaults.standard.set(true, forKey: "firstLaunch")

        print("[Debug] Application didFinishLaunchingWithOptions completed.")
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Set the APNs token in Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Debug] APNs token set: \(tokenString)")

        // Fetch the FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                print("[Error] Failed to fetch FCM token: \(error.localizedDescription)")
            } else if let token = token {
                print("[Success] FCM token fetched: \(token)")
                self.saveFCMTokenToFirestore(token: token)
            } else {
                print("[Error] FCM token is nil.")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Error] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    private func saveFCMTokenToFirestore(token: String) {
        if let userId = Auth.auth().currentUser?.uid {
            print("[Debug] Saving FCM token to Firestore for userId: \(userId)")
            let userRef = Firestore.firestore().collection("users").document(userId)

            // Use FieldValue.arrayUnion to ensure tokens are stored uniquely
            userRef.updateData(["fcmTokens": FieldValue.arrayUnion([token])]) { error in
                if let error = error {
                    print("[Error] Failed to save FCM token to Firestore: \(error.localizedDescription)")
                } else {
                    print("[Success] FCM token \(token) successfully saved to Firestore for userId: \(userId)")
                }
            }
        } else {
            print("[Warning] No authenticated user. Cannot save FCM token.")
        }
    }

    // Handle FCM token updates
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("[Info] Firebase registration token: \(String(describing: fcmToken))")
        if let fcmToken = fcmToken {
            saveFCMTokenToFirestore(token: fcmToken)
        }
    }

    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("[Debug] Foreground notification received: \(notification.request.content.userInfo)")
        completionHandler([.banner, .sound])
    }

    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("[Debug] Notification tapped: \(response.notification.request.content.userInfo)")
        completionHandler()
    }

    private func handleUserLogin() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Warning] User not authenticated, skipping token save.")
            return
        }

        Messaging.messaging().token { token, error in
            if let error = error {
                print("[Error] Failed to fetch FCM token after login: \(error.localizedDescription)")
            } else if let token = token {
                print("[Debug] Saving FCM token to Firestore for userId: \(userId)")
                self.saveFCMTokenToFirestore(token: token)
            } else {
                print("[Warning] FCM token is nil after login.")
            }
        }
    }

    func checkLikesForAllPosts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Warning] No authenticated user. Skipping like checks.")
            return
        }

        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("[Error] Failed to fetch posts: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("[Info] No posts found for userId: \(userId).")
                    return
                }

                print("[Debug] Found \(documents.count) posts for userId: \(userId).")
                for document in documents {
                    NotificationManager.shared.checkLikesAndNotifyUser(postId: document.documentID)
                }
            }
    }


}

@main
struct TreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
