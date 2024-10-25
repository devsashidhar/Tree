import SwiftUI

struct ChatView: View {
    let chatId: String
    let currentUserId: String
    let receiverId: String
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToUserPosts = false // State variable for navigation

    @State private var messages: [Message] = []
    @State private var messageText: String = ""
    @State private var isLoading: Bool = true
    @State private var userNames: [String: String] = [:]

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
                    
                    Button(action: {
                        // Trigger navigation to UserPostsView
                        navigateToUserPosts = true
                    }) {
                        Text("View Posts")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .padding()
                    
                    Spacer()
                }

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
