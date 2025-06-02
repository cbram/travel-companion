import SwiftUI

/// View zum Bearbeiten der Benutzerdaten
struct EditUserProfileView: View {
    @EnvironmentObject private var userManager: UserManager
    let user: User
    
    @State private var displayName: String
    @State private var email: String
    @State private var avatarURL: String
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    init(user: User) {
        self.user = user
        self._displayName = State(initialValue: user.displayName ?? "")
        self._email = State(initialValue: user.email ?? "")
        self._avatarURL = State(initialValue: user.avatarURL ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar Vorschau
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: avatarURL.isEmpty ? user.avatarURL ?? "" : avatarURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        
                        Text("Avatar Vorschau")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Bearbeitungsformular
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
                        
                        // Email (nur anzeigen, nicht bearbeitbar)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("E-Mail Adresse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("E-Mail", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(true)
                                .foregroundColor(.secondary)
                            
                            Text("Die E-Mail Adresse kann nicht geändert werden")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Avatar URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Avatar URL (optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("https://...", text: $avatarURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Text("Link zu deinem Profilbild")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveChanges()
                    }
                    .disabled(!hasChanges || !isFormValid || isLoading)
                }
            }
            .alert("Fehler", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Speichere...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasChanges: Bool {
        displayName != user.displayName ||
        avatarURL != (user.avatarURL ?? "")
    }
    
    private var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        guard hasChanges && isFormValid else { return }
        
        isLoading = true
        
        // Simuliere kurze Verzögerung für bessere UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = userManager.updateUser(
                user,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarURL: avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            isLoading = false
            
            if success {
                dismiss()
            } else {
                errorMessage = "Fehler beim Speichern der Änderungen. Bitte versuche es erneut."
                showingError = true
            }
        }
    }
}

// MARK: - Preview
struct EditUserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview mit Mock User
        let mockUser = User(context: PersistenceController.preview.container.viewContext)
        mockUser.displayName = "Max Mustermann"
        mockUser.email = "max@example.com"
        mockUser.avatarURL = "https://example.com/avatar.jpg"
        
        return EditUserProfileView(user: mockUser)
            .environmentObject(UserManager.shared)
    }
} 