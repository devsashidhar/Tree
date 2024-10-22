import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    let chatId: String
    let currentUserId: String
    let receiverId: String // Added receiverId to handle message sending properly

    @State private var messages: [Message] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = true

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

    // Fetch messages in the chat
    private func fetchMessages() {
        ChatService().fetchMessages(forChatId: chatId) { result in
            switch result {
            case .success(let fetchedMessages):
                self.messages = fetchedMessages
                self.isLoading = false

                // Mark all received messages as read
                markMessagesAsRead(for: fetchedMessages.filter { $0.senderId != currentUserId })
                
            case .failure(let error):
                print("Error fetching messages: \(error)")
                self.isLoading = false
            }
        }
    }

    private func markMessagesAsRead(for messages: [Message]) {
        ChatService().markMessagesAsRead(inChat: chatId, forUserId: currentUserId)
    }

    // Send a new message
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
