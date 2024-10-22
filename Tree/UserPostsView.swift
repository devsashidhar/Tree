import SwiftUI
import FirebaseFirestore
import Kingfisher


struct UserPostsView: View {
    var userId: String
    @State private var userPosts: [Post] = []
    @State private var username: String = "Unknown" // Default username value
    @State private var selectedImage: FullScreenImage? = nil // For full-screen image display

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
                        let latitude = data["latitude"] as? Double ?? 0.0
                        let longitude = data["longitude"] as? Double ?? 0.0
                        let timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
                        
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
