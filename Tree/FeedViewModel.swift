import Foundation
import Combine

class FeedViewModel: ObservableObject {
    @Published var previouslyViewedPosts: [Post] = []

    init() {
        listenForFollowerRemoval()
    }

    func listenForFollowerRemoval() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFollowerRemoved(_:)),
            name: Notification.Name("FollowerRemoved"),
            object: nil
        )
    }

    @objc private func handleFollowerRemoved(_ notification: Notification) {
        if let unfollowedUserId = notification.userInfo?["unfollowedUserId"] as? String {
            print("[Debug] Removing posts from unfollowed user: \(unfollowedUserId)")

            // Load existing cached posts
            var cachedPosts: [Post] = []
            if let cachedData = UserDefaults.standard.data(forKey: "cachedPreviouslyViewedPosts"),
               let loadedPosts = try? JSONDecoder().decode([Post].self, from: cachedData) {
                cachedPosts = loadedPosts
            }

            // Remove unfollowed user's posts
            cachedPosts.removeAll { $0.userId == unfollowedUserId }

            // Save updated cache
            if let data = try? JSONEncoder().encode(cachedPosts) {
                UserDefaults.standard.set(data, forKey: "cachedPreviouslyViewedPosts")
                print("[Debug] Removed cached posts of unfollowed user: \(unfollowedUserId)")
            } else {
                print("[Error] Failed to update cache after unfollowing \(unfollowedUserId)")
            }

            // ✅ Refresh Feed after updating cache
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("FeedShouldRefresh"), object: nil)
            }
        }
    }

}
