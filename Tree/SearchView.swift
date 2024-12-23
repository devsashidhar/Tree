import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SearchView: View {
    @State private var searchQuery: String = ""
    @State private var searchResults: [User] = []
    @State private var isLoading: Bool = false
    @State private var following: Set<String> = [] // Track users already followed for UI updates
    
    @EnvironmentObject var followManager: FollowManager

    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    TextField("Search by username", text: $searchQuery, onCommit: performSearch)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .autocapitalization(.none)
                        .foregroundColor(.white) // Text in search bar
                        .background(Color.gray.opacity(0.2)) // Search bar background
                        .cornerRadius(8) // Rounded corners
                        .onChange(of: searchQuery) {
                            performSearch() // Perform search whenever the query changes
                        }
                    if isLoading {
                        ProgressView()
                            .padding(.trailing)
                            .foregroundColor(.white) // Progress indicator in white
                    }
                }
                .padding(.top)

                // Results list
                List(searchResults) { user in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 1) // White border
                            .background(Color.black) // Black background
                            .cornerRadius(10)

                        HStack {
                            // Wrap username and name in the NavigationLink
                            NavigationLink(destination: UserPostsView(userId: user.id)) {
                                VStack(alignment: .leading) {
                                    Text(user.username)
                                        .font(.headline)
                                        .foregroundColor(.white) // Username text in white

                                    if let firstName = user.firstName, let lastName = user.lastName {
                                        Text("\(firstName) \(lastName)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray) // Subtitle in gray
                                    }
                                }
                            }

                            Spacer()

                            // Follow/Following button logic outside the NavigationLink
                            if following.contains(user.id) {
                                Button(action: {
                                    removeFollower(newFollowerId: user.id)
                                }) {
                                    Text("Following")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(8) // Comfortable padding
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(BorderlessButtonStyle()) // Prevent navigation when clicking the button
                            } else {
                                Button(action: {
                                    addFollower(newFollowerId: user.id)
                                }) {
                                    Text("Follow")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(8) // Comfortable padding
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(BorderlessButtonStyle()) // Prevent navigation when clicking the button
                            }
                        }
                        .padding(.horizontal, 16) // Add horizontal padding inside the box
                        .padding(.vertical, 12)  // Add vertical padding inside the box
                    }
                    .listRowInsets(EdgeInsets()) // Remove default list row padding
                    .padding(.vertical, 5) // Add spacing between rows
                }
                .scrollContentBackground(.hidden) // Hide default list background
            }
            .background(Color.black.edgesIgnoringSafeArea(.all)) // Set background color to black
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.white) // Ensure the navigation title is white
            .onAppear {
                fetchFollowing() // Fetch following list on appear
            }
        }
        .preferredColorScheme(.dark) // Force dark mode
    }


    private func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true

        let db = Firestore.firestore()
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: searchQuery)
            .whereField("username", isLessThanOrEqualTo: searchQuery + "\u{f8ff}")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        print("Error searching users by username: \(error.localizedDescription)")
                        self.searchResults = [] // Clear results on error
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.searchResults = [] // Clear results if no documents
                        return
                    }

                    self.searchResults = documents.compactMap { document in
                        parseUserData(data: document.data(), id: document.documentID)
                    }
                }
            }
    }

    private func parseUserData(data: [String: Any], id: String) -> User? {
        guard let username = data["username"] as? String else { return nil }
        let firstName = data["firstName"] as? String
        let lastName = data["lastName"] as? String
        return User(id: id, username: username, firstName: firstName, lastName: lastName)
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
                    following.insert(newFollowerId) // Update local state to reflect UI changes
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
                    following.remove(newFollowerId) // Update local state to reflect UI changes
                }
            }
        }
    }

    private func fetchFollowing() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.getDocument { snapshot, error in
            if let error = error {
                print("Error fetching following list: \(error)")
                return
            }

            if let data = snapshot?.data(), let followingList = data["following"] as? [String] {
                DispatchQueue.main.async {
                    self.following = Set(followingList)
                }
            }
        }
    }
}

struct User: Identifiable {
    var id: String
    var username: String
    var firstName: String?
    var lastName: String?
}
