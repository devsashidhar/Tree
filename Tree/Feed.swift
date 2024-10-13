import SwiftUI
import FirebaseFirestore
import CoreLocation

struct Post: Identifiable {
    var id: String
    var userId: String
    var username: String
    var imageUrl: String
    var locationName: String // The location name entered by the user
    var latitude: Double
    var longitude: Double
    var timestamp: Timestamp
}

struct Feed: View {
    @ObservedObject var locationManager = LocationManager()
    @State private var posts: [Post] = []
    @State private var showUserPostsView = false
    @State private var selectedUserId: String = ""

    var body: some View {
        NavigationView {
            VStack {
                if posts.isEmpty {
                    Text("No posts to show.")
                } else {
                    List(posts) { post in
                        VStack(alignment: .leading, spacing: 10) {
                            // NavigationLink to user's profile view
                            NavigationLink(destination: UserPostsView(userId: post.userId)) {
                                Text("Posted by: \(post.username)")
                                    .font(.caption)
                                    .foregroundColor(.blue) // Make the username clickable
                            }

                            Text("Location: \(post.locationName)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            AsyncImage(url: URL(string: post.imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 300, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .onAppear {
                fetchPosts()
            }
            .navigationTitle("Nearby Posts") // Set a title for the navigation bar
        }
    }

    // Fetch posts first
    func fetchPosts() {
        print("Fetching posts from Firestore...")

        Firestore.firestore().collection("posts").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching documents: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found")
                return
            }

            print("Found \(documents.count) documents")

            var fetchedPosts: [Post] = []

            for document in documents {
                let data = document.data()
                print("Document data: \(data)")  // Log each document data for debugging

                guard let userId = data["userId"] as? String,
                      let imageUrl = data["imageUrl"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    print("Missing data in document: \(document.documentID)")
                    continue // Skip this document if critical data is missing
                }

                // Provide default value for missing location name
                let locationName = data["locationName"] as? String ?? "Unknown location"

                // Create a Post object with "Unknown" username initially
                let post = Post(id: document.documentID,
                                userId: userId,
                                username: "Unknown", // Default username
                                imageUrl: imageUrl,
                                locationName: locationName,
                                latitude: latitude,
                                longitude: longitude,
                                timestamp: timestamp)

                fetchedPosts.append(post)
            }

            print("Fetched posts: \(fetchedPosts.count)")

            DispatchQueue.main.async {
                self.posts = fetchedPosts
                fetchUsernames(for: fetchedPosts)
            }
        }
    }

    // Asynchronously fetch usernames after posts are loaded
    func fetchUsernames(for posts: [Post]) {
        for (index, post) in posts.enumerated() {
            Firestore.firestore().collection("users").document(post.userId).getDocument { (userSnapshot, error) in
                guard let userData = userSnapshot?.data(), let username = userData["username"] as? String else {
                    print("Failed to fetch username for userId: \(post.userId)")
                    return
                }

                // Update the username in the post
                DispatchQueue.main.async {
                    self.posts[index].username = username
                    print("Updated username for post \(post.id): \(username)")
                }
            }
        }
    }
}
