import Foundation
import CoreData
import Combine

/// Zentrale Verwaltung für User-bezogene Operationen
class UserManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UserManager()
    
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var viewContext: NSManagedObjectContext {
        return coreDataManager.viewContext
    }
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
        loadOrCreateDefaultUser()
    }
    
    // MARK: - Setup Methods
    private func setupNotifications() {
        // Beobachte Core Data Änderungen
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshCurrentUser()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public User Management Methods
    
    /// Lädt oder erstellt den Default User
    func loadOrCreateDefaultUser() {
        isLoading = true
        
        DispatchQueue.main.async {
            self.currentUser = User.fetchOrCreateDefaultUser(in: self.viewContext)
            
            // Speichern falls neuer User erstellt wurde
            _ = self.saveContext()
            
            self.isLoading = false
            print("✅ UserManager: Current User geladen: \(self.currentUser?.formattedDisplayName ?? "Unknown")")
        }
    }
    
    /// Erstellt einen neuen User
    func createUser(email: String, displayName: String) -> User? {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ UserManager: Email und Display Name sind erforderlich")
            return nil
        }
        
        // Prüfe ob User mit Email bereits existiert
        if User.fetchUser(by: email, in: viewContext) != nil {
            print("❌ UserManager: User mit Email \(email) existiert bereits")
            return nil
        }
        
        let newUser = User(context: viewContext)
        newUser.id = UUID()
        newUser.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        newUser.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        newUser.createdAt = Date()
        newUser.isActive = true
        
        guard saveContext() else {
            print("❌ UserManager: Fehler beim Speichern des neuen Users")
            return nil
        }
        
        print("✅ UserManager: Neuer User erstellt: \(displayName)")
        return newUser
    }
    
    /// Setzt einen User als aktuellen User
    func setCurrentUser(_ user: User) {
        currentUser = user
        print("✅ UserManager: Current User geändert zu: \(user.formattedDisplayName)")
    }
    
    /// Aktualisiert User-Daten
    func updateUser(_ user: User, displayName: String? = nil, avatarURL: String? = nil) -> Bool {
        if let displayName = displayName {
            user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let avatarURL = avatarURL {
            user.avatarURL = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard saveContext() else {
            print("❌ UserManager: Fehler beim Aktualisieren des Users")
            return false
        }
        
        print("✅ UserManager: User aktualisiert: \(user.formattedDisplayName)")
        return true
    }
    
    /// Deaktiviert einen User (soft delete)
    func deactivateUser(_ user: User) -> Bool {
        user.isActive = false
        
        guard saveContext() else {
            print("❌ UserManager: Fehler beim Deaktivieren des Users")
            return false
        }
        
        print("✅ UserManager: User deaktiviert: \(user.formattedDisplayName)")
        
        // Falls current User deaktiviert wurde, lade einen anderen
        if user == currentUser {
            loadOrCreateDefaultUser()
        }
        
        return true
    }
    
    /// Holt alle aktiven User
    func getAllActiveUsers() -> [User] {
        return User.fetchActiveUsers(in: viewContext)
    }
    
    /// Sucht User nach Email
    func findUser(byEmail email: String) -> User? {
        return User.fetchUser(by: email, in: viewContext)
    }
    
    // MARK: - Private Helper Methods
    
    private func refreshCurrentUser() {
        guard let currentUser = currentUser else { return }
        
        // Refresh der aktuellen User-Daten
        viewContext.refresh(currentUser, mergeChanges: true)
    }
    
    private func saveContext() -> Bool {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
            return true
        } catch {
            print("❌ UserManager: Core Data Save Error: \(error)")
            return false
        }
    }
    
    // MARK: - User Statistics
    
    /// Holt Statistiken für einen User
    func getUserStatistics(for user: User) -> UserStatistics {
        return UserStatistics(
            tripsCount: user.tripsCount,
            memoriesCount: user.memoriesCount,
            memberSince: user.formattedCreatedAt
        )
    }
}

// MARK: - User Statistics Model
struct UserStatistics {
    let tripsCount: Int
    let memoriesCount: Int
    let memberSince: String
} 