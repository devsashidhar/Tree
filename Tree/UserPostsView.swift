import SwiftUI
import FirebaseFirestore

struct UserPostsView: View {
    var userId: String
    @State private var userPosts: [Post] = []
    @State private var username: String = "Unknown" // Default username value

    var body: some View {
        VStack {
            if userPosts.isEmpty {
                Text("No posts available for this user.")
                    .padding()
            } else {
                List(userPosts) { post in
                    VStack {
                        AsyncImage(url: URL(string: post.imageUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // Show location name
                        Text("Location: \(post.locationName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Posts by \(username)") // Use the fetched username
        .onAppear {
            fetchUserPosts() // Fetch posts first, then the username
        }
    }

    // Fetch posts by the userId
    func fetchUserPosts() {
        print("Fetching posts for userId: \(userId)")

        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No posts found for userId: \(userId)")
                    return
                }

                DispatchQueue.main.async {
                    var fetchedPosts: [Post] = []

                    for document in documents {
                        let data = document.data()
                        print("Post data for userId \(userId): \(data)")  // Log each document data for debugging
                        
                        guard let imageUrl = data["imageUrl"] as? String else {
                            print("Skipping post due to missing imageUrl: \(document.documentID)")
                            continue // Skip this document if critical data like imageUrl is missing
                        }

                        // Handle missing location name and provide a default value
                        let locationName = data["locationName"] as? String ?? "Unknown Location"
                        
                        // Handle other fields, providing default values where needed
                        let latitude = data["latitude"] as? Double ?? 0.0
                        let longitude = data["longitude"] as? Double ?? 0.0
                        let timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())

                        // Create a Post object without username initially
                        let post = Post(id: document.documentID,
                                        userId: userId,
                                        username: "Unknown", // Placeholder for now
                                        imageUrl: imageUrl,
                                        locationName: locationName,
                                        latitude: latitude,
                                        longitude: longitude,
                                        timestamp: timestamp)

                        fetchedPosts.append(post)
                    }

                    self.userPosts = fetchedPosts
                    print("Fetched posts count: \(self.userPosts.count)")
                    fetchUsername() // Fetch the username after fetching posts
                }
            }
    }

    // Fetch the username based on the userId
    func fetchUsername() {
        print("Fetching username for userId: \(userId)")
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                print("Fetched username data: \(String(describing: data))")

                if let fetchedUsername = data?["username"] as? String {
                    DispatchQueue.main.async {
                        self.username = fetchedUsername // Update the username state
                        // Update the username for the posts
                        self.userPosts = self.userPosts.map { post in
                            var updatedPost = post
                            updatedPost.username = fetchedUsername
                            return updatedPost
                        }
                    }
                } else {
                    print("Username not found for userId: \(userId)")
                    self.username = "Unknown" // Fallback if username is missing
                }
            } else {
                print("Error fetching username or document does not exist: \(String(describing: error))")
                self.username = "Unknown" // Fallback if Firestore fails
            }
        }
    }
}
