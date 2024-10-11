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

    var body: some View {
        VStack {
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Button("Select an Image") {
                    showImagePicker = true
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }

            Button(action: uploadPost) {
                Text("Upload")
                    .frame(width: 200)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
            }
            .padding(.top, 20)
            .disabled(selectedImage == nil || isUploading)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            checkAuthenticationStatus()
        }
        .sheet(isPresented: $showImagePicker, content: {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        })
        
    }
    
    func checkAuthenticationStatus() {
            if let user = Auth.auth().currentUser {
                print("User authenticated: \(user.uid)")
            } else {
                print("User is not authenticated.")
            }
    }

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

    func savePostToFirestore(imageUrl: String, location: CLLocation) {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "userId": Auth.auth().currentUser?.uid ?? "",
            "imageUrl": imageUrl,
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
            }
            self.isUploading = false
        }
    }
}
