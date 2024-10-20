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
    @State private var allPostsViewed = false // New state to track if all posts are viewed

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all) // Ensure the background is always black

                if posts.isEmpty && allPostsViewed {
                    // Show the "You're all caught up!" message only when all posts are viewed
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

                        Text("No more nature posts to view at the moment")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, -10)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: posts.isEmpty)
                } else {
                    // Show the list of posts
                    List(posts) { post in
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
                        .listRowBackground(Color.black)
                        .padding(.vertical, 5)
                        .onAppear {
                            markPostAsViewed(post) // Mark the post as viewed when it appears
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        refreshFeed()
                    }
                }
            }
            .navigationTitle("Nearby Posts")
            .onAppear {
                fetchPosts()
            }
        }
    }

    // Pull-to-refresh functionality
    func refreshFeed() {
        print("Refreshing feed...")
        isRefreshing = true
        posts.removeAll() // Clear existing posts
        fetchPosts() // Re-fetch posts
        isRefreshing = false
    }

    // Fetch posts
    func fetchPosts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user")
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

            // If there are no viewed posts, fetch all posts
            if viewedPosts.isEmpty {
                fetchAllPosts()
            } else {
                fetchUnviewedPosts(notIn: viewedPosts)
            }
        }
    }

    func fetchUnviewedPosts(notIn viewedPosts: [String]) {
        print("Fetching unviewed posts...")

        // If viewedPosts exceeds 10, we can't use 'notIn' query directly
        if viewedPosts.count > 10 {
            print("Viewed posts exceed 10, fetching all posts and filtering locally...")
            fetchAndFilterAllPosts(viewedPosts: viewedPosts)
        } else {
            // If viewedPosts are 10 or less, proceed with 'notIn' query
            Firestore.firestore().collection("posts")
                .whereField(FieldPath.documentID(), notIn: viewedPosts)
                .getDocuments { (snapshot, error) in
                    if let error = error {
                        print("Error fetching posts: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        print("No documents found")
                        allPostsViewed = true // No more unviewed posts found
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
                        self.allPostsViewed = fetchedPosts.isEmpty // Check if no new posts were fetched
                        self.fetchUsernames(for: fetchedPosts)
                    }
                }
        }
    }

    func fetchAndFilterAllPosts(viewedPosts: [String]) {
        Firestore.firestore().collection("posts").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching posts: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found")
                allPostsViewed = true // No more unviewed posts found
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

                // Filter out posts that are in viewedPosts
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
                self.allPostsViewed = fetchedPosts.isEmpty // Check if no new posts were fetched
                self.fetchUsernames(for: fetchedPosts)
            }
        }
    }

    // Fetch all posts (for new users or users without viewedPosts)
    func fetchAllPosts() {
        print("Fetching all posts...")
        Firestore.firestore().collection("posts").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching posts: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found")
                allPostsViewed = true // No more posts found
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
                self.allPostsViewed = fetchedPosts.isEmpty // Check if no posts were fetched
                self.fetchUsernames(for: fetchedPosts)
            }
        }
    }

    // Fetch usernames for the posts
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

    // Mark a post as viewed when it appears
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
