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
    @State private var recentlyBlockedUser: String? // Track the recently blocked user to allow immediate unblocking

    @State private var showFirstBlockConfirmation = false
    @State private var showSecondBlockConfirmation = false
    @State private var selectedUserIdToBlock: String? = nil
    
    @State private var selectedUserIdToFlag: String? // To track the user ID to flag
    @State private var showFlagConfirmation: Bool = false // To control the display of the flag confirmation alert
    
    @State private var selectedPostIdToFlag: String? = nil // Holds the post ID for flagging confirmation
    
    @State private var flaggedPosts: Set<String> = [] // Track flagged posts


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
                                ForEach(posts.filter { !blockedUsers.contains($0.userId) }) { post in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            NavigationLink(destination: UserPostsView(userId: post.userId)) {
                                                Text("Posted by: \(users[post.userId] ?? "Unknown")")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }

                                            Spacer()

                                            // Menu with three dots for additional actions
                                            Menu {
                                                // Block option
                                                Button(action: {
                                                    selectedUserIdToBlock = post.userId
                                                    showBlockConfirmation = true // Show block confirmation
                                                }) {
                                                    Label("Block", systemImage: "hand.raised.fill") // Hand icon for block
                                                }

                                                // Flag option
                                                    Button(action: {
                                                        if flaggedPosts.contains(post.id) {
                                                            // Unflag the post
                                                            flaggedPosts.remove(post.id)
                                                            unflagContent(post.id) // Optional: if you have an unflag function
                                                            print("Post unflagged. Current flagged posts: \(flaggedPosts)")
                                                        } else {
                                                            // Flag the post
                                                            flaggedPosts.insert(post.id)
                                                            selectedUserIdToFlag = post.userId
                                                            selectedPostIdToFlag = post.id
                                                            showFlagConfirmation = true // Show flag confirmation
                                                            flagContent(post.id, offendingUserId: post.userId)
                                                            print("Post flagged. Current flagged posts: \(flaggedPosts)")
                                                        }
                                                    }) {
                                                        // Conditionally show filled or outlined flag icon
                                                        if flaggedPosts.contains(post.id) {
                                                            Label("Flag", systemImage: "flag.fill") // Black filled flag
                                                                .foregroundColor(.black)
                                                        } else {
                                                            Label("Flag", systemImage: "flag") // Gray outlined flag
                                                                .foregroundColor(.gray)
                                                        }
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
                                        markPostAsViewed(post)
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
            fetchUnreadMessages()
            fetchPosts()
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
                "blockedUsers": FieldValue.arrayUnion([userId])
            ]) { error in
                if let error = error {
                    print("Error blocking user: \(error)")
                } else {
                    blockedUsers.append(userId) // Update local state
                    showBlockConfirmation = false // Show alert
                    selectedUserIdToBlock = nil // Clear the selected user ID
                }
            }
    }

    private func unblockUser(_ userId: String) {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            let userRef = Firestore.firestore().collection("users").document(currentUserId)
            
            userRef.updateData([
                "blockedUsers": FieldValue.arrayRemove([userId])
            ]) { error in
                if let error = error {
                    print("Error unblocking user: \(error)")
                } else {
                    blockedUsers.removeAll { $0 == userId } // Update local state
                }
            }
    }
    
    private func fetchBlockedUsers() {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            let userRef = Firestore.firestore().collection("users").document(currentUserId)

            userRef.getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching blocked users: \(error)")
                    return
                }
                if let data = snapshot?.data(), let blocked = data["blockedUsers"] as? [String] {
                    blockedUsers = blocked
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
                fetchAllPosts(blockedUsers: blockedUsers)
                return
            }

            guard let data = snapshot?.data() else {
                print("User document does not exist, fetching all posts")
                fetchAllPosts(blockedUsers: blockedUsers)
                return
            }

            // Fetch blocked users list from the user document
            let blockedUsers = data["blockedUsers"] as? [String] ?? []
            
            // Fetch viewed posts list from the user document
            let viewedPosts = data["viewedPosts"] as? [String] ?? []
            
            if viewedPosts.isEmpty {
                fetchAllPosts(blockedUsers: blockedUsers)
            } else {
                fetchUnviewedPosts(notIn: viewedPosts, blockedUsers: blockedUsers)
            }
        }
    }

    func fetchUnviewedPosts(notIn viewedPosts: [String], blockedUsers: [String]) {
        if viewedPosts.count > 10 {
            print("Viewed posts exceed 10, fetching all posts and filtering locally...")
            fetchAndFilterAllPosts(viewedPosts: viewedPosts, blockedUsers: blockedUsers)
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
                              !blockedUsers.contains(userId), // Exclude blocked users
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
    }

    func fetchAndFilterAllPosts(viewedPosts: [String], blockedUsers: [String]) {
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
                      !blockedUsers.contains(userId), // Exclude blocked users
                      let imageUrl = data["imageUrl"] as? String,
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

    func fetchAllPosts(blockedUsers: [String]) {
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
                      !blockedUsers.contains(userId), // Filter out posts from blocked users
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
