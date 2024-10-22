import FirebaseFirestore

struct Chat: Identifiable {
    var id: String? // Optional document ID
    var userIds: [String]
    var createdAt: Timestamp
    var lastMessageTimestamp: Timestamp

    // Initialize without @DocumentID annotation
    init(id: String? = nil, userIds: [String], createdAt: Timestamp, lastMessageTimestamp: Timestamp) {
        self.id = id
        self.userIds = userIds
        self.createdAt = createdAt
        self.lastMessageTimestamp = lastMessageTimestamp
    }

    // Function to create a dictionary to save to Firestore
    func toDictionary() -> [String: Any] {
        return [
            "userIds": userIds,
            "createdAt": createdAt,
            "lastMessageTimestamp": lastMessageTimestamp
        ]
    }

    // Initialize from Firestore document data
    init?(from data: [String: Any], id: String) {
        guard let userIds = data["userIds"] as? [String],
              let createdAt = data["createdAt"] as? Timestamp,
              let lastMessageTimestamp = data["lastMessageTimestamp"] as? Timestamp else {
            return nil
        }
        self.id = id
        self.userIds = userIds
        self.createdAt = createdAt
        self.lastMessageTimestamp = lastMessageTimestamp
    }
}
