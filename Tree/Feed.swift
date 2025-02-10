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
        List(notifications.sorted(by: { $0.timestamp > $1.timestamp })) { notification in
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

struct ConditionalFrameModifier: ViewModifier {
    @State private var isLandscape: Bool? = nil
    let imageUrl: String

    func body(content: Content) -> some View {
        Group {
            if let isLandscape = isLandscape {
                if isLandscape {
                    content
                        .aspectRatio(contentMode: .fill) // Fill width, no stretching
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 0.95) // Bigger height
                        .clipped() // Remove overflow
                } else {
                    content
                        .aspectRatio(contentMode: .fit) // Keeps portrait images natural
                        .frame(width: UIScreen.main.bounds.width) // Full width
                }
            } else {
                content
                    .aspectRatio(contentMode: .fit) // Default before loading
                    .frame(width: UIScreen.main.bounds.width)
            }
        }
        .onAppear {
            if let url = URL(string: imageUrl) {
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let value):
                            let image = value.image
                            let aspectRatio = image.size.width / image.size.height
                            isLandscape = aspectRatio > 1
                        case .failure:
                            isLandscape = nil
                        }
                    }
                }
            }
        }
    }
}



struct ChatIdentifier: Identifiable {
    var id: String
    var userIds: [String] // Add userIds to keep track of users in the chat
}


struct Post: Identifiable, Codable {
    var id: String
    var userId: String
    var username: String
    var imageUrl: String
    var locationName: String
    var timestamp: Date
    var likes: [String] = []
}

struct Feed: View {
    @State private var posts: [Post] = []
    @State private var users: [String: String] = [:]
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
    
    @State private var listener: ListenerRegistration? // Firestore listener for unread messages
    
    @State private var following: [String] = [] // To keep track of followed users
    
    @State private var previouslyViewedPosts: [Post] = []

    @State private var isLoadingPreviouslyViewed: Bool = false

    @State private var shouldReloadFeed = UserDefaults.standard.bool(forKey: "shouldReloadFeed")
    
    @State private var shouldIgnoreOnAppear = false
    
    @StateObject private var viewModel = FeedViewModel()
    
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
                        
                        // Refresh Button - Positioned before the notification and message buttons
                        Button(action: {
                            print("[Debug] Refresh button tapped. Reloading Feed...")
                            loadFeed()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24) // Adjust size for consistency
                                .foregroundColor(.white)
                        }
                        
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
                    } else if posts.isEmpty && following.isEmpty {
                        // Show message when no one is followed
                        VStack {
                            Image(systemName: "person.2.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                                .padding(.bottom, 20)

                            Text("Start following users to see their posts on your Feed.")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                        }
                        .frame(maxHeight: .infinity)
                    } else if posts.isEmpty && allPostsViewed {
                        // Show previously viewed posts in the same feed format
                        if isLoadingPreviouslyViewed {
                            VStack {
                                ProgressView("Loading previously viewed posts...")
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                    .padding()
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack {
                                    ForEach(previouslyViewedPosts) { post in
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
                                                .modifier(ConditionalFrameModifier(imageUrl: post.imageUrl)) // Apply fix dynamically
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
                                    }
                                }
                                .padding(.top, 10)
                            }
                        }
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
                                        .frame(maxWidth: .infinity) // Ensures full width

                                        Text("Location: \(post.locationName)")
                                            .font(.caption)
                                            .foregroundColor(.white)

                                        KFImage(URL(string: post.imageUrl))
                                            .resizable()
                                            .modifier(ConditionalFrameModifier(imageUrl: post.imageUrl)) // Apply fix dynamically
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
                                    .frame(maxWidth: .infinity, alignment: .leading) // Ensures VStack does not restrict width
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
            
            viewModel.listenForFollowerRemoval() // Register observer
            
            
            NotificationCenter.default.removeObserver(self, name: Notification.Name("FeedShouldRefresh"), object: nil)
            
            NotificationCenter.default.addObserver(forName: Notification.Name("FeedShouldRefresh"), object: nil, queue: .main) { _ in
                print("[Debug] Received FeedShouldRefresh notification. Reloading Feed...")
                loadFeed()
            }
            let firstLaunch = UserDefaults.standard.bool(forKey: "firstLaunch")
                
            print("[Debug] onAppear triggered - firstLaunch: \(firstLaunch)")

            if firstLaunch {
                print("[Debug] Reloading Feed due to app restart...")
                loadFeed()
                UserDefaults.standard.set(false, forKey: "firstLaunch") // ✅ Reset flag after loading
            } else if posts.isEmpty {  // ✅ Only refresh if there are no posts in memory
                print("[Debug] Keeping current Feed, falling back to cached posts...")
                fetchFollowing { following in
                    fallbackToCachedPreviouslyViewedPosts(following: following)
                }
            } else {
                print("[Debug] Feed already loaded. Skipping refresh.")
            }
            
        }
    }


    func loadFeed() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Error] User not authenticated.")
            self.posts = []
            self.isLoading = false
            return
        }

        self.isLoading = true
        fetchFollowing { following in
            if following.isEmpty {
                print("[Info] User is not following anyone. Clearing feed.")
                self.posts = [] // ✅ Clear feed if no one is followed
                self.isLoading = false
                return
            }

            Firestore.firestore().collection("users").document(userId).getDocument { snapshot, error in
                if let error = error {
                    print("[Error] Failed to fetch viewedPosts: \(error.localizedDescription)")
                    self.posts = []
                    self.isLoading = false
                    return
                }

                let viewedPosts = snapshot?.data()?["viewedPosts"] as? [String] ?? []

                fetchUnseenPosts(following: following, viewedPosts: viewedPosts) { unseenPosts in
                    if unseenPosts.isEmpty {
                        print("[Info] No new posts, filtering cached posts...")
                        self.fallbackToCachedPreviouslyViewedPosts(following: following) // ✅ Pass the updated following list
                    } else {
                        print("[Info] Displaying unseen posts in the Feed.")
                        self.posts = unseenPosts
                        self.isLoading = false
                    }
                }
            }
        }
    }


    
    func fetchFollowing(completion: @escaping ([String]) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user")
            completion([])
            return
        }

        Firestore.firestore().collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching following list: \(error)")
                completion([])
                return
            }

            guard let data = snapshot?.data(), let following = data["following"] as? [String] else {
                print("No following list found.")
                completion([])
                return
            }

            completion(following)
        }
    }
    
    func fetchUnseenPosts(following: [String], viewedPosts: [String], completion: @escaping ([Post]) -> Void) {
        let batchSize = 10
        let batches = stride(from: 0, to: following.count, by: batchSize).map {
            Array(following[$0..<min($0 + batchSize, following.count)])
        }

        var unseenPosts: [Post] = []
        let group = DispatchGroup()

        for batch in batches {
            group.enter()
            Firestore.firestore().collection("posts")
                .whereField("userId", in: batch)
                .getDocuments { snapshot, error in
                    defer { group.leave() }

                    if let error = error {
                        print("[Error] Fetching posts for batch: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    for document in documents {
                        let data = document.data()
                        // Removed the unnecessary cast for document.documentID
                        let postId = document.documentID

                        guard let userId = data["userId"] as? String,
                              let imageUrl = data["imageUrl"] as? String,
                              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                            continue
                        }

                        if viewedPosts.contains(postId) { continue }

                        let locationName = data["locationName"] as? String ?? "Unknown location"
                        let post = Post(
                            id: postId,
                            userId: userId,
                            username: "Unknown",
                            imageUrl: imageUrl,
                            locationName: locationName,
                            timestamp: timestamp
                        )
                        unseenPosts.append(post)
                    }
                }
        }

        group.notify(queue: .main) {
            if unseenPosts.isEmpty {
                completion([])
                return
            }

            // Fetch usernames for the unseen posts before returning them
            self.fetchUsernames(for: unseenPosts) {
                let postsWithUsernames = unseenPosts.map { post in
                    Post(
                        id: post.id,
                        userId: post.userId,
                        username: self.users[post.userId] ?? "Unknown", // Update username from fetched data
                        imageUrl: post.imageUrl,
                        locationName: post.locationName,
                        timestamp: post.timestamp
                    )
                }
                completion(postsWithUsernames)
            }
        }
    }
    
    func fallbackToCachedPreviouslyViewedPosts(following: [String]) {
        loadCachedPreviouslyViewedPosts { cachedPosts in
            let filteredPosts = cachedPosts.filter { following.contains($0.userId) } // ✅ Only keep posts from followed users
            
            if filteredPosts.isEmpty {
                print("[Info] No valid cached posts after filtering.")
                self.posts = [] // Clear feed if no valid posts remain
            } else {
                print("[Info] Showing filtered cached posts.")
                self.posts = filteredPosts.shuffled()
            }

            self.isLoading = false
        }
    }


    func fetchPreviouslyViewedPosts(completion: @escaping ([Post]) -> Void) {
        if let cachedData = UserDefaults.standard.data(forKey: "cachedPreviouslyViewedPosts"),
           let cachedPosts = try? JSONDecoder().decode([Post].self, from: cachedData) {
            completion(cachedPosts)
        } else {
            print("[Info] No cached previously viewed posts.")
            completion([])
        }
    }
    
    func loadCachedPreviouslyViewedPosts(completion: @escaping ([Post]) -> Void) {
        if let cachedData = UserDefaults.standard.data(forKey: "cachedPreviouslyViewedPosts"),
           let cachedPosts = try? JSONDecoder().decode([Post].self, from: cachedData) {
            
            print("Loaded \(cachedPosts.count) cached previously viewed posts.")
            
            // Fetch usernames for these cached posts
            self.fetchUsernames(for: cachedPosts) {
                DispatchQueue.main.async {
                    // Map posts to include updated usernames from the global `users` dictionary
                    let updatedPosts = cachedPosts.map { post in
                        Post(
                            id: post.id,
                            userId: post.userId,
                            username: self.users[post.userId] ?? post.username, // Use updated username
                            imageUrl: post.imageUrl,
                            locationName: post.locationName,
                            timestamp: post.timestamp,
                            likes: post.likes
                        )
                    }
                    print("Updated previously viewed posts with usernames.")
                    completion(updatedPosts)
                }
            }
        } else {
            print("[Info] No cached previously viewed posts found.")
            completion([])
        }
    }

    func savePreviouslyViewedPostsToCache(_ newPosts: [Post]) {
        // Load existing cached posts first
        var cachedPosts: [Post] = []
        
        if let cachedData = UserDefaults.standard.data(forKey: "cachedPreviouslyViewedPosts"),
           let loadedPosts = try? JSONDecoder().decode([Post].self, from: cachedData) {
            cachedPosts = loadedPosts
        }

        // Ensure all posts include usernames before saving
        let postsWithUsernames = newPosts.map { post in
            Post(
                id: post.id,
                userId: post.userId,
                username: users[post.userId] ?? post.username, // Include username
                imageUrl: post.imageUrl,
                locationName: post.locationName,
                timestamp: post.timestamp,
                likes: post.likes
            )
        }

        // Merge new posts with cached ones, ensuring uniqueness
        let updatedPosts = (cachedPosts + postsWithUsernames).uniqued(by: \.id)

        print("[Debug] Updating cache with \(updatedPosts.count) previously viewed posts.")

        if let data = try? JSONEncoder().encode(updatedPosts) {
            UserDefaults.standard.set(data, forKey: "cachedPreviouslyViewedPosts")
            print("[Success] Cached \(updatedPosts.count) previously viewed posts.")
        } else {
            print("[Error] Failed to update cache.")
        }
    }

    
    func fetchUsernames(for posts: [Post], completion: (() -> Void)? = nil) {
        // Extract unique user IDs from posts
        let userIds = Array(Set(posts.map { $0.userId }))

        guard !userIds.isEmpty else {
            print("No user IDs to fetch.")
            completion?()
            return
        }

        let batchSize = 10
        let batches = stride(from: 0, to: userIds.count, by: batchSize).map {
            Array(userIds[$0..<min($0 + batchSize, userIds.count)])
        }

        var fetchedUsers: [String: String] = [:]
        let group = DispatchGroup()

        for batch in batches {
            group.enter()
            Firestore.firestore().collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { (snapshot, error) in
                    defer { group.leave() }

                    guard let documents = snapshot?.documents else {
                        print("Error fetching user documents: \(String(describing: error))")
                        return
                    }

                    for document in documents {
                        let data = document.data()
                        if let username = data["username"] as? String {
                            fetchedUsers[document.documentID] = username
                        }
                    }
                }
        }

        group.notify(queue: .main) {
            // Merge fetched usernames into the global `users` dictionary
            self.users.merge(fetchedUsers) { (_, new) in new }
            print("Fetched and merged \(fetchedUsers.count) usernames.")
            completion?()
        }
    }


    
    func appendUniquePosts(to target: inout [Post], from newPosts: [Post]) {
        let existingIds = Set(target.map { $0.id })
        let uniquePosts = newPosts.filter { !existingIds.contains($0.id) }
        target.append(contentsOf: uniquePosts)
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
                
                // Add post to cache immediately
                DispatchQueue.main.async {
                    self.appendUniquePosts(to: &self.previouslyViewedPosts, from: [post])
                    self.savePreviouslyViewedPostsToCache(self.previouslyViewedPosts)
                }
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
    
// Function to listen for real-time updates to unread messages
    func listenForUnreadMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let chatsRef = Firestore.firestore().collection("chats")
        listener = chatsRef.whereField("userIds", arrayContains: userId).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening for chat updates: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No chat documents found.")
                return
            }
            
            // Count chats with unread messages for the current user
            let unreadCount = documents.filter { document in
                let chatData = document.data()
                if let messages = chatData["messages"] as? [[String: Any]] {
                    return messages.contains { message in
                        let isRead = message["isRead"] as? Bool ?? true
                        let receiverId = message["receiverId"] as? String ?? ""
                        return !isRead && receiverId == userId
                    }
                }
                return false
            }.count
            
            DispatchQueue.main.async {
                self.unreadMessagesCount = unreadCount
            }
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
            case .authorized:
                print("Notifications already authorized.")
            case .provisional:
                print("Notifications provisionally authorized.")
            case .denied:
                print("Notifications were previously denied. Encourage the user to enable them in settings.")
            case .ephemeral:
                print("Notifications authorized for an ephemeral session.")
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
    
}

// Helper function to remove duplicates based on post ID
extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
