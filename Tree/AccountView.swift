//
//  AccountView.swift
//  Tree
//
//  Created by Dev Sashidhar on 10/11/24.
//

import SwiftUI

struct AccountView: View {
    var body: some View {
        VStack {
            Text("Welcome to your account!")
                .font(.largeTitle)
                .padding()
            // Add other UI elements for the account view here
        }
        .onAppear {
            print("Welcome to AccountView!")
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}
