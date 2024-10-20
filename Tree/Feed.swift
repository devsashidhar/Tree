import SwiftUI
import FirebaseFirestore
import CoreLocation
import Kingfisher
import FirebaseAuth

struct Post: Identifiable {
    var id: String
    var userId: String
    var username: String
    var imageUrl: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var timestamp: Timestamp
}

struct Feed: View {
    @ObservedObject var locationManager = LocationManager()
    @State private var posts: [Post] = []
    @State private var users: [String: String] = [:] // Cache usernames by userId
    @State private var isRefreshing = false
    @State private var allPostsViewed = false // Track if all posts are viewed
    @State private var isLoading = false // Track if loading
    @State private var distanceFilter: Int = 10 // Default to 10 miles

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all) // Keep background black

                VStack(spacing: 0) {
                    // Custom Header (fixed)
                    HStack {
                        Text("Wander")
                            .font(.custom("AvenirNext-Bold", size: 34)) // Custom font with larger size
                            .foregroundColor(.white)
                            .shadow(color: .gray, radius: 2, x: 0, y: 2) // Add shadow for depth
                            .tracking(2) // Add spacing between letters
                        Spacer()
                        Button(action: {
                            // Action for the distance filter (add your logic here)
                            print("Distance filter pressed")
                        }) {
                            Image(systemName: "location.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black) // Ensure the title bar is black

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
            }
        }
        .onAppear {
            fetchPosts()
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
}
