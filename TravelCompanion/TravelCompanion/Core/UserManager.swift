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
        guard !isLoading else {
            print("⚠️ UserManager: Bereits beim Laden, überspringe...")
            return
        }
        
        isLoading = true
        
        // SYNCHRONOUS Operation im Main Context für Stabilität
        let user = User.fetchOrCreateDefaultUser(in: self.viewContext)
        
        // ERWEITERTE Validierung des geladenen/erstellten Users
        guard !user.isDeleted,
              let userContext = user.managedObjectContext,
              userContext == self.viewContext else {
            print("❌ UserManager: Geladener User ist ungültig oder in falschem Context")
            self.currentUser = nil
            self.isLoading = false
            return
        }
        
        // STORE-VALIDIERUNG: Prüfe dass User wirklich im Persistent Store existiert
        do {
            _ = try viewContext.existingObject(with: user.objectID)
            self.currentUser = user
            print("✅ UserManager: Current User geladen und validiert: \(user.formattedDisplayName)")
        } catch {
            print("❌ UserManager: User nicht im Store gefunden: \(error)")
            self.currentUser = nil
        }
        
        // ZUSÄTZLICHER Save um sicherzustellen, dass alles persistiert ist
        if viewContext.hasChanges {
            if saveContext() {
                print("✅ UserManager: User-Änderungen erfolgreich gespeichert")
            } else {
                print("❌ UserManager: Fehler beim Speichern der User-Änderungen")
                self.currentUser = nil
            }
        }
        
        self.isLoading = false
    }
    
    /// Validiert den aktuellen User und lädt ihn bei Bedarf neu - ENHANCED VERSION
    func validateCurrentUser() -> Bool {
        guard let user = currentUser else {
            print("⚠️ UserManager: Kein currentUser vorhanden")
            loadOrCreateDefaultUser()
            return false
        }
        
        // MULTI-LEVEL Validierung
        // Level 1: Basic Object-Validierung
        guard !user.isDeleted else {
            print("⚠️ UserManager: CurrentUser ist gelöscht, lade neu...")
            loadOrCreateDefaultUser()
            return false
        }
        
        // Level 2: Context-Validierung
        guard let userContext = user.managedObjectContext else {
            print("⚠️ UserManager: CurrentUser hat keinen Context, lade neu...")
            loadOrCreateDefaultUser()
            return false
        }
        
        // Level 3: Context-Kompatibilität prüfen
        guard userContext == viewContext || userContext.parent == viewContext else {
            print("⚠️ UserManager: CurrentUser in inkompatiblem Context, lade neu...")
            loadOrCreateDefaultUser()
            return false
        }
        
        // Level 4: Store-Existenz-Validierung (KRITISCH!)
        do {
            let storeUser = try viewContext.existingObject(with: user.objectID) as? User
            guard let validStoreUser = storeUser,
                  !validStoreUser.isDeleted,
                  validStoreUser.isActive else {
                print("⚠️ UserManager: CurrentUser nicht im Store oder inaktiv")
                loadOrCreateDefaultUser()
                return false
            }
            
            // FINAL CHECK: Update currentUser reference if needed
            if currentUser?.objectID != validStoreUser.objectID {
                currentUser = validStoreUser
                print("✅ UserManager: CurrentUser-Referenz aktualisiert")
            }
            
            return true
            
        } catch {
            print("⚠️ UserManager: CurrentUser Store-Validierung fehlgeschlagen: \(error)")
            loadOrCreateDefaultUser()
            return false
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
    
    /// Setzt einen User als aktuellen User - ENHANCED VERSION
    func setCurrentUser(_ user: User) {
        // VALIDIERUNG vor dem Setzen
        guard !user.isDeleted,
              let userContext = user.managedObjectContext,
              userContext == viewContext else {
            print("❌ UserManager: Ungültiger User für setCurrentUser")
            return
        }
        
        // STORE-VALIDIERUNG
        do {
            let storeUser = try viewContext.existingObject(with: user.objectID) as? User
            guard let validUser = storeUser,
                  validUser.isActive else {
                print("❌ UserManager: User nicht im Store oder inaktiv")
                return
            }
            
            currentUser = validUser
            print("✅ UserManager: Current User erfolgreich geändert zu: \(validUser.formattedDisplayName)")
            
        } catch {
            print("❌ UserManager: Fehler bei setCurrentUser Store-Validierung: \(error)")
        }
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
        guard viewContext.hasChanges else {
            return true // Kein Save nötig
        }
        
        do {
            // Performance-Monitoring
            let startTime = CFAbsoluteTimeGetCurrent()
            try viewContext.save()
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            if timeElapsed > 0.1 {
                print("⚠️ UserManager: Langsamer Context-Save: \(String(format: "%.3f", timeElapsed))s")
            } else {
                print("✅ UserManager: Context erfolgreich gespeichert (\(String(format: "%.3f", timeElapsed))s)")
            }
            
            return true
        } catch {
            print("❌ UserManager: Core Data Save Error: \(error)")
            // ROLLBACK bei Fehlern
            viewContext.rollback()
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