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
    @State private var isScanning = false
    @State private var uploadSuccessMessage: String = "" // For success message

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
                
                // Display success message if any
                if !uploadSuccessMessage.isEmpty {
                    Text(uploadSuccessMessage)
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }

                // Display error message if any
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
            }
            .padding()
            
            // Scanning overlay
            if isScanning {
                ZStack {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    Text("Scanning...")
                        .foregroundColor(.white)
                        .font(.title)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
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
        // Clear previous error message and reset isUploading
        errorMessage = ""
        isUploading = false
        isScanning = true  // Show scanning indicator
        
        guard let selectedImage = selectedImage, let location = locationManager.location else {
            errorMessage = "No image selected or location not available."
            isScanning = false // Hide scanning if validation fails
            return
        }

        isUploading = true

        // First, analyze the image for humans
        analyzeImageForHumans(selectedImage) { isAllowed in
            DispatchQueue.main.async {
                self.isScanning = false  // Hide scanning indicator
                if isAllowed {
                    // No humans detected, proceed with the upload
                    let storageRef = Storage.storage().reference().child("images/\(UUID().uuidString).jpg")
                    guard let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
                        self.errorMessage = "Failed to process image data."
                        self.isUploading = false
                        return
                    }

                    // Upload image to Firebase Storage
                    storageRef.putData(imageData, metadata: nil) { metadata, error in
                        if let error = error {
                            self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                            self.isUploading = false
                            return
                        }

                        // Retrieve the download URL after successful upload
                        storageRef.downloadURL { url, error in
                            if let error = error {
                                self.errorMessage = "Failed to retrieve image URL: \(error.localizedDescription)"
                                self.isUploading = false
                                return
                            }

                            guard let imageUrl = url?.absoluteString else { return }
                            
                            // Save the post to Firestore with the image URL and location
                            savePostToFirestore(imageUrl: imageUrl, location: location)
                        }
                    }
                } else {
                    // Human detected, do not proceed with upload
                    self.errorMessage = "No humans allowed in the image."
                    self.isUploading = false
                }
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
                self.uploadSuccessMessage = "Image uploaded successfully!" // Show success message
                
                // Clear the success message after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.uploadSuccessMessage = ""
                }
            }
            self.isUploading = false
        }
    }
    
    func analyzeImageForHumans(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let base64Image = imageData.base64EncodedString()
        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=AIzaSyDnVii14FsV_9UkERduhvJYTobWRhiRpes")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [["type": "LABEL_DETECTION"]]
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to make request: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            // Print the raw JSON response to inspect its structure
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("Full JSON response: \(json)")
            } else {
                print("Failed to parse JSON response.")
            }
            
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let labels = (json?["responses"] as? [[String: Any]])?.first?["labelAnnotations"] as? [[String: Any]]
            let detectedLabels = labels?.compactMap { $0["description"] as? String } ?? []
            
            // Check for human-related labels
            let humanKeywords = ["person", "human", "face", "man", "woman", "people", "child", "forehead", "head", "smile", "chin", "eyebrows", "baby", "guy", "girl", "boy", "lady", "gentleman"]
            let containsHuman = detectedLabels.contains { label in
                humanKeywords.contains { keyword in
                    label.localizedCaseInsensitiveContains(keyword)
                }
            }
            
            // Allow upload if no human-related labels are detected
            completion(!containsHuman)
        }.resume()

    }

    
}
