import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Kingfisher

// A struct to wrap the image URL and conform to Identifiable
struct FullScreenImage: Identifiable {
    var id = UUID() // Conform to Identifiable with a unique ID
    var url: String // The image URL
}

struct AccountView: View {
    @State private var userPosts: [Post] = []
    @State private var userId: String = Auth.auth().currentUser?.uid ?? "" // Fetch the current user's ID
    @State private var username: String = "Unknown" // Default username value
    @State private var selectedImage: FullScreenImage? = nil // For showing the full-screen image
    @State private var isLoading = true // Loading state
    @State private var showDeleteConfirmation = false // Track if delete confirmation alert is shown

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ] // 2-column grid

    var body: some View {
        ZStack {
            // Show a black background
            Color.black.ignoresSafeArea()

            if isLoading {
                // Show white loading spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2) // Make the spinner larger
            } else {
                VStack(spacing: 0) {
                    // Title and settings button in HStack for alignment
                    HStack {
                        Spacer()
                        
                        Text("Your Gallery")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity) // Center align title within the HStack
                        
                        Spacer()
                        
                        // Settings button with menu
                        Menu {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Account", systemImage: "trash")
                            }
                            // Sign-Out Option
                            Button(action: {
                                handleSignOut()
                            }) {
                                Label("Sign Out", systemImage: "arrowshape.turn.up.left")
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                                .font(.system(size: 20)) // Smaller size for subtle appearance
                        }
                        .padding(.trailing, 5) // Adjust padding for alignment with title
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Subtitle with additional padding below the title
                    Text("Tap to expand each image")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                        .padding(.top, 4) // Add slight space below the title
                        .padding(.bottom, 20) // Add space between the subtitle and the pictures

                    if userPosts.isEmpty {
                        VStack {
                            Text("🏞️")
                                .font(.system(size: 60))
                                .padding(.bottom, 10)

                            Text("Upload pictures to show up here")
                                .foregroundColor(.gray)
                                .font(.system(size: 18, weight: .medium))
                                .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(userPosts) { post in
                                    ZStack(alignment: .topLeading) {
                                        KFImage(URL(string: post.imageUrl))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: UIScreen.main.bounds.width / 2 - 15, height: UIScreen.main.bounds.width / 2 - 15)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .onTapGesture {
                                                selectedImage = FullScreenImage(url: post.imageUrl)
                                            }

                                        HStack(spacing: 4) {
                                            Text("\(post.likes.count)")
                                                .font(.caption)
                                                .foregroundColor(.white)

                                            Image(systemName: "heart.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 12, height: 12)
                                                .foregroundColor(.red)
                                        }
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(5)
                                        .padding([.top, .leading], 8)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                        .frame(maxHeight: .infinity, alignment: .top) // Force the grid to align at the top
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top) // Force the entire VStack to align at the top
            }
        }
        .onAppear {
            fetchUserPosts()
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Account"),
                message: Text("Are you sure you want to permanently delete your account? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete"), action: deleteAccount),
                secondaryButton: .cancel()
            )
        }
        .fullScreenCover(item: $selectedImage, content: { fullScreenImage in
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
        })
    }

    func handleSignOut() {
        do {
            try Auth.auth().signOut()
            // Navigate back to the SignInView
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                if let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: SignInView())
                    window.makeKeyAndVisible()
                }
            }
        } catch {
            print("Failed to sign out: \(error.localizedDescription)")
        }
    }

    func deleteAccount() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Step 1: Delete all posts made by the user
        deleteUserPosts(for: userId) { error in
            if let error = error {
                print("Error deleting user posts: \(error)")
                return
            }
            
            // Step 2: Delete the user document from Firestore
            Firestore.firestore().collection("users").document(userId).delete { error in
                if let error = error {
                    print("Error deleting user document: \(error)")
                    return
                }
                
                // Step 3: Delete the Firebase Auth account
                Auth.auth().currentUser?.delete { authError in
                    if let authError = authError {
                        print("Error deleting user from Firebase Auth: \(authError)")
                    } else {
                        // Navigate to the FarewellView after successful deletion
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            if let window = windowScene.windows.first {
                                window.rootViewController = UIHostingController(rootView: FarewellView())
                                window.makeKeyAndVisible()
                            }
                        }
                    }
                }
            }
        }
    }

    
    func deleteUserPosts(for userId: String, completion: @escaping (Error?) -> Void) {
        let postsRef = Firestore.firestore().collection("posts")
        
        postsRef.whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(nil) // No posts found, so we're done
                return
            }
            
            let batch = Firestore.firestore().batch()
            
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { batchError in
                if let batchError = batchError {
                    completion(batchError)
                } else {
                    completion(nil) // Successfully deleted all posts
                }
            }
        }
    }


    // Fetch posts by the current user's userId
    func fetchUserPosts() {
        print("Fetching posts for userId: \(userId)")

        Firestore.firestore().collection("posts")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No posts found for userId: \(userId)")
                    isLoading = false
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
                        
                        let timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
                        let likes = data["likes"] as? [String] ?? [] // Fetch the likes array from Firestore

                        // Create a Post object without username initially
                        let post = Post(id: document.documentID,
                                        userId: userId,
                                        username: "Unknown", // Placeholder for now
                                        imageUrl: imageUrl,
                                        locationName: locationName,
                                        timestamp: timestamp,
                                        likes: likes) // Include likes here)

                        fetchedPosts.append(post)
                    }

                    self.userPosts = fetchedPosts
                    self.isLoading = false // Stop showing the loading spinner
                    fetchUsername() // Fetch the username after fetching posts
                }
            }
    }

    // Fetch the current user's username based on the userId
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

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}
