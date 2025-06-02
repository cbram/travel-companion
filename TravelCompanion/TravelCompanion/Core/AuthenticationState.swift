import SwiftUI
import Combine

/// Verwaltet den Authentifizierungsstatus der App
class AuthenticationState: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AuthenticationState()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var needsUserSelection = false
    @Published var isLoading = true
    
    // MARK: - Private Properties
    private var userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupUserObservation()
        checkAuthenticationStatus()
    }
    
    // MARK: - Setup Methods
    
    private func setupUserObservation() {
        // Beobachte Änderungen am aktuellen User
        userManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.updateAuthenticationStatus(user: user)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Methods
    
    /// Überprüft den aktuellen Authentifizierungsstatus
    func checkAuthenticationStatus() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateAuthenticationStatus(user: self.userManager.currentUser)
            self.isLoading = false
        }
    }
    
    /// Aktualisiert den Authentifizierungsstatus basierend auf dem aktuellen User
    private func updateAuthenticationStatus(user: User?) {
        if let user = user, user.isActive {
            isAuthenticated = true
            needsUserSelection = false
            print("✅ AuthenticationState: User \(user.formattedDisplayName) ist angemeldet")
        } else {
            isAuthenticated = false
            needsUserSelection = true
            print("⚠️ AuthenticationState: Kein gültiger User angemeldet")
        }
    }
    
    /// Meldet einen User an
    func signIn(user: User) {
        userManager.setCurrentUser(user)
        // Der Status wird automatisch über den Publisher aktualisiert
    }
    
    /// Meldet den aktuellen User ab
    func signOut() {
        userManager.currentUser = nil
        // Der Status wird automatisch über den Publisher aktualisiert
    }
    
    /// Zeigt die Benutzerauswahl an
    func showUserSelection() {
        needsUserSelection = true
    }
    
    /// Versteckt die Benutzerauswahl
    func hideUserSelection() {
        needsUserSelection = false
    }
    
    /// Erstellt einen neuen User und meldet ihn sofort an
    func createAndSignInUser(email: String, displayName: String, avatarURL: String? = nil) -> Bool {
        guard let newUser = userManager.createUser(email: email, displayName: displayName) else {
            return false
        }
        
        // Avatar URL optional setzen
        if let avatarURL = avatarURL, !avatarURL.isEmpty {
            _ = userManager.updateUser(newUser, avatarURL: avatarURL)
        }
        
        signIn(user: newUser)
        return true
    }
    
    // MARK: - Utility Methods
    
    /// Überprüft ob die App bereit für die Nutzung ist
    var isReadyForUse: Bool {
        return isAuthenticated && !needsUserSelection && !isLoading
    }
    
    /// Holt die verfügbaren Benutzer
    var availableUsers: [User] {
        return userManager.getAllActiveUsers()
    }
    
    /// Aktuelle User-Informationen
    var currentUserInfo: String? {
        guard let user = userManager.currentUser else { return nil }
        return "\(user.formattedDisplayName) (\(user.email ?? "Keine E-Mail"))"
    }
} 