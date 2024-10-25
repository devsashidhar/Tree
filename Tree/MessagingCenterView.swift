import SwiftUI

struct MessagingCenterView: View {
    let currentUserId: String
    @Environment(\.presentationMode) var presentationMode // To handle dismissal

    @State private var chats: [(Chat, String, Bool)] = [] // Tuple of Chat, Username, and Unread status
    @State private var isLoading: Bool = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading chats...")
            } else if chats.isEmpty {
                Text("No chats available.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(chats, id: \.0.id) { (chat, otherUsername, hasUnreadMessages) in
                    if let chatId = chat.id,
                       let receiverId = chat.userIds.first(where: { $0 != currentUserId }) {
                        NavigationLink(
                            destination: ChatView(chatId: chatId, currentUserId: currentUserId, receiverId: receiverId)
                                .onAppear {
                                    markChatAsRead(chatId: chatId)
                                }
                        ) {
                            HStack {
                                Text("Chat with: \(otherUsername)")
                                Spacer()
                                if hasUnreadMessages {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                    } else {
                        Text("Error: Could not load chat information")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            // Add a back button in the toolbar to dismiss `MessagingCenterView`
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss() // Dismiss the view
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .onAppear {
            fetchChats()
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
        if let index = chats.firstIndex(where: { $0.0.id == chatId }) {
            chats[index].2 = false
        }
    }
}
