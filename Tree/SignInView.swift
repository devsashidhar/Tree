import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Custom TextField style modifier for consistent styling
extension View {
    func customTextFieldStyle() -> some View {
        self
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .disableAutocorrection(true)
    }
}

struct SignInView: View {
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var errorMessage = ""
    @State private var leafOffsetY: CGFloat = -200
    @State private var leafOpacity: Double = 1.0

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    ZStack {
                        Text("EcoTerra")
                            .font(.custom("Noteworthy", size: 50))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 2)

                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 40))
                            .offset(x: 0, y: leafOffsetY)
                            .opacity(leafOpacity)
                            .onAppear {
                                withAnimation(
                                    Animation.easeInOut(duration: 3.0)
                                        .repeatCount(1, autoreverses: false)
                                ) {
                                    leafOffsetY = 600
                                    leafOpacity = 0
                                }
                            }
                    }
                    .padding(.bottom, 20)

                    VStack(spacing: 20) {
                        Picker("Login or Signup", selection: $isLoginMode) {
                            Text("Login").tag(true)
                            Text("Signup").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)

                        VStack(spacing: 16) {
                            if !isLoginMode {
                                TextField("First Name", text: $firstName)
                                    .customTextFieldStyle()

                                TextField("Last Name", text: $lastName)
                                    .customTextFieldStyle()

                                TextField("Username", text: $username)
                                    .customTextFieldStyle()
                                    .autocapitalization(.none)
                            }

                            TextField("Email", text: $email)
                                .customTextFieldStyle()
                                .autocapitalization(.none)

                            SecureField("Password", text: $password)
                                .customTextFieldStyle()
                                .autocapitalization(.none)

                            if !isLoginMode {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .customTextFieldStyle()
                                    .autocapitalization(.none)
                            }

                            if isLoginMode {
                                NavigationLink(destination: ResetPasswordView()) {
                                    Text("Forgot My Password?")
                                        .foregroundColor(.white)
                                        .underline()
                                        .font(.footnote)
                                }
                                .padding(.top, 4)
                            }

                            Button(action: handleAction) {
                                Text(isLoginMode ? "Sign In" : "Sign Up")
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
                        }
                    }
                    .frame(maxWidth: 350)
                    .padding(.vertical, 20)

                    Spacer()
                }
            }
            .navigationTitle(isLoginMode ? "Login" : "Signup")
            .navigationBarHidden(true)
        }
    }

    func handleAction() {
        if isLoginMode {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    self.errorMessage = "Failed to login: \(error.localizedDescription)"
                    return
                }
                // Navigate to the main tab view after successful login
                navigateToMainTabView()
            }
        } else {
            if password != confirmPassword {
                self.errorMessage = "Passwords do not match."
                return
            }

            if username.isEmpty || firstName.isEmpty || lastName.isEmpty {
                self.errorMessage = "Please fill in all fields."
                return
            }

            // Create a new user with email and password
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    self.errorMessage = "Failed to sign up: \(error.localizedDescription)"
                    return
                }
                
                guard let user = result?.user else { return }

                // Save additional user info to Firestore
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).setData([
                    "username": username,
                    "firstName": firstName,
                    "lastName": lastName,
                    "email": email
                ]) { error in
                    if let error = error {
                        self.errorMessage = "Error saving user info: \(error.localizedDescription)"
                        return
                    }
                    // Navigate to the main tab view after successful signup
                    navigateToMainTabView()
                }
            }
        }
    }

    func navigateToMainTabView() {
        // This will replace the root view with the MainTabView
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(rootView: MainTabView())
                window.makeKeyAndVisible()
            }
        }
    }
    
    func navigateToResetPasswordView() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(rootView: ResetPasswordView())
                window.makeKeyAndVisible()
            }
        }
    }

}
