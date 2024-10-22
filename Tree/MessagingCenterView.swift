import SwiftUI

struct MessagingCenterView: View {
    let currentUserId: String

    @State private var chats: [(Chat, String)] = [] // Tuple of Chat and Username
    @State private var unreadStatuses: [String: Bool] = [:] // Track which chats have unread messages
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
                    List(chats, id: \.0.id) { (chat, otherUsername) in
                        // Wrap the entire row with a NavigationLink
                        NavigationLink(
                            destination: ChatView(
                                chatId: chat.id!,
                                currentUserId: currentUserId,
                                receiverId: chat.userIds.first(where: { $0 != currentUserId }) ?? currentUserId
                            )
                            .onDisappear {
                                // Remove the blue dot when the user finishes viewing the chat
                                unreadStatuses[chat.id!] = false
                            }
                        ) {
                            HStack {
                                // Display chat with username
                                Text("Chat with: \(otherUsername)")

                                Spacer() // Push the blue dot and arrow to the right

                                // If there are unread messages, display a blue dot
                                if unreadStatuses[chat.id!] == true {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 10, height: 10)
                                        .padding(.trailing, 5) // Add padding to give space between the dot and the arrow
                                }

                                // Display the default disclosure indicator (the arrow)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray) // Keep it subtle
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

    // Fetch the chats for the current user
    private func fetchChats() {
        ChatService().fetchChats(forUserId: currentUserId) { result in
            switch result {
            case .success(let fetchedChats):
                self.chats = fetchedChats
                self.isLoading = false

                // After fetching chats, check for unread messages in each chat
                for (chat, _) in fetchedChats {
                    ChatService().hasUnreadMessages(inChat: chat.id!, forUserId: currentUserId) { result in
                        switch result {
                        case .success(let hasUnread):
                            DispatchQueue.main.async {
                                self.unreadStatuses[chat.id!] = hasUnread
                            }
                        case .failure(let error):
                            print("Error checking unread messages for chat \(chat.id!): \(error)")
                        }
                    }
                }
            case .failure(let error):
                print("Error fetching chats: \(error)")
                self.isLoading = false
            }
        }
    }
}
