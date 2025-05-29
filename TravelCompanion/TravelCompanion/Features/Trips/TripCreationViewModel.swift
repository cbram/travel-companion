import SwiftUI
import CoreData
import Foundation

/// ViewModel für die Trip-Erstellung
@MainActor
class TripCreationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var title = ""
    @Published var description = ""
    @Published var startDate = Date()
    @Published var endDate: Date?
    @Published var isCreating = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private let coreDataManager: CoreDataManager
    private let user: User
    
    // MARK: - Computed Properties
    var canCreateTrip: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }
    
    var canSave: Bool {
        canCreateTrip
    }
    
    var isLoading: Bool {
        isCreating
    }
    
    var showError: Bool {
        showingError
    }
    
    // MARK: - Initialization
    init(user: User, coreDataManager: CoreDataManager = .shared) {
        self.user = user
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Trip Creation
    func createTrip() async -> Trip? {
        guard canCreateTrip else { return nil }
        
        isCreating = true
        defer { isCreating = false }
        
        do {
            return await withCheckedContinuation { continuation in
                coreDataManager.performBackgroundTask { context in
                    // User in Background Context holen
                    let backgroundUser = context.object(with: self.user.objectID) as! User
                    
                    // Trip erstellen
                    let trip = Trip(context: context)
                    trip.id = UUID()
                    trip.title = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    trip.tripDescription = self.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    trip.startDate = self.startDate
                    trip.endDate = self.endDate
                    trip.isActive = false
                    trip.createdAt = Date()
                    trip.owner = backgroundUser
                    
                    // Speichern
                    do {
                        try context.save()
                        
                        // Trip in Main Context holen
                        DispatchQueue.main.async {
                            let mainTrip = self.coreDataManager.viewContext.object(with: trip.objectID) as! Trip
                            continuation.resume(returning: mainTrip)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.showError("Fehler beim Erstellen der Reise: \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    func clearForm() {
        title = ""
        description = ""
        startDate = Date()
        endDate = nil
    }
    
    // MARK: - Validation
    func getTitleValidationMessage() -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return "Titel ist erforderlich"
        }
        if trimmedTitle.count < 3 {
            return "Titel muss mindestens 3 Zeichen lang sein"
        }
        return nil
    }
} 