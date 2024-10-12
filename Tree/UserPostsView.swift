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
        print("Fetching username for userId: \(userId)")  // Log the userId being queried
        
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                print("Fetched username data: \(String(describing: data))")  // Log the fetched username data
                if let data = data, let fetchedUsername = data["username"] as? String {
                    DispatchQueue.main.async {
                        self.username = fetchedUsername // Update the username state
                    }
                }
            } else {
                print("Error fetching username: \(String(describing: error))")
            }
        }
    }

    func fetchUserPosts() {
        print("Fetching posts for userId: \(userId)")  // Log userId for verification

        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("No documents found or error: \(String(describing: error))")
                    return
                }

                DispatchQueue.main.async {
                    self.userPosts = documents.compactMap { document in
                        let data = document.data()
                        print("Document data: \(data)")  // Log each document data for debugging
                        
                        guard let userId = data["userId"] as? String,
                              let imageUrl = data["imageUrl"] as? String,
                              let latitude = data["latitude"] as? Double,
                              let longitude = data["longitude"] as? Double,
                              let timestamp = data["timestamp"] as? Timestamp else {
                            return nil
                        }
                        
                        // Provide a default value if the description is missing
                        let description = data["description"] as? String ?? ""

                        // Use the fetched username from `fetchUsername()` function
                        return Post(id: document.documentID,
                                    userId: userId,
                                    username: self.username, // Use the already fetched username
                                    imageUrl: imageUrl,
                                    description: description, // Handle missing description
                                    latitude: latitude,
                                    longitude: longitude,
                                    timestamp: timestamp)
                    }
                    
                    if self.userPosts.isEmpty {
                        print("No posts found for this user")
                    }
                }
            }
    }
}
