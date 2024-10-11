import SwiftUI
import FirebaseFirestore
import CoreLocation

// Define the Post struct with username and description
struct Post: Identifiable {
    var id: String
    var userId: String
    var username: String
    var imageUrl: String
    var description: String
    var latitude: Double
    var longitude: Double
    var timestamp: Timestamp
}

struct Feed: View {
    @ObservedObject var locationManager = LocationManager()
    @State private var posts: [Post] = []

    var body: some View {
        NavigationView {  // Wrap the feed in a NavigationView to enable navigation
            VStack {
                if let location = locationManager.location {
                    List(posts) { post in
                        VStack(alignment: .leading, spacing: 10) {
                            // NavigationLink to user's profile view
                            NavigationLink(destination: UserPostsView(userId: post.userId)) {
                                Text("Posted by: \(post.username)")
                                    .font(.caption)
                                    .foregroundColor(.blue) // Make the username clickable
                            }

                            if !post.description.isEmpty {
                                Text(post.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

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
                    .onAppear {
                        fetchNearbyPosts(location: location)
                    }
                } else {
                    Text("Getting your location...")
                        .padding()
                }
            }
            .onAppear {
                // Ensure posts are fetched when the view appears
                if posts.isEmpty {
                    if let location = locationManager.location {
                        fetchNearbyPosts(location: location)
                    }
                }
            }
            .navigationTitle("Nearby Posts") // Set a title for the navigation bar
        }
    }

    // Fetch posts and their corresponding usernames from Firestore
    func fetchNearbyPosts(location: CLLocation) {
        let maxDistance: Double = 10000 // 10 km radius
        Firestore.firestore().collection("posts").getDocuments { (snapshot, error) in
            guard let documents = snapshot?.documents else {
                print("Error fetching documents: \(String(describing: error))")
                return
            }

            var fetchedPosts: [Post] = [] // Temporarily hold posts

            let dispatchGroup = DispatchGroup() // To synchronize the asynchronous tasks

            for document in documents {
                let data = document.data()
                guard let userId = data["userId"] as? String,
                      let imageUrl = data["imageUrl"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    continue
                }

                // Calculate the distance
                let postLocation = CLLocation(latitude: latitude, longitude: longitude)
                let distance = location.distance(from: postLocation)

                if distance <= maxDistance {
                    dispatchGroup.enter() // Mark the start of an asynchronous task

                    // Fetch the username from the 'users' collection
                    Firestore.firestore().collection("users").document(userId).getDocument { (userSnapshot, error) in
                        var username = "Unknown"
                        if let userData = userSnapshot?.data() {
                            username = userData["username"] as? String ?? "Unknown"
                        }

                        let description = data["description"] as? String ?? ""

                        // Create the post only after fetching the username
                        let post = Post(id: document.documentID,
                                        userId: userId,
                                        username: username,
                                        imageUrl: imageUrl,
                                        description: description,
                                        latitude: latitude,
                                        longitude: longitude,
                                        timestamp: timestamp)

                        fetchedPosts.append(post)
                        dispatchGroup.leave() // Mark the end of this asynchronous task
                    }
                }
            }

            // When all asynchronous tasks are done, update the UI
            dispatchGroup.notify(queue: .main) {
                self.posts = fetchedPosts
            }
        }
    }
}
