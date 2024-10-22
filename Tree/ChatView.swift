import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    let chatId: String
    let currentUserId: String
    let receiverId: String // Added receiverId to handle message sending properly

    @State private var messages: [Message] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = true
    @State private var userNames: [String: String] = [:] // Cache of userIds and usernames

    var body: some View {
        VStack {
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
                                Text("\(userNames[message.senderId] ?? "Unknown") says: \(message.text)") // Fetch correct username
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
                    sendMessage() // Send the message
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
        }
    }

    private func fetchMessages() {
        // Debugging: Print the chat ID we're fetching messages for
        print("DEBUG: Fetching messages for chatId: \(chatId)")
        
        ChatService().fetchMessages(forChatId: chatId) { result in
            switch result {
            case .success(let fetchedMessages):
                print("DEBUG: Fetched \(fetchedMessages.count) messages.")
                self.messages = fetchedMessages
                self.isLoading = false

                // Debugging: Log message IDs and sender IDs for verification
                for message in fetchedMessages {
                    print("DEBUG: Message ID: \(message.id ?? "nil") from Sender: \(message.senderId)")
                }

                // Mark all received messages as read
                markMessagesAsRead(for: fetchedMessages.filter { $0.senderId != currentUserId })

            case .failure(let error):
                print("DEBUG: Error fetching messages: \(error)")
                self.isLoading = false
            }
        }
    }



    // Fetch usernames for the senderIds
    private func fetchUsernames(for userIds: [String]) {
        let db = Firestore.firestore()
        let usersRef = db.collection("users")

        usersRef.whereField(FieldPath.documentID(), in: userIds).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching usernames: \(error)")
                return
            }
            guard let documents = snapshot?.documents else {
                print("No users found")
                return
            }

            var fetchedNames: [String: String] = [:]
            for document in documents {
                let data = document.data()
                if let username = data["username"] as? String {
                    fetchedNames[document.documentID] = username
                }
            }

            DispatchQueue.main.async {
                self.userNames.merge(fetchedNames) { (_, new) in new }
            }
        }
    }

    private func markMessagesAsRead(for messages: [Message]) {
        print("DEBUG: Marking \(messages.count) messages as read for chatId: \(chatId)") // Debugging
        ChatService().markMessagesAsRead(inChat: chatId, forUserId: currentUserId)
    }


    private func sendMessage() {
        if !messageText.isEmpty {
            // Debugging: Print the currentUserId and receiverId before sending the message
            print("Sending message from \(currentUserId) to \(receiverId) in chat \(chatId)")

            ChatService().sendMessage(inChat: chatId, senderId: currentUserId, receiverId: receiverId, text: messageText) { result in
                switch result {
                case .success(let message):
                    self.messages.append(message)
                    self.messageText = ""
                    print("Message sent successfully. Message ID: \(message.id ?? "nil") from \(message.senderId) to \(message.receiverId)") // Debugging
                case .failure(let error):
                    print("Error sending message: \(error)")
                }
            }
        }
    }


}
