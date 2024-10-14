import SwiftUI
import FirebaseFirestore
import CoreLocation
import Kingfisher

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
    @State private var users: [String: String] = [:] // Cache usernames by userId
    @State private var showUserPostsView = false
    @State private var selectedUserId: String = ""

    init() {
        // Customize Navigation Bar background and title text color
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.backgroundColor = UIColor.black
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        // Customize Tab Bar background color
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.backgroundColor = UIColor.black
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    var body: some View {
        NavigationView {
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
                .listRowBackground(Color.black) // Background for each post
                .padding(.vertical, 5)
            }
            .listStyle(PlainListStyle())
            .onAppear {
                fetchPosts()
            }
            .navigationTitle("Nearby Posts")
        }
        .background(Color.black.edgesIgnoringSafeArea(.all)) // Background for the whole view
    }

    func fetchPosts() {
        Firestore.firestore().collection("posts").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching documents: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found")
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
                fetchUsernames(for: fetchedPosts)
            }
        }
    }

    func fetchUsernames(for posts: [Post]) {
        let userIds = Set(posts.map { $0.userId })
        Firestore.firestore().collection("users")
            .whereField(FieldPath.documentID(), in: Array(userIds))
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
                    self.users = fetchedUsers
                }
            }
    }
}
