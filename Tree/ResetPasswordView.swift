import SwiftUI
import FirebaseAuth

struct ResetPasswordView: View {
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack {
                Text("Reset Password")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.bottom, 40)

                TextField("Email", text: $email)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Button(action: handlePasswordReset) {
                    Text("Send Reset Link")
                        .frame(width: 200)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                }
                .padding(.top, 16)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }

                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.top, 100)
        }
        .navigationBarTitle("", displayMode: .inline) // Hides the title but keeps the back button
    }

    func handlePasswordReset() {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                self.errorMessage = "Error: \(error.localizedDescription)"
            } else {
                self.successMessage = "If an account with this email exists, a reset link has been sent."
                self.errorMessage = ""
            }
        }
    }
}
