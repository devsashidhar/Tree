import SwiftUI
import FirebaseFirestore

struct UserPostsView: View {
    var userId: String
    @State private var userPosts: [Post] = []
    @State private var username: String = "User" // Default username value

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
                    }
                }
            }
        }
        .navigationTitle("Posts by \(username)") // Use the fetched username
        .onAppear {
            fetchUsername()
            fetchUserPosts()
        }
    }

    // Fetch the username based on the userId
    func fetchUsername() {
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                if let data = document.data(), let fetchedUsername = data["username"] as? String {
                    DispatchQueue.main.async {
                        self.username = fetchedUsername // Update the username state
                    }
                }
            } else {
                print("Error fetching username: \(String(describing: error))")
            }
        }
    }

    // Fetch posts by the userId
    func fetchUserPosts() {
        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    self.userPosts = documents.compactMap { document in
                        let data = document.data()
                        guard let userId = data["userId"] as? String,
                              let username = data["username"] as? String,
                              let imageUrl = data["imageUrl"] as? String,
                              let description = data["description"] as? String,
                              let latitude = data["latitude"] as? Double,
                              let longitude = data["longitude"] as? Double,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            return nil
                        }
                        return Post(id: document.documentID,
                                    userId: userId,
                                    username: username,
                                    imageUrl: imageUrl,
                                    description: description,
                                    latitude: latitude,
                                    longitude: longitude,
                                    timestamp: timestamp)
                    }
                }
            }
    }
}
