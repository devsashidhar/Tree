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
                    if isLoading {
                        ProgressView()
                            .padding(.trailing)
                    }
                }
                .padding(.top)

                // Results list
                List(searchResults) { user in
                    HStack {
                        // Wrap only the username and name in the NavigationLink
                        NavigationLink(destination: UserPostsView(userId: user.id)) {
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                
                                if let firstName = user.firstName, let lastName = user.lastName {
                                    Text("\(firstName) \(lastName)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
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
                                    .foregroundColor(.gray)
                                    .padding(6)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Prevent navigation when clicking the button
                        } else {
                            Button(action: {
                                addFollower(newFollowerId: user.id)
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
                }
            }
            .navigationTitle("Search")
            .onAppear {
                fetchFollowing()
            }
        }
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
                isLoading = false
                if let error = error {
                    print("Error searching users by username: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.searchResults = []
                    return
                }

                self.searchResults = documents.compactMap { document in
                    parseUserData(data: document.data(), id: document.documentID)
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
