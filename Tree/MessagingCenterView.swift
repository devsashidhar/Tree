import SwiftUI

struct MessagingCenterView: View {
    let currentUserId: String

    @State private var chats: [(Chat, String)] = [] // Tuple of Chat and Username
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
                        NavigationLink(destination: ChatView(chatId: chat.id!, currentUserId: currentUserId, receiverId: chat.userIds.first { $0 != currentUserId }!)) {
                            Text("Chat with: \(otherUsername)")
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
}
