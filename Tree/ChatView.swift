import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    let chatId: String
    let currentUserId: String
    let receiverId: String
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToUserPosts = false // State variable for navigation
    @State private var messages: [Message] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = true
    @State private var userNames: [String: String] = [:] // Store usernames by user ID
    @State private var isBlocked: Bool = false // Track if the user is blocked
    @State private var blockStatusChecked: Bool = false // Indicate if block status was checked
    @State private var blockDocumentId: String? = nil // Use optional String to allow setting it to nil


    var body: some View {
        NavigationStack {
            VStack {
                // Custom Back Button and "View Posts" button in the toolbar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .padding()
                    
                    Spacer()

                    // Circular icon with initials and full username text next to it
                    if let username = userNames[receiverId] {
                        HStack(spacing: 8) {
                            // Circular button with initials
                            Button(action: {
                                // Trigger navigation to UserPostsView
                                navigateToUserPosts = true
                            }) {
                                Text(username.prefix(2).uppercased()) // Show initials
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            
                            // Display full username next to the initials button
                            Text(username)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    } else {
                        // Default view if username is not available
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.blue)
                    }

                    Spacer()
                }
                .padding(.top) // Add padding to adjust vertical alignment

                // Display messages or blocked status
                if isLoading {
                    ProgressView("Loading messages...")
                } else if isBlocked && blockStatusChecked {
                    Text("You cannot message this user.")
                        .foregroundColor(.gray)
                        .padding()

                    if blockDocumentId != nil {
                        Button(action: {
                            unblockUser()
                        }) {
                            Text("Unblock User")
                                .foregroundColor(.blue)
                                .padding()
                        }
                    }
                } else {
                    ScrollView {
                        ForEach(messages) { message in
                            HStack {
                                if message.senderId == currentUserId {
                                    Spacer()
                                    Text(message.text)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                } else {
                                    Text(message.text)
                                        .padding()
                                        .background(Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Message input and send button
                if !isBlocked && blockStatusChecked {
                    HStack {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                    }
                    .padding()
                }

                // Block User button (only show if not already blocked)
                if !isBlocked {
                    Button(action: {
                        blockUser()
                    }) {
                        Text("Block User")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
            .onAppear {
                fetchMessages()
                fetchUsername()
                checkIfBlocked()
            }
            .navigationDestination(isPresented: $navigateToUserPosts) {
                UserPostsView(userId: receiverId)
            }
        }
    }

    private func fetchMessages() {
        ChatService().fetchMessages(forChatId: chatId) { result in
            switch result {
            case .success(let fetchedMessages):
                self.messages = fetchedMessages
                self.isLoading = false
                markMessagesAsRead(for: fetchedMessages.filter { $0.senderId != currentUserId })
            case .failure(let error):
                print("Error fetching messages: \(error)")
                self.isLoading = false
            }
        }
    }

    private func fetchUsername() {
        Firestore.firestore().collection("users").document(receiverId).getDocument { (document, error) in
            if let document = document, document.exists, let data = document.data() {
                if let username = data["username"] as? String {
                    DispatchQueue.main.async {
                        self.userNames[receiverId] = username
                    }
                }
            } else {
                print("User document not found or error: \(String(describing: error))")
            }
        }
    }

    private func markMessagesAsRead(for messages: [Message]) {
        ChatService().markMessagesAsRead(inChat: chatId, forUserId: currentUserId)
    }

    private func sendMessage() {
        if !messageText.isEmpty {
            ChatService().sendMessage(inChat: chatId, senderId: currentUserId, receiverId: receiverId, text: messageText) { result in
                switch result {
                case .success(let message):
                    self.messages.append(message)
                    self.messageText = ""
                case .failure(let error):
                    print("Error sending message: \(error)")
                }
            }
        }
    }

    // Block the other user
    private func blockUser() {
        let db = Firestore.firestore()
        let blockedRef = db.collection("blockedUsers").document()

        let data: [String: Any] = [
            "blockerId": currentUserId,
            "blockedId": receiverId
        ]

        blockedRef.setData(data) { error in
            if let error = error {
                print("Error blocking user: \(error.localizedDescription)")
            } else {
                print("User successfully blocked.")
                isBlocked = true
                blockDocumentId = blockedRef.documentID // Store document ID for unblocking
            }
        }
    }

    // Unblock the other user
    private func unblockUser() {
        guard let blockDocumentId = blockDocumentId else { return }

        let db = Firestore.firestore()
        db.collection("blockedUsers").document(blockDocumentId).delete { error in
            if let error = error {
                print("Error unblocking user: \(error.localizedDescription)")
            } else {
                print("User successfully unblocked.")
                isBlocked = false
                self.blockDocumentId = nil // Clear document ID after unblocking
            }
        }
    }


    private func checkIfBlocked() {
        let db = Firestore.firestore()
        
        // Check if the current user has blocked the receiver
        db.collection("blockedUsers")
            .whereField("blockerId", isEqualTo: currentUserId)
            .whereField("blockedId", isEqualTo: receiverId)
            .getDocuments { snapshot, error in
                if let document = snapshot?.documents.first {
                    // The current user has blocked the receiver
                    self.isBlocked = true
                    self.blockDocumentId = document.documentID // Store document ID for potential unblocking
                    self.blockStatusChecked = true // Mark block status as checked
                } else {
                    // Reset blockDocumentId if User A hasn't blocked User B
                    self.blockDocumentId = nil
                    
                    // Check if the receiver has blocked the current user
                    db.collection("blockedUsers")
                        .whereField("blockerId", isEqualTo: receiverId)
                        .whereField("blockedId", isEqualTo: currentUserId)
                        .getDocuments { snapshot, error in
                            if let snapshot = snapshot, !snapshot.isEmpty {
                                // The receiver has blocked the current user
                                self.isBlocked = true
                            } else {
                                // No block in either direction, allow messaging
                                self.isBlocked = false
                            }
                            // Mark the block status check as completed
                            self.blockStatusChecked = true
                        }
                }
            }
    }



}
