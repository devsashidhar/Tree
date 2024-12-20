import SwiftUI
import FirebaseFirestore
import Kingfisher
import FirebaseAuth


struct UserPostsView: View {
    var userId: String
    @State private var userPosts: [Post] = []
    @State private var username: String = "Unknown" // Default username value
    @State private var selectedImage: FullScreenImage? = nil // For full-screen image display
    
    @EnvironmentObject var followManager: FollowManager

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ] // 2-column grid layout

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Set background to black
            VStack(spacing: 10) {
                // Title and subtitle
                VStack {
                    Text("\(username)'s Gallery")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .bold)) // Large title
                        .padding(.top, 20)

                    Text("Tap to expand each image")
                        .foregroundColor(.gray)
                        .font(.system(size: 16)) // Smaller subtitle
                        .padding(.bottom, 10)
                    
                    if followManager.following.contains(userId) {
                        Button(action: {
                            removeFollower(newFollowerId: userId)
                        }) {
                            Text("Following")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(6)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(BorderlessButtonStyle()) // Prevent navigation when clicking the button
                    } else {
                        Button(action: {
                            addFollower(newFollowerId: userId)
                        }) {
                            Text("Follow")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(BorderlessButtonStyle()) // Prevent navigation when clicking the button
                    }
                }
            if userPosts.isEmpty {
                Text("No posts available for this user.")
                    .foregroundColor(.gray)
                    .font(.system(size: 18, weight: .medium))
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(userPosts) { post in
                            KFImage(URL(string: post.imageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width / 2 - 15, height: UIScreen.main.bounds.width / 2 - 15)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture {
                                    selectedImage = FullScreenImage(url: post.imageUrl)
                                }
                        }
                    }
                    .padding()
                }
                }
            }
        }
        .navigationTitle("Posts by \(username)") // Show the user's name in the title
        .onAppear {
            fetchUserPosts()
        }
        .fullScreenCover(item: $selectedImage) { fullScreenImage in
            ZStack {
                Color.black.ignoresSafeArea()
                
                KFImage(URL(string: fullScreenImage.url))
                    .resizable()
                    .scaledToFit()

                VStack {
                    HStack {
                        Button(action: {
                            selectedImage = nil
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
    }

    private func addFollower(newFollowerId: String) {
        let userId = Auth.auth().currentUser?.uid ?? ""

        let userRef = Firestore.firestore().collection("users").document(userId)

        userRef.updateData([
            "following": FieldValue.arrayUnion([newFollowerId])
        ]) { error in
            if let error = error {
                print("Error updating following list: \(error)")
            } else {
                print("Successfully updated following list with: \(newFollowerId)")
                DispatchQueue.main.async {
                    followManager.following.insert(newFollowerId) // Update local state to reflect UI changes
                }
            }
        }
    }
    
    
    private func removeFollower(newFollowerId: String) {
        let userId = Auth.auth().currentUser?.uid ?? ""

        let userRef = Firestore.firestore().collection("users").document(userId)

        userRef.updateData([
            "following": FieldValue.arrayRemove([newFollowerId])
        ]) { error in
            if let error = error {
                print("Error updating following list: \(error)")
            } else {
                print("Successfully updated following list with: \(newFollowerId)")
                DispatchQueue.main.async {
                    followManager.following.remove(newFollowerId) // Update local state to reflect UI changes
                }
            }
        }
    }
    
    // Fetch posts for the given userId
    func fetchUserPosts() {
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
                        guard let imageUrl = data["imageUrl"] as? String else { continue }
                        let locationName = data["locationName"] as? String ?? "Unknown Location"
                        let timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
                        
                        let post = Post(id: document.documentID,
                                        userId: userId,
                                        username: "Unknown",
                                        imageUrl: imageUrl,
                                        locationName: locationName,
                                        timestamp: timestamp)
                        fetchedPosts.append(post)
                    }
                    self.userPosts = fetchedPosts
                    fetchUsername()
                }
            }
    }

    // Fetch the username of the post owner
    func fetchUsername() {
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                if let fetchedUsername = data?["username"] as? String {
                    DispatchQueue.main.async {
                        self.username = fetchedUsername
                        self.userPosts = self.userPosts.map { post in
                            var updatedPost = post
                            updatedPost.username = fetchedUsername
                            return updatedPost
                        }
                    }
                } else {
                    self.username = "Unknown"
                }
            } else {
                self.username = "Unknown"
            }
        }
    }
}
