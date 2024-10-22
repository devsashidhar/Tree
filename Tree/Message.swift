import FirebaseFirestore

struct Message: Identifiable {
    var id: String? // Optional document ID
    var senderId: String
    var receiverId: String // The recipient of the message
    var text: String
    var timestamp: Timestamp
    var isRead: Bool // Whether the message has been read

    // Initialize without @DocumentID annotation
    init(id: String? = nil, senderId: String, receiverId: String, text: String, timestamp: Timestamp, isRead: Bool) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
    }

    // Function to create a dictionary to save to Firestore
    func toDictionary() -> [String: Any] {
        return [
            "senderId": senderId,
            "receiverId": receiverId, // Include receiverId in the dictionary
            "text": text,
            "timestamp": timestamp,
            "isRead": isRead // Include isRead in the dictionary
        ]
    }

    // Initialize from Firestore document data
    init?(from data: [String: Any], id: String) {
        guard let senderId = data["senderId"] as? String,
              let receiverId = data["receiverId"] as? String,
              let text = data["text"] as? String,
              let timestamp = data["timestamp"] as? Timestamp,
              let isRead = data["isRead"] as? Bool else {
            return nil
        }
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
    }
}
