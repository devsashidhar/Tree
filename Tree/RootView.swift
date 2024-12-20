import SwiftUI
import FirebaseAuth

struct RootView: View {
    @State private var isSignedIn: Bool = false
    @State private var isCheckingAuth = true
    @StateObject private var followManager = FollowManager()

    var body: some View {
        Group {
            if isCheckingAuth {
                // Show a loading indicator while checking authentication
                ProgressView("Loading...")
            } else if isSignedIn {
                // If signed in, navigate to MainTabView
                MainTabView()
                    .environmentObject(followManager)
            } else {
                // If not signed in, navigate to SignInView
                SignInView()
                    .environmentObject(followManager)
            }
        }
        .onAppear {
            checkAuthStatus()
        }
    }

    func checkAuthStatus() {
        if let currentUser = Auth.auth().currentUser {
            print("User is signed in: \(currentUser.uid)")
            isSignedIn = true
        } else {
            print("User is not signed in")
            isSignedIn = false
        }
        isCheckingAuth = false
    }
}

