import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Feed()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Feed")
                }

            PostView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Post")
                }
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            AccountView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Account")
                }
        }
    }
}

