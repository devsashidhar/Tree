import SwiftUI
import FirebaseFirestore
import CoreLocation
import Kingfisher
import FirebaseAuth

// Step 1: Add this struct at the top of your file
struct IdentifiableString: Identifiable {
    var id: String
}

struct AppNotification: Identifiable {
    let id: String
    let message: String
    let timestamp: Date
    let read: Bool
}


struct NotificationCenterView: View {
    let notifications: [AppNotification]

    var body: some View {
        List(notifications) { notification in
            VStack(alignment: .leading) {
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.white)
                Text("\(notification.timestamp, formatter: DateFormatter.shortDate)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
        }
        .listStyle(PlainListStyle())
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationTitle("Notifications")
    }
}

extension DateFormatter {
    static var shortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}


struct ZoomableImageView: View {
    let imageUrl: String

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            KFImage(URL(string: imageUrl))
                .resizable()
                .aspectRatio(contentMode: .fit) // Maintain aspect ratio
                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnitude
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset // Save the final offset
                            }
                    )
                )
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}


struct ChatIdentifier: Identifiable {
    var id: String
    var userIds: [String] // Add userIds to keep track of users in the chat
}


struct Post: Identifiable {
    var id: String
    var userId: String
    var username: String
    var imageUrl: String
    var locationName: String
    var timestamp: Timestamp
    var likes: [String] = [] // Array to store user IDs of people who liked the post
}

struct Feed: View {
    @State private var posts: [Post] = []
    @State private var users: [String: String] = [:]
    @State private var isRefreshing = false
    @State private var allPostsViewed = false
    @State private var isLoading = false
    @State private var selectedChatId: ChatIdentifier? // Use ChatIdentifier instead of String
    @State private var isMessageCenterPresented = false
    @State private var unreadMessagesCount: Int = 0 // Unread messages count
    @State private var likedPosts: Set<String> = [] // Track liked posts for the current session
    
    // blocking
    @State private var blockedUsers: [String] = [] // Track blocked users persistently
    @State private var showBlockConfirmation: Bool = false // Show confirmation message after blocking
   
    @State private var selectedUserIdToBlock: String? = nil
    
    @State private var selectedUserIdToFlag: String? // To track the user ID to flag
    @State private var showFlagConfirmation: Bool = false // To control the display of the flag confirmation alert
    
    @State private var selectedPostIdToFlag: String? = nil // Holds the post ID for flagging confirmation
    
    @State private var flaggedPosts: Set<String> = [] // Track flagged posts
    
    @State private var selectedImageUrl: String? // Track the selected image URL
    
    @State private var selectedImage: FullScreenImage? = nil // For showing the full-screen image
    
    // State for notifications
    @State public var isNotificationCenterPresented = false
    @State private var notifications: [AppNotification] = []

    @State private var unreadNotificationsCount: Int = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("EcoTerra")
                            .font(.custom("Noteworthy", size: 34))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                            .tracking(2)
                        Spacer()
                        
                        // Notification button
                        Button(action: {
                            print("[Debug] Notification button tapped.")
                            fetchNotifications()
                            isNotificationCenterPresented = true
                        }) {
                            ZStack {
                                Image(systemName: "bell.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.white)
                                
                                if unreadNotificationsCount > 0 {
                                    Text("\(unreadNotificationsCount)")
                                        .font(.caption2)
                                        .padding(4)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                        .sheet(isPresented: $isNotificationCenterPresented, onDismiss: markNotificationsAsRead) {
                            NotificationCenterView(notifications: notifications)
                        }

                        // Messaging button with unread count badge
                        Button(action: {
                            isMessageCenterPresented = true
                        }) {
                            ZStack {
                                Image(systemName: "message.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.white)
                                
                                if unreadMessagesCount > 0 {
                                    Text("\(unreadMessagesCount)")
                                        .font(.caption2)
                                        .padding(4)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                        .fullScreenCover(isPresented: $isMessageCenterPresented) {
                            NavigationView {
                                MessagingCenterView(currentUserId: Auth.auth().currentUser?.uid ?? "")
                            }
                            .navigationViewStyle(StackNavigationViewStyle())
                        }
                    }
                    .padding()
                    .background(Color.black)

                    // Feed Content
                    if isLoading {
                        // Show loading spinner while posts are being fetched
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .padding()

                            Text("Loading...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(maxHeight: .infinity)
                    } else if posts.isEmpty && allPostsViewed {
                        // Show "You're all caught up!" message
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.green)
                                .shadow(radius: 10)

                            Text("You're all caught up!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding()

                            Text("No more posts to view at the moment")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.top, -10)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Scrollable feed content below the fixed header
                        
                        ScrollView {
                            LazyVStack {
                                ForEach(posts) { post in
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Username and Location Name Above the Photo
                                        HStack {
                                            NavigationLink(destination: UserPostsView(userId: post.userId)) {
                                                Text("Posted by: \(users[post.userId] ?? "Unknown")")
                                                    .font(.caption)
                                                    .foregroundColor(Color.blue.opacity(0.7)) // Subtle blue shade
                                            }
                                            Spacer()
                                            Menu {
                                                Button(action: {
                                                    selectedUserIdToBlock = post.userId
                                                    showBlockConfirmation = true
                                                }) {
                                                    Label("Block", systemImage: "hand.raised.fill")
                                                }
                                                Button(action: {
                                                    if flaggedPosts.contains(post.id) {
                                                        flaggedPosts.remove(post.id)
                                                        unflagContent(post.id)
                                                    } else {
                                                        flaggedPosts.insert(post.id)
                                                        flagContent(post.id, offendingUserId: post.userId)
                                                    }
                                                }) {
                                                    Label(flaggedPosts.contains(post.id) ? "Unflag" : "Flag", systemImage: flaggedPosts.contains(post.id) ? "flag.fill" : "flag")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(.gray)
                                            }
                                        }

                                        Text("Location: \(post.locationName)")
                                            .font(.caption)
                                            .foregroundColor(.white)

                                        KFImage(URL(string: post.imageUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: UIScreen.main.bounds.width - 20)
                                            .gesture(
                                                ExclusiveGesture(
                                                    TapGesture(count: 2).onEnded {
                                                        likePost(post) // Double tap to like
                                                    },
                                                    TapGesture(count: 1).onEnded {
                                                        selectedImage = FullScreenImage(url: post.imageUrl) // Single tap for full screen
                                                    }
                                                )
                                            )


                                        // Buttons Below the Photo
                                        HStack(spacing: 12) {
                                            Button(action: { likePost(post) }) {
                                                Image(systemName: likedPosts.contains(post.id) ? "heart.fill" : "heart")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(likedPosts.contains(post.id) ? .red : .gray)
                                            }

                                            Button(action: {
                                                initiateChat(with: post.userId)
                                            }) {
                                                Image(systemName: "message")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .padding(.horizontal) // Retain horizontal padding for consistent spacing
                                    .padding(.vertical, 5) // Retain vertical padding for spacing between posts
                                    .background(Color.black) // Maintain dark theme
                                    .onAppear {
                                        markPostAsViewed(post) // Ensure posts are marked as viewed
                                    }

                                }
                            }
                            .padding(.top, 10)
                        }
                        .refreshable {
                            refreshFeed()
                        }
                    }

                }
                .fullScreenCover(item: $selectedImage) { fullScreenImage in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ZoomableImageView(imageUrl: fullScreenImage.url)
                        VStack {
                            HStack {
                                Button(action: {
                                    selectedImage = nil // Dismiss full-screen mode
                                }) {
                                    Image(systemName: "arrow.left")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                }
                                .padding(.leading, 20)
                                .padding(.top, 40)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                
                .alert(isPresented: $showBlockConfirmation) {
                    Alert(
                        title: Text("Block user?"),
                        message: Text("Do you want to block this user?"),
                        primaryButton: .default(Text("Yes"), action: {
                            if let userId = selectedUserIdToBlock {
                                blockUser(userId)
                            }
                        }),
                        secondaryButton: .cancel(Text("No"), action: {
                            showBlockConfirmation = false // Reset to close the alert
                        })
                    )
                }
                
                // Full-screen cover for chat
                .fullScreenCover(item: $selectedChatId) { chatIdentifier in
                    let otherUserId = chatIdentifier.userIds.first { $0 != Auth.auth().currentUser!.uid } ?? ""
                    ChatView(chatId: chatIdentifier.id, currentUserId: Auth.auth().currentUser!.uid, receiverId: otherUserId)
                }
            }
        }
        .onAppear {
            listenForUnreadNotifications()
            requestNotificationPermissions()
            fetchUnreadMessages()
            fetchPosts()
            print("[Info] Unread notification count badge: \(unreadNotificationsCount)")
        }
    }
    
    func listenForUnreadNotifications() {
        guard let userId = Auth.auth().currentUser?.uid else {
                print("[Error] User ID not found.")
                return
        }
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .whereField("read", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[Error] Fetching unread notifications failed: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("[Warning] No snapshot data returned.")
                    return
                }
                
                print("[Info] Listener triggered. Unread notifications count: \(snapshot.documents.count)")
                snapshot.documents.forEach { doc in
                    print("[Info] Notification ID: \(doc.documentID), Data: \(doc.data())")
                }
                
                // Update unread count
                self.unreadNotificationsCount = snapshot.documents.count
            }
    }
    
    private func markNotificationsAsRead() {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        print("[Debug] Marking notifications as read for userId: \(currentUserId)")
        
        Firestore.firestore()
            .collection("users")
            .document(currentUserId)
            .collection("notifications")
            .whereField("read", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("[Error] Marking notifications as read failed: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("[Warning] No unread notifications to mark as read.")
                    return
                }
                
                documents.forEach { doc in
                    print("[Info] Marking notification as read: \(doc.documentID)")
                    doc.reference.updateData(["read": true])
                }
                
                self.unreadNotificationsCount = 0
            }
    }

    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // Request permissions if not determined
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Error requesting notification permissions: \(error)")
                    } else if granted {
                        print("Notifications permission granted.")
                    } else {
                        print("Notifications permission denied.")
                    }
                }
            case .authorized, .provisional:
                print("Notifications already authorized.")
            case .denied:
                print("Notifications were previously denied. Encourage the user to enable them in settings.")
            @unknown default:
                print("Unknown notification settings state. No action taken.")
            }
        }
    }
    
    private func fetchNotifications() {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        print("[Debug] Fetching notifications for userId: \(currentUserId)")
        
        Firestore.firestore()
            .collection("users")
            .document(currentUserId)
            .collection("notifications")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("[Error] Fetching notifications failed: \(error.localizedDescription)")
                    self.notifications = [] // Clear notifications on error
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("[Warning] No notifications found.")
                    self.notifications = []
                    return
                }
                
                print("[Info] Notifications fetched: \(documents.count)")
                documents.forEach { doc in
                    print("[Info] Notification ID: \(doc.documentID), Data: \(doc.data())")
                }
                
                self.notifications = documents.compactMap { doc in
                    let data = doc.data()
                    return AppNotification(
                        id: doc.documentID,
                        message: data["message"] as? String ?? "Unknown notification",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        read: data["read"] as? Bool ?? false
                    )
                }
                
                print("[Info] Parsed notifications: \(self.notifications)")
            }
    }



    // Notify the backend about the like
    func notifyBackendOfLike(postId: String, userId: String) {
        guard let url = URL(string: "https://your-backend-url.com/like-notification") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "postId": postId,
            "userId": userId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Error serializing JSON body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending like notification to backend: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Notification triggered successfully for post: \(postId)")
            } else {
                print("Unexpected response from backend for post: \(postId)")
            }
        }.resume()
    }
    
    private func processUserPosts(completion: @escaping ([String]) -> Void) {
        let db = Firestore.firestore()
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        var notifications: [String] = []
        
        db.collection("posts").whereField("userId", isEqualTo: currentUserId).getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                for document in documents {
                    let postId = document.documentID
                    NotificationManager.shared.checkLikesAndNotifyUser(postId: postId)
                    
                    // Add notification for likes
                    let data = document.data()
                    let currentLikes = (data["likes"] as? [String])?.count ?? 0
                    if currentLikes > 0 {
                        notifications.append("Your post has \(currentLikes) likes!")
                    }
                }
                completion(notifications)
            } else {
                print("Error fetching posts: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
            }
        }
    }


    func flagContent(_ postId: String, offendingUserId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        // Reference to the "flaggedPosts" collection
        let db = Firestore.firestore()
        let flaggedPostRef = db.collection("flaggedPosts").document(postId)

        // Data to store in Firestore for tracking flagged content
        let flagData: [String: Any] = [
            "flaggedByUserId": currentUserId,       // The ID of the user who flagged the post
            "offendingUserId": offendingUserId,     // The ID of the user who posted the flagged content
            "postId": postId,                       // The ID of the flagged post
            "timestamp": FieldValue.serverTimestamp() // Timestamp of when the flag was created
        ]

        // Add the flagged post entry to Firestore
        flaggedPostRef.setData(flagData) { error in
            if let error = error {
                print("Error flagging post: \(error)")
            } else {
                print("Post successfully flagged and saved to Firestore.")
            }
        }
    }

    
    func unflagContent(_ postId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Reference to the Firestore collection where flags are stored (assuming "flaggedContent")
        let db = Firestore.firestore().collection("flaggedContent")
        
        // Find the document where the current user flagged this post
        db.whereField("postId", isEqualTo: postId)
          .whereField("flaggedByUserId", isEqualTo: currentUserId)
          .getDocuments { snapshot, error in
            if let error = error {
                print("Error unflagging content: \(error.localizedDescription)")
            } else if let document = snapshot?.documents.first {
                // Remove the flag by deleting the document
                db.document(document.documentID).delete { error in
                    if let error = error {
                        print("Error deleting flag document: \(error.localizedDescription)")
                    } else {
                        print("Content successfully unflagged.")
                        // Optionally remove from flaggedPosts array for UI update
                        flaggedPosts.remove(postId)
                    }
                }
            }
        }
    }


    
    // Function to fetch unread messages count
    func fetchUnreadMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        ChatService().fetchUnreadMessagesCount(forUserId: userId) { result in
            switch result {
            case .success(let count):
                self.unreadMessagesCount = count
            case .failure(let error):
                print("Error fetching unread messages count: \(error)")
            }
        }
    }

    func initiateChat(with userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user")
            return
        }

        // Debugging: Print the current user and the user we're trying to initiate a chat with
        print("Initiating chat between \(currentUserId) and \(userId)")

        ChatService().getOrCreateChat(forUsers: [currentUserId, userId]) { result in
            switch result {
            case .success(let chatId):
                // Wrap the chatId and userIds in ChatIdentifier
                self.selectedChatId = ChatIdentifier(id: chatId, userIds: [currentUserId, userId]) // Pass userIds array here
            case .failure(let error):
                print("Error initiating chat: \(error)")
            }
        }
    }

    private func blockUser(_ userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(currentUserId)
        
        userRef.updateData([
            "blockedUsers": FieldValue.arrayUnion([userId]),
            "following": FieldValue.arrayRemove([userId]) // Remove from following
        ]) { error in
            if let error = error {
                print("Error blocking user: \(error)")
            } else {
                blockedUsers.append(userId) // Update local state
                showBlockConfirmation = false
                selectedUserIdToBlock = nil
            }
        }
    }

    private func unblockUser(_ userId: String) {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            let userRef = Firestore.firestore().collection("users").document(currentUserId)
            
            userRef.updateData([
                "blockedUsers": FieldValue.arrayRemove([userId]),
                "following": FieldValue.arrayUnion([userId]) // Re-add to following
            ]) { error in
                if let error = error {
                    print("Error unblocking user: \(error)")
                } else {
                    blockedUsers.removeAll { $0 == userId } // Update local state
                    print("User \(userId) successfully unblocked and re-added to following.")
                }
            }
    }
    

    // Refresh feed functionality
    func refreshFeed() {
        print("Refreshing feed...")
        isRefreshing = true
        isLoading = true
        posts.removeAll() // Clear existing posts
        fetchPosts() // Re-fetch posts
        isRefreshing = false
    }

    func markPostAsViewed(_ post: Post) {
        let userId = Auth.auth().currentUser?.uid ?? ""

        let userRef = Firestore.firestore().collection("users").document(userId)

        userRef.updateData([
            "viewedPosts": FieldValue.arrayUnion([post.id])
        ]) { error in
            if let error = error {
                print("Error updating viewedPosts: \(error)")
            } else {
                print("Successfully updated viewedPosts with post: \(post.id)")
            }
        }
    }
    
    // Like a post
    func likePost(_ post: Post) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()

        if likedPosts.contains(post.id) {
            // If already liked, remove the like
            db.collection("posts").document(post.id).updateData([
                "likes": FieldValue.arrayRemove([currentUserId])
            ]) { error in
                if let error = error {
                    print("Error removing like: \(error)")
                    return
                }
                likedPosts.remove(post.id)
                print("Like removed for post: \(post.id)")
            }
        } else {
            // If not liked, add the like
            db.collection("posts").document(post.id).updateData([
                "likes": FieldValue.arrayUnion([currentUserId])
            ]) { error in
                if let error = error {
                    print("Error adding like: \(error)")
                    return
                }
                likedPosts.insert(post.id)
                print("Like added for post: \(post.id)")

                // Notify the backend about the like
                notifyBackendOfLike(postId: post.id, userId: post.userId)
            }
        }
    }
    
    // Fetch posts function with integrated blocked users check
    func fetchPosts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user")
            isLoading = false
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.getDocument { (snapshot, error) in
            if let error = error {
                print("Error fetching user document: \(error)")
                self.posts = [] // Clear the feed
                self.isLoading = false
                return
            }

            guard let data = snapshot?.data() else {
                print("User document does not exist, unable to fetch posts.")
                self.posts = [] // Clear the feed
                self.isLoading = false
                return
            }
            
            // Fetch viewed posts list from the user document
            let viewedPosts = data["viewedPosts"] as? [String] ?? []
            
            let following = data["following"] as? [String] ?? []
            
            // If no followed users, display an empty feed
            if following.isEmpty {
                print("Feed is empty. Follow users to see posts!")
                self.posts = [] // Clear the feed
                self.isLoading = false
                return
            }
            
            fetchPostsFromFollowedUsers(following: following, viewedPosts: viewedPosts)
        }
    }
    
    func fetchPostsFromFollowedUsers(following: [String], viewedPosts: [String]) {
        let batchSize = 10
        let batches = stride(from: 0, to: following.count, by: batchSize).map {
            Array(following[$0..<min($0 + batchSize, following.count)])
        }

        var fetchedPosts: [Post] = []
        var batchFetchesCompleted = 0

        for batch in batches {
            Firestore.firestore().collection("posts")
                .whereField("userId", in: batch)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching posts for batch: \(error)")
                        batchFetchesCompleted += 1
                        checkBatchCompletion(batchFetchesCompleted, totalBatches: batches.count, fetchedPosts: fetchedPosts)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        batchFetchesCompleted += 1
                        checkBatchCompletion(batchFetchesCompleted, totalBatches: batches.count, fetchedPosts: fetchedPosts)
                        return
                    }

                    for document in documents {
                        let data = document.data()

                        guard let userId = data["userId"] as? String,
                              let imageUrl = data["imageUrl"] as? String,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            continue
                        }

                        if viewedPosts.contains(document.documentID) {
                            continue
                        }

                        let locationName = data["locationName"] as? String ?? "Unknown location"
                        let post = Post(
                            id: document.documentID,
                            userId: userId,
                            username: "Unknown",
                            imageUrl: imageUrl,
                            locationName: locationName,
                            timestamp: timestamp
                        )
                        fetchedPosts.append(post)
                        
                        // Trigger notification monitoring for likes
                        NotificationManager.shared.checkLikesAndNotifyUser(postId: post.id)
                    }

                    batchFetchesCompleted += 1
                    checkBatchCompletion(batchFetchesCompleted, totalBatches: batches.count, fetchedPosts: fetchedPosts)
                }
        }
    }
    
    func checkBatchCompletion(_ completed: Int, totalBatches: Int, fetchedPosts: [Post]) {
            if completed == totalBatches {
                DispatchQueue.main.async {
                    self.posts = fetchedPosts
                    self.isLoading = false
                    fetchUsernames(for: fetchedPosts)
                }
            }
    }


    func fetchAllPosts() {
        Firestore.firestore().collection("posts").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching posts: \(error)")
                isLoading = false
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found")
                allPostsViewed = true
                isLoading = false
                return
            }

            var fetchedPosts: [Post] = []
            for document in documents {
                let data = document.data()

                guard let userId = data["userId"] as? String,
                      let imageUrl = data["imageUrl"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    continue
                }

                let locationName = data["locationName"] as? String ?? "Unknown location"

                let post = Post(id: document.documentID,
                                userId: userId,
                                username: "Unknown",
                                imageUrl: imageUrl,
                                locationName: locationName,
                                timestamp: timestamp)

                fetchedPosts.append(post)
            }

            DispatchQueue.main.async {
                self.posts = fetchedPosts
                self.allPostsViewed = fetchedPosts.isEmpty
                self.isLoading = false
                self.fetchUsernames(for: fetchedPosts)
            }
        }
    }


    func fetchUsernames(for posts: [Post]) {
        let userIds = Array(Set(posts.map { $0.userId }))

        guard !userIds.isEmpty else {
            print("No user IDs to fetch.")
            return
        }

        let batchSize = 10
        let batches = stride(from: 0, to: userIds.count, by: batchSize).map {
            Array(userIds[$0..<min($0 + batchSize, userIds.count)])
        }

        for batch in batches {
            Firestore.firestore().collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { (snapshot, error) in
                    guard let documents = snapshot?.documents else {
                        print("Error fetching user documents: \(String(describing: error))")
                        return
                    }

                    var fetchedUsers: [String: String] = [:]
                    for document in documents {
                        let data = document.data()
                        if let username = data["username"] as? String {
                            fetchedUsers[document.documentID] = username
                        }
                    }

                    DispatchQueue.main.async {
                        self.users.merge(fetchedUsers) { (_, new) in new }
                    }
                }
        }
    }
    
}
