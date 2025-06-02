import SwiftUI

/// View für die Erstellung neuer Benutzer
/// Wird angezeigt, wenn kein User vorhanden ist und eine Reise erstellt werden soll
struct UserCreationView: View {
    @StateObject private var viewModel = UserCreationViewModel()
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    
    let onUserCreated: () -> Void
    
    init(onUserCreated: @escaping () -> Void = {}) {
        self.onUserCreated = onUserCreated
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                Form {
                    // Benutzername Section
                    Section("Dein Name") {
                        TextField("z.B. Max Mustermann", text: $viewModel.displayName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .headerProminence(.increased)
                    
                    // Email Section (Optional)
                    Section("E-Mail (Optional)") {
                        TextField("max@beispiel.de", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Info Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Deine Daten bleiben privat", systemImage: "lock.shield")
                                .foregroundColor(.blue)
                            
                            Text("Alle Informationen werden nur lokal auf deinem Gerät gespeichert und nicht übertragen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Vorschau Section
                    if !viewModel.displayName.isEmpty {
                        Section("Vorschau") {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.displayName)
                                        .font(.headline)
                                    
                                    if !viewModel.email.isEmpty {
                                        Text(viewModel.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Benutzer erstellen")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        viewModel.createUser(using: userManager) {
                            onUserCreated()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isCreating)
                    .fontWeight(.semibold)
                }
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Erfolg", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    onUserCreated()
                    dismiss()
                }
            } message: {
                Text("Benutzer wurde erfolgreich erstellt!")
            }
            .disabled(viewModel.isCreating)
            .overlay(
                // Loading Overlay
                viewModel.isCreating ? 
                Color.black.opacity(0.3)
                    .overlay(
                        ProgressView("Benutzer wird erstellt...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    )
                    .ignoresSafeArea()
                : nil
            )
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Willkommen bei TravelCompanion!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Um Reisen zu erstellen und Erinnerungen zu speichern, benötigst du zunächst ein Benutzerprofil.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

/// ViewModel für UserCreationView
/// Verwaltet Form-State, Validation und User-Erstellung
class UserCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var displayName = ""
    @Published var email = ""
    @Published var isCreating = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage = ""
    
    // MARK: - Computed Properties
    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - User Creation
    func createUser(using userManager: UserManager, completion: @escaping () -> Void) {
        guard isValid else {
            showError(message: "Bitte gib einen Namen ein.")
            return
        }
        
        isCreating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let trimmedName = self.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEmail = self.email.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Verwende Default-Email wenn keine angegeben
            let finalEmail = trimmedEmail.isEmpty ? "user@travelcompanion.com" : trimmedEmail
            
            // Prüfe Email-Format wenn angegeben
            if !trimmedEmail.isEmpty && !self.isValidEmail(trimmedEmail) {
                self.showError(message: "Bitte gib eine gültige E-Mail-Adresse ein.")
                self.isCreating = false
                return
            }
            
            if let newUser = userManager.createUser(email: finalEmail, displayName: trimmedName) {
                // Setze als aktuellen User
                userManager.setCurrentUser(newUser)
                
                self.isCreating = false
                self.showSuccess = true
                
                print("✅ UserCreationView: Benutzer erfolgreich erstellt: \(trimmedName)")
            } else {
                self.showError(message: "Der Benutzer konnte nicht erstellt werden. Bitte versuche es erneut.")
                self.isCreating = false
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Preview
struct UserCreationView_Previews: PreviewProvider {
    static var previews: some View {
        UserCreationView()
            .environmentObject(UserManager.shared)
    }
} 