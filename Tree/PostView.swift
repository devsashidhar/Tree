import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
import FirebaseAuth

struct PostView: View {
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var errorMessage: String = ""
    @State private var isUploading = false
    @State private var locationName: String = "" // State for location input
    @State private var isScanning = false
    @State private var uploadSuccessMessage: String = "" // For success message
    
    
    // Location selection
    @State private var countries: [String: [String]] = [:] // All countries and states
    @State private var countryList: [String] = [] // Dynamic list of countries
    @State private var filteredCountryList: [String] = []
    @State private var stateList: [String] = []
    @State private var filteredStateList: [String] = []
    @State private var selectedCountry: String = ""
    @State private var selectedState: String = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
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
                            .shadow(radius: 10)

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

                    // Country selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select a Country")
                            .font(.headline)

                        NavigationLink(destination: SelectionListView(
                            title: "Select a Country",
                            items: countryList,
                            onSelect: { country in
                                selectedCountry = country
                                loadStates(for: country) // Load states for the selected country
                                updateLocationName() // Update the location name
                            }
                        )) {
                            Text(selectedCountry.isEmpty ? "Type to search countries" : selectedCountry)
                                .foregroundColor(.black)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    }

                    // State selection
                    if !selectedCountry.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select a State/Region (Optional)")
                                .font(.headline)

                            NavigationLink(destination: SelectionListView(
                                title: "Select a State/Region",
                                items: stateList,
                                onSelect: { state in
                                    selectedState = state
                                    updateLocationName() // Update the location name
                                }
                            )) {
                                Text(selectedState.isEmpty ? "Type to search states" : selectedState)
                                    .foregroundColor(.black)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                            }
                        }
                    }

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
                    .disabled(selectedImage == nil || locationName.isEmpty || isUploading) // Allow upload if locationName is non-empty

                    // Success or error messages
                    if !uploadSuccessMessage.isEmpty {
                        Text(uploadSuccessMessage)
                            .foregroundColor(.black)
                            .padding(.top, 8)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.black)
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
                loadCountries() // Load the initial list of countries
            }
        }
    }

    private func loadCountries() {
            // Load the JSON file
            guard let url = Bundle.main.url(forResource: "countries", withExtension: "json") else {
                print("Countries JSON file not found.")
                return
            }

            do {
                let data = try Data(contentsOf: url)
                let decodedCountries = try JSONDecoder().decode([String: [String]].self, from: data)
                countries = decodedCountries
                countryList = Array(decodedCountries.keys).sorted()
                filteredCountryList = countryList
            } catch {
                print("Error loading countries: \(error)")
            }
        }

        private func filterCountries(query: String) {
            if query.isEmpty {
                filteredCountryList = countryList
            } else {
                filteredCountryList = countryList.filter { $0.lowercased().contains(query.lowercased()) }
            }
        }

        private func loadStates(for country: String) {
            stateList = countries[country] ?? []
            filteredStateList = stateList
        }

        private func filterStates(query: String) {
            if query.isEmpty {
                filteredStateList = stateList
            } else {
                filteredStateList = stateList.filter { $0.lowercased().contains(query.lowercased()) }
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
    
    private func updateLocationName() {
        if selectedState.isEmpty {
            locationName = selectedCountry
        } else {
            locationName = "\(selectedState), \(selectedCountry)"
        }
        print("Updated locationName: \(locationName)") // Debug statement
    }

    // Function to handle post upload
    func uploadPost() {
        // Clear previous error message and reset isUploading
        errorMessage = ""
        //isUploading = false
        isScanning = true  // Show scanning indicator
        
        // Ensure an image is selected and a location name is provided
        guard let selectedImage = selectedImage, !locationName.isEmpty else {
            errorMessage = "No image selected or location not provided."
            isScanning = false // Hide scanning if validation fails
            return
        }

        isUploading = true

        // First, analyze the image for humans
        analyzeImageForHumansAndInappropContent(selectedImage) { isAllowed in
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
                            savePostToFirestore(imageUrl: imageUrl)
                        }
                    }
                } else {
                    // Human detected, do not proceed with upload
                    self.errorMessage = "Only images of pure nature or wildlife are allowed — no people or human-made objects."
                    self.isUploading = false
                }
            }
        }
    }


    // Save post to Firestore
    func savePostToFirestore(imageUrl: String) {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "userId": Auth.auth().currentUser?.uid ?? "",
            "imageUrl": imageUrl,
            "locationName": locationName, // Save the location name
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("posts").addDocument(data: data) { error in
            if let error = error {
                self.errorMessage = "Failed to save post: \(error.localizedDescription)"
            } else {
                self.errorMessage = ""
                self.selectedImage = nil
                self.locationName = "" // Clear after upload
                self.selectedCountry = ""
                self.selectedState = ""
                self.uploadSuccessMessage = "Image uploaded successfully!" // Show success message
                
                // Clear the success message after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.uploadSuccessMessage = ""
                }
            }
            self.isUploading = false
        }
    }
    
    func analyzeImageForHumansAndInappropContent(_ image: UIImage, completion: @escaping (Bool) -> Void) {
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
                    "features": [
                        ["type": "LABEL_DETECTION"],
                        ["type": "FACE_DETECTION"],
                        ["type": "SAFE_SEARCH_DETECTION"] // Add SafeSearch Detection
                    ]
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
            
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("Full JSON response: \(json ?? [:])")
            
            // Extract SafeSearch results
            if let safeSearch = (json?["responses"] as? [[String: Any]])?.first?["safeSearchAnnotation"] as? [String: String] {
                let adultContent = safeSearch["adult"] ?? "UNKNOWN"
                let violenceContent = safeSearch["violence"] ?? "UNKNOWN"
                let racyContent = safeSearch["racy"] ?? "UNKNOWN"
                
                // Reject if any objectionable content is likely or very likely
                if adultContent == "LIKELY" || adultContent == "VERY_LIKELY" ||
                   violenceContent == "LIKELY" || violenceContent == "VERY_LIKELY" ||
                   racyContent == "LIKELY" || racyContent == "VERY_LIKELY" {
                    DispatchQueue.main.async {
                        self.errorMessage = "This image doesn’t meet our content guidelines. Please ensure that your upload contains only natural scenery and is free from any objectionable or inappropriate content."
                    }
                    completion(false)
                    return
                }
            }
            
            let labels = (json?["responses"] as? [[String: Any]])?.first?["labelAnnotations"] as? [[String: Any]]
            let faces = (json?["responses"] as? [[String: Any]])?.first?["faceAnnotations"] as? [[String: Any]]

            let detectedLabels = labels?.compactMap { $0["description"] as? String } ?? []
            
            let nonNatureKeywords = [
                "person", "human", "forehead", "smile", "chin", "eyebrows", "nose", "mouth",
                "building", "house", "car", "vehicle", "road", "street", "city", "architecture",
                "monument", "airplane", "ship", "bridge", "statue", "fountain", "train", "traffic",
                "wall", "fence", "sidewalk"
            ]
            
            let containsNonNature = detectedLabels.contains { label in
                nonNatureKeywords.contains { keyword in
                    label.localizedCaseInsensitiveContains(keyword)
                }
            } || !(faces?.isEmpty ?? true)

            // Allow upload if there is no human, no restricted labels, no faces, and no objectionable content
            completion(!containsNonNature)
        }.resume()
    }
    
    
    struct SelectionListView: View {
        let title: String
        let items: [String]
        let onSelect: (String) -> Void

        @State private var searchQuery: String = ""
        @Environment(\.presentationMode) var presentationMode

        var filteredItems: [String] {
            items.filter { item in
                searchQuery.isEmpty || item.lowercased().contains(searchQuery.lowercased())
            }
        }

        var body: some View {
            VStack {
                TextField("Search \(title.lowercased())", text: $searchQuery)
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.horizontal)

                List(filteredItems, id: \.self) { item in
                    Button(action: {
                        onSelect(item)
                        presentationMode.wrappedValue.dismiss() // Dismiss view after selection
                    }) {
                        Text(item)
                    }
                }
            }
            .navigationTitle(title)
        }
    }


}
