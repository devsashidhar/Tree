import FirebaseFirestore

class ChatService {
    let db = Firestore.firestore()
    
    func fetchUnreadMessagesCount(forUserId userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
            let db = Firestore.firestore()
            db.collection("messages")
                .whereField("receiverId", isEqualTo: userId) // Assuming you store the receiverId in each message
                .whereField("isRead", isEqualTo: false)
                .getDocuments { (snapshot, error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    let unreadCount = snapshot?.documents.count ?? 0
                    completion(.success(unreadCount))
                }
        }

        // Update read status of messages when a chat is viewed
        func markMessagesAsRead(inChat chatId: String, forUserId userId: String) {
            let db = Firestore.firestore()
            db.collection("messages")
                .whereField("chatId", isEqualTo: chatId)
                .whereField("receiverId", isEqualTo: userId)
                .whereField("isRead", isEqualTo: false)
                .getDocuments { (snapshot, error) in
                    if let documents = snapshot?.documents {
                        for document in documents {
                            document.reference.updateData(["isRead": true])
                        }
                    }
                }
        }

    func getOrCreateChat(forUsers userIds: [String], completion: @escaping (Result<String, Error>) -> Void) {
        let chatsRef = Firestore.firestore().collection("chats")

        // Check if a chat already exists between the two users
        chatsRef
            .whereField("userIds", arrayContainsAny: userIds) // This checks if any of the userIds match
            .getDocuments { (snapshot, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                // Iterate through all found chats and check if they contain the exact same userIds
                if let documents = snapshot?.documents {
                    for document in documents {
                        let existingUserIds = document.data()["userIds"] as? [String] ?? []
                        if Set(existingUserIds) == Set(userIds) { // Check if it's the exact same set of userIds
                            completion(.success(document.documentID))
                            return
                        }
                    }
                }

                // If no chat exists, create a new chat with both userIds
                let newChat = Chat(userIds: userIds, createdAt: Timestamp(), lastMessageTimestamp: Timestamp())
                var ref: DocumentReference? = nil
                ref = chatsRef.addDocument(data: [
                    "userIds": userIds, // Ensure both user IDs are added here
                    "createdAt": newChat.createdAt,
                    "lastMessageTimestamp": newChat.lastMessageTimestamp
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(ref!.documentID))
                    }
                }
            }
    }

    // Create a new chat
    func createChat(withUserIds userIds: [String], completion: @escaping (Result<Chat, Error>) -> Void) {
        let chatRef = db.collection("chats").document()
        let chat = Chat(id: chatRef.documentID, userIds: userIds, createdAt: Timestamp(), lastMessageTimestamp: Timestamp())
        chatRef.setData(chat.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(chat))
            }
        }
    }

    func fetchChats(forUserId userId: String, completion: @escaping (Result<[(Chat, String)], Error>) -> Void) {
        db.collection("chats").whereField("userIds", arrayContains: userId).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                var chatResults: [(Chat, String)] = []
                let group = DispatchGroup()

                for doc in snapshot?.documents ?? [] {
                    if let chat = Chat(from: doc.data(), id: doc.documentID) {
                        // Find the other user in the chat (not the current user)
                        let otherUserId = chat.userIds.first { $0 != userId } ?? userId

                        group.enter()
                        // Fetch the username of the other user
                        self.fetchUsername(forUserId: otherUserId) { result in
                            switch result {
                            case .success(let username):
                                chatResults.append((chat, username))
                            case .failure:
                                chatResults.append((chat, "Unknown"))
                            }
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .main) {
                    completion(.success(chatResults))
                }
            }
        }
    }

    // Fetch username by userId
    func fetchUsername(forUserId userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists, let data = document.data(), let username = data["username"] as? String {
                completion(.success(username))
            } else {
                completion(.failure(error ?? NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
            }
        }
    }


    func sendMessage(inChat chatId: String, senderId: String, receiverId: String, text: String, completion: @escaping (Result<Message, Error>) -> Void) {
        print("DEBUG: Sending message from \(senderId) to \(receiverId) in chat \(chatId)") // Added for debugging

        let messageRef = db.collection("chats").document(chatId).collection("messages").document()

        // Create the message with isRead set to false (since it's just being sent)
        let message = Message(
            id: messageRef.documentID,
            senderId: senderId,
            receiverId: receiverId,
            text: text,
            timestamp: Timestamp(),
            isRead: false
        )

        messageRef.setData(message.toDictionary()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("DEBUG: Message sent successfully. Message ID: \(message.id ?? "nil")") // Debugging
                // Update the last message timestamp in the chat
                self.updateLastMessageTimestamp(chatId: chatId)
                completion(.success(message))
            }
        }
    }



    // Fetch messages in a chat
    func fetchMessages(forChatId chatId: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        db.collection("chats").document(chatId).collection("messages").order(by: "timestamp").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let messages = snapshot?.documents.compactMap { doc in
                    return Message(from: doc.data(), id: doc.documentID)
                } ?? []
                completion(.success(messages))
            }
        }
    }

    // Update last message timestamp in chat document
    func updateLastMessageTimestamp(chatId: String) {
        let chatRef = db.collection("chats").document(chatId)
        chatRef.updateData([
            "lastMessageTimestamp": Timestamp()
        ]) { error in
            if let error = error {
                print("Error updating last message timestamp: \(error)")
            } else {
                print("Successfully updated last message timestamp")
            }
        }
    }
}
