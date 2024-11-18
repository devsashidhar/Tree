import SwiftUI
import FirebaseCore
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import BackgroundTasks
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase configured successfully")
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
        
        // Set the notification delegate to self
        UNUserNotificationCenter.current().delegate = self
        
        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        // Register the background task (optional, if you still want to keep background tasks)
        registerBackgroundTask()
        
        return true
    }
    
    // Register the background task (Optional if you still want background task functionality)
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "Dev.Tree.backgroundfetch", using: nil) { task in
            // This is the task handler
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "Dev.Tree.backgroundfetch")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20) // Schedule for 20 seconds later for testing purposes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Unable to submit task: \(error)")
        }
    }

    
    // Perform the task when the app is in the background
    func handleAppRefresh(task: BGAppRefreshTask) {
        print("handleAppRefresh triggered")
        // Schedule the next refresh
        scheduleAppRefresh()
        print("Scheduled next app refresh")
        
        // Check for new likes on the user's photos
        checkLikesForAllPosts() // Call your function to check likes for all posts
        print("checkLikesForAllPosts called")
        
        // Provide a completion handler
        task.expirationHandler = {
            // If the task runs out of time, clean up here
            print("Background task expired before completion")
        }
        
        // Mark the task as complete
        task.setTaskCompleted(success: true)
        print("Background task completed successfully")
    }
    
    func checkLikesForAllPosts() {
        let userId = Auth.auth().currentUser?.uid ?? ""

        // Fetch posts created by the current user (Mike)
        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching posts: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No posts found for userId: \(userId)")
                    return
                }

                let postIds = documents.map { $0.documentID } // Extract post IDs of Mike's posts

                // Check the number of likes for each post Mike has created
                for postId in postIds {
                    NotificationManager.shared.checkLikesAndNotifyUser(postId: postId)
                }
            }
    }
    
    // Schedule the background task when the app moves to the background (optional)
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    // MARK: - UNUserNotificationCenterDelegate for notifications in the foreground
    
    // This function will be called when a notification is delivered while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Present notification as a banner, list, with sound and badge while the app is in the foreground
        completionHandler([.banner, .list, .sound, .badge])
    }

    // MARK: - Handling Remote Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // Firebase Messaging Delegate Method
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        // Optionally: send token to the server if needed
    }
}

@main
struct TreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView() // Use RootView to decide which screen to show
        }
    }
}
