import SwiftUI

/// View für die Registrierung neuer Benutzer
struct UserRegistrationView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var authenticationState: AuthenticationState
    @State private var email = ""
    @State private var displayName = ""
    @State private var avatarURL = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Willkommen bei Travel Companion")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Erstelle dein Profil um zu beginnen")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Formular
                VStack(spacing: 16) {
                    // Display Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anzeigename")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Dein Name", text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(false)
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 4) {
                        Text("E-Mail Adresse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("deine@email.com", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Avatar URL (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avatar URL (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("https://...", text: $avatarURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Registrieren Button
                Button(action: registerUser) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isLoading ? "Registriere..." : "Profil erstellen")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                
                // Info Text
                Text("Du kannst diese Daten später in den Einstellungen ändern")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Registrierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Schließen Button nur wenn andere Benutzer vorhanden sind
                if !authenticationState.availableUsers.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Abbrechen") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Fehler", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(email)
    }
    
    // MARK: - Actions
    
    private func registerUser() {
        guard isFormValid else { return }
        
        isLoading = true
        
        // Simuliere kurze Verzögerung für bessere UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = authenticationState.createAndSignInUser(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarURL: avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            isLoading = false
            
            if success {
                dismiss()
            } else {
                errorMessage = "Ein Benutzer mit dieser E-Mail Adresse existiert bereits oder es ist ein Fehler aufgetreten."
                showingError = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Preview
struct UserRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        UserRegistrationView()
            .environmentObject(UserManager.shared)
            .environmentObject(AuthenticationState.shared)
    }
} 