import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
import FirebaseAuth

struct PostView: View {
    @ObservedObject var locationManager = LocationManager()
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var errorMessage: String = ""
    @State private var isUploading = false
    @State private var locationName: String = "" // State for location input

    var body: some View {
        ZStack {
            // Softer gradient background with light blue and indigo
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.indigo.opacity(0.8)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Display selected image or button to select/change one
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 10) // Add shadow to image
                    
                    // "Change Image" button to allow the user to pick another image
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text("Change Image")
                            .frame(width: 200)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 5)
                    }
                } else {
                    // Show "Select an Image" button if no image is selected
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text("Select an Image")
                            .frame(width: 200)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 5)
                    }
                }

                // Clean and modern TextField with subtle contrast
                TextField("Enter the location (e.g., Iceland)", text: $locationName)
                    .padding()
                    .background(Color.white.opacity(0.3)) // Add a subtle contrasting background
                    .cornerRadius(10)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.8), lineWidth: 1) // Soft white border
                    )
                    .padding(.horizontal, 16)

                // Upload button
                Button(action: uploadPost) {
                    Text("Upload")
                        .frame(width: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: .blue.opacity(0.5), radius: 5, x: 0, y: 5)
                }
                .padding(.top, 10)
                .disabled(selectedImage == nil || locationName.isEmpty || isUploading) // Disable if no image or location name

                // Display error message if any
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showImagePicker, content: {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        })
        .onAppear {
            checkAuthenticationStatus()
        }
    }
    
    // Function to check authentication status
    func checkAuthenticationStatus() {
        if let user = Auth.auth().currentUser {
            print("User authenticated: \(user.uid)")
        } else {
            print("User is not authenticated.")
        }
    }

    // Function to handle post upload
    func uploadPost() {
        guard let selectedImage = selectedImage, let location = locationManager.location else {
            errorMessage = "No image selected or location not available."
            return
        }

        isUploading = true
        let storageRef = Storage.storage().reference().child("images/\(UUID().uuidString).jpg")
        guard let imageData = selectedImage.jpegData(compressionQuality: 0.8) else { return }

        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                self.isUploading = false
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    self.errorMessage = "Failed to retrieve image URL: \(error.localizedDescription)"
                    self.isUploading = false
                    return
                }

                guard let imageUrl = url?.absoluteString else { return }
                savePostToFirestore(imageUrl: imageUrl, location: location)
            }
        }
    }

    // Save post to Firestore
    func savePostToFirestore(imageUrl: String, location: CLLocation) {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "userId": Auth.auth().currentUser?.uid ?? "",
            "imageUrl": imageUrl,
            "locationName": locationName, // Save the location name
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("posts").addDocument(data: data) { error in
            if let error = error {
                self.errorMessage = "Failed to save post: \(error.localizedDescription)"
            } else {
                self.errorMessage = ""
                self.selectedImage = nil
                self.locationName = "" // Clear after upload
            }
            self.isUploading = false
        }
    }
}
