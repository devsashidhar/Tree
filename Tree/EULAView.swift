import SwiftUI

struct EULAView: View {
    @Environment(\.presentationMode) var presentationMode // Allows dismissal of the sheet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("End User License Agreement (EULA)")
                    .font(.headline)
                    .padding(.bottom, 10)

                Text("""
                End-User License Agreement (EULA) for EcoTerra
                Effective Date: 11/8/2024
                Last Updated: 11/8/2024
                Please read this End-User License Agreement ("EULA") carefully before using the EcoTerra mobile application ("App"). By installing, accessing, or using the App, you agree to be bound by this EULA. If you do not agree to these terms, do not install, access, or use the App.
                License Grant
                EcoTerra grants you a non-exclusive, non-transferable, revocable license to use the App solely for personal, non-commercial purposes in accordance with this EULA. All rights not expressly granted to you are reserved by EcoTerra.
                User Responsibilities and Conduct
                By using the App, you agree to:
                Abide by all applicable laws and regulations.
                Use the App only for lawful purposes and in a manner that does not infringe on the rights of others.
                Not post, share, or transmit content that is offensive, abusive, obscene, discriminatory, or otherwise objectionable ("Objectionable Content").
                Objectionable Content includes, but is not limited to:
                Hate speech, harassment, threats, or any form of abusive behavior.
                Pornographic, lewd, or sexually explicit material.
                Content that incites violence, promotes illegal activity, or discriminates based on race, religion, gender, nationality, disability, or any other characteristic.
                Violation of this clause may result in the immediate suspension or termination of your account and removal of all related content, at EcoTerra's sole discretion.
                Content Ownership and Responsibility
                You retain ownership of any content you submit, post, or display on or through the App. However, by posting content, you grant EcoTerra a non-exclusive, worldwide, royalty-free, and transferable license to use, modify, display, reproduce, and distribute such content solely to provide the App's services.
                You are solely responsible for the content you post and may be held legally liable for any content that violates this EULA or applicable law. EcoTerra is not responsible for any content shared by users and reserves the right to remove content at its discretion.
                Reporting Objectionable Content
                If you encounter content that you believe violates this EULA, you may report it to EcoTerra via the in-app reporting feature. EcoTerra will review all reports and take appropriate action within 24 hours, including but not limited to content removal and account suspension for violators.
                Note: Reporting content does not guarantee its immediate removal. EcoTerra will act in good faith to respond to all reports but does not assume liability for content posted by users.
                Termination of Use
                EcoTerra reserves the right to suspend, restrict, or terminate your access to the App, with or without notice, if you violate this EULA or engage in any behavior deemed harmful or abusive. Upon termination, you must delete all copies of the App from your devices. EcoTerra reserves the right to delete any user data associated with terminated accounts.
                Account Deletion and Data Handling
                You may request account deletion at any time via the account settings in the App. Upon account deletion, EcoTerra will remove your personal data from its systems and delete all content you posted, including photos and comments. Note that your username may become available for reuse by others after your account is deleted.
                Limitation of Liability
                To the maximum extent permitted by law, EcoTerra shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or related to your use of the App, even if EcoTerra has been advised of the possibility of such damages. EcoTerra's total liability under this EULA, whether in contract, tort, or otherwise, shall be limited to the amount you paid, if any, to use the App.
                You acknowledge that you use the App at your own risk and agree that EcoTerra shall not be liable for any damages resulting from your reliance on information or content available through the App.
                Disclaimer of Warranties
                The App is provided "as-is" and "as available," without any warranties of any kind, whether express or implied. EcoTerra disclaims all warranties, including but not limited to implied warranties of merchantability, fitness for a particular purpose, and non-infringement. EcoTerra does not guarantee that the App will be available without interruption or error-free or that any defects will be corrected.
                Changes to this EULA
                EcoTerra reserves the right to update or modify this EULA at any time. EcoTerra will notify users of any material changes by posting the revised EULA within the App or by other means. Your continued use of the App after the effective date of the revised EULA constitutes your acceptance of the changes.
                Governing Law
                This EULA shall be governed by and construed in accordance with the laws of the State of North Carolina, without regard to its conflict of law provisions. Any disputes arising under or related to this EULA shall be resolved exclusively in the courts located in North Carolina, USA.
                By using the App, you acknowledge that you have read, understood, and agree to be bound by this EULA. If you do not agree to this EULA, you must not use the App.
                """)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)

                Button(action: {
                    presentationMode.wrappedValue.dismiss() // Close the sheet
                }) {
                    Text("Close")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all)) // Optional background color
    }
}
