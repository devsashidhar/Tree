import SwiftUI

struct FarewellView: View {
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.8)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Sad face icon to add a human touch
                Image(systemName: "hand.wave.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                    .padding(.bottom, 10)

                Text("We're Sorry to See You Go")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("Your data has been securely removed from our system, and your username is now available for new users.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.body)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)

                Text("Thank you for being a part of EcoTerra. We hope to see you again!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.body)
                    .padding(.horizontal, 30)

                Spacer()

                Button(action: {
                    navigateToLogin()
                }) {
                    Text("Return to Home")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 40)
            }
        }
    }

    // Function to navigate back to the login or home screen
    func navigateToLogin() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(rootView: SignInView())
                window.makeKeyAndVisible()
            }
        }
    }
}
