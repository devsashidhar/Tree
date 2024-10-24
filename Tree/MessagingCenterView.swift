import SwiftUI

struct MessagingCenterView: View {
    let currentUserId: String

    @State private var chats: [(Chat, String, Bool)] = [] // Tuple of Chat, Username, and Unread status
    @State private var isLoading: Bool = true

    var body: some View {
            NavigationView {
                VStack {
                    if isLoading {
                        ProgressView("Loading chats...")
                    } else if chats.isEmpty {
                        Text("No chats available.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(chats, id: \.0.id) { (chat, otherUsername, hasUnreadMessages) in
                            HStack {
                                NavigationLink(
                                    destination: ChatView(chatId: chat.id!, currentUserId: currentUserId, receiverId: chat.userIds.first { $0 != currentUserId }!)
                                    .onAppear {
                                        // Mark messages as read when the chat is opened
                                        markChatAsRead(chatId: chat.id!)
                                    }
                                ) {
                                    Text("Chat with: \(otherUsername)")

                                    Spacer()

                                    // Show unread indicator (blue dot) if there are unread messages
                                    if hasUnreadMessages {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    fetchChats()
                }
            }
        }

    private func fetchChats() {
            ChatService().fetchChats(forUserId: currentUserId) { result in
                switch result {
                case .success(let fetchedChats):
                    self.chats = fetchedChats
                    self.isLoading = false
                case .failure(let error):
                    print("Error fetching chats: \(error)")
                    self.isLoading = false
                }
            }
    }

    private func markChatAsRead(chatId: String) {
        ChatService().markMessagesAsRead(inChat: chatId, forUserId: currentUserId)
        
        // After marking messages as read, update the UI
        if let index = chats.firstIndex(where: { $0.0.id == chatId }) {
            chats[index].2 = false // Mark as no unread messages
        }
    }
}
