import SwiftUI
import FirebaseFirestore
import CoreLocation
import Kingfisher
import FirebaseAuth

// Step 1: Add this struct at the top of your file
struct IdentifiableString: Identifiable {
    var id: String
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
    var latitude: Double
    var longitude: Double
    var timestamp: Timestamp
    var likes: [String] = [] // Array to store user IDs of people who liked the post
}

struct Feed: View {
    @ObservedObject var locationManager = LocationManager()
    @State private var posts: [Post] = []
    @State private var users: [String: String] = [:]
    @State private var isRefreshing = false
    @State private var allPostsViewed = false
    @State private var isLoading = false
    @State private var distanceFilter: Int = 10
    @State private var selectedChatId: ChatIdentifier? // Use ChatIdentifier instead of String
    @State private var isMessageCenterPresented = false
    @State private var unreadMessagesCount: Int = 0 // Unread messages count
    @State private var likedPosts: Set<String> = [] // Track liked posts for the current session

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("Wander")
                            .font(.custom("Noteworthy", size: 34))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                            .tracking(2)
                        Spacer()

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
                                    // Show unread count badge
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
                        .sheet(isPresented: $isMessageCenterPresented) {
                            MessagingCenterView(currentUserId: Auth.auth().currentUser?.uid ?? "")
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
                        // Show "You're all caught up!" message when no more posts are available
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
                                        NavigationLink(destination: UserPostsView(userId: post.userId)) {
                                            Text("Posted by: \(users[post.userId] ?? "Unknown")")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }

                                        Text("Location: \(post.locationName)")
                                            .font(.caption)
                                            .foregroundColor(.white)

                                        KFImage(URL(string: post.imageUrl))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture(count: 2) {
                                                    likePost(post) // Double tap gesture to like the picture
                                            }
                                        // Messaging Button
                                        HStack {
                                            Button(action: {
                                                likePost(post)
                                            }) {
                                                Image(systemName: likedPosts.contains(post.id) ? "heart.fill" : "heart")
                                                    .resizable()
                                                    .frame(width: 16, height: 16)
                                                    .foregroundColor(likedPosts.contains(post.id) ? .red : .gray)
                                            }
                                            .padding(.trailing, 8)
                                            Button("Send Test Notification") {
                                                NotificationManager.shared.sendLikeNotification(totalLikes: 5)
                                            }

                                            Button(action: {
                                                initiateChat(with: post.userId)
                                            }) {
                                                HStack(spacing: 4) {
                                                    Text("Message Artist")
                                                        .font(.system(size: 8, weight: .semibold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.blue.opacity(0.8))
                                                )
                                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 5)
                                    .background(Color.black)
                                    .onAppear {
                                        markPostAsViewed(post) // Mark post as viewed when it appears
                                    }
                                }
                            }
                            .padding(.top, 10) // Add some spacing between the header and content
                        }
                        .refreshable {
                            refreshFeed()
                        }
                    }

                }
                .fullScreenCover(item: $selectedChatId) { chatIdentifier in
                    // Get the receiverId by finding the other user in the chat (i.e., not the current user)
                    let otherUserId = chatIdentifier.userIds.first { $0 != Auth.auth().currentUser!.uid } ?? ""
                    ChatView(chatId: chatIdentifier.id, currentUserId: Auth.auth().currentUser!.uid, receiverId: otherUserId)
                }

            }
        }
        .onAppear {
            fetchUnreadMessages()
            fetchPosts()
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



    // Refresh feed functionality
    func refreshFeed() {
        print("Refreshing feed...")
        isRefreshing = true
        isLoading = true
        posts.removeAll() // Clear existing posts
        fetchPosts() // Re-fetch posts
        isRefreshing = false
    }

    // Fetch posts function
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
                fetchAllPosts()
                return
            }

            guard let data = snapshot?.data(), let viewedPosts = data["viewedPosts"] as? [String] else {
                print("No viewed posts found or user document does not exist, fetching all posts")
                fetchAllPosts()
                return
            }

            if viewedPosts.isEmpty {
                fetchAllPosts()
            } else {
                fetchUnviewedPosts(notIn: viewedPosts)
            }
        }
    }

    func fetchUnviewedPosts(notIn viewedPosts: [String]) {
        print("Fetching unviewed posts...")

        if viewedPosts.count > 10 {
            print("Viewed posts exceed 10, fetching all posts and filtering locally...")
            fetchAndFilterAllPosts(viewedPosts: viewedPosts)
        } else {
            Firestore.firestore().collection("posts")
                .whereField(FieldPath.documentID(), notIn: viewedPosts)
                .getDocuments { (snapshot, error) in
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
                              let latitude = data["latitude"] as? Double,
                              let longitude = data["longitude"] as? Double,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            continue
                        }

                        let locationName = data["locationName"] as? String ?? "Unknown location"

                        let post = Post(id: document.documentID,
                                        userId: userId,
                                        username: "Unknown",
                                        imageUrl: imageUrl,
                                        locationName: locationName,
                                        latitude: latitude,
                                        longitude: longitude,
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
    }

    func fetchAndFilterAllPosts(viewedPosts: [String]) {
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
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    continue
                }

                let locationName = data["locationName"] as? String ?? "Unknown location"

                if !viewedPosts.contains(document.documentID) {
                    let post = Post(id: document.documentID,
                                    userId: userId,
                                    username: "Unknown",
                                    imageUrl: imageUrl,
                                    locationName: locationName,
                                    latitude: latitude,
                                    longitude: longitude,
                                    timestamp: timestamp)

                    fetchedPosts.append(post)
                }
            }

            DispatchQueue.main.async {
                self.posts = fetchedPosts
                self.allPostsViewed = fetchedPosts.isEmpty
                self.isLoading = false
                self.fetchUsernames(for: fetchedPosts)
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
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    continue
                }

                let locationName = data["locationName"] as? String ?? "Unknown location"

                let post = Post(id: document.documentID,
                                userId: userId,
                                username: "Unknown",
                                imageUrl: imageUrl,
                                locationName: locationName,
                                latitude: latitude,
                                longitude: longitude,
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

        // Check if post is already liked
        if likedPosts.contains(post.id) {
            // If already liked, remove the like
            Firestore.firestore().collection("posts").document(post.id).updateData([
                "likes": FieldValue.arrayRemove([currentUserId])
            ])
            likedPosts.remove(post.id)
        } else {
            // If not liked, add the like
            Firestore.firestore().collection("posts").document(post.id).updateData([
                "likes": FieldValue.arrayUnion([currentUserId])
            ])
            likedPosts.insert(post.id)
        }
    }
}
