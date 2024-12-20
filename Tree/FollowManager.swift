import SwiftUI
import Combine

class FollowManager: ObservableObject {
    @Published var following: Set<String> = []
}
