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

                    // Circular icon button with username
                    Button(action: {
                        // Trigger navigation to UserPostsView
                        navigateToUserPosts = true
                    }) {
                        if let username = userNames[receiverId] {
                            Text(username.prefix(2).uppercased()) // Show initials or full username
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.blue)
                                .clipShape(Circle())
                        } else {
                            // Default view if username is not available
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal) // Adjust padding to center icon more precisely
                    .alignmentGuide(.leading) { _ in -20 } // Adjust to shift icon slightly left

                    Spacer()
                }
                .padding(.top) // Add padding to adjust vertical alignment

                if isLoading {
                    ProgressView("Loading messages...")
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
            .onAppear {
                fetchMessages()
                fetchUsername() // Fetch username when the view appears
            }
            // Use navigationDestination with the state variable to navigate to UserPostsView
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
        // Assume you have a service or Firestore call to get the username by user ID
        Firestore.firestore().collection("users").document(receiverId).getDocument { (document, error) in
            if let document = document, document.exists, let data = document.data() {
                if let username = data["username"] as? String {
                    DispatchQueue.main.async {
                        self.userNames[receiverId] = username // Store the username for receiverId
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
}
