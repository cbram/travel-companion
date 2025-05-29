import SwiftUI
import CoreData
import Combine

/// ViewModel für die Timeline-Hauptansicht mit Performance-optimierter Memory-Darstellung
@MainActor
class TimelineViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRefreshing = false
    @Published var showingDeleteAlert = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var selectedFootstep: Footstep?
    @Published var searchText = ""
    @Published var isLoadingMore = false
    @Published var hasMoreToLoad = true
    
    // Filter Properties
    @Published var selectedTrip: Trip?
    @Published var showingFilterSheet = false
    @Published var dateRange: ClosedRange<Date>?
    
    // MARK: - Private Properties
    private let managedObjectContext: NSManagedObjectContext
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Core Data
    private var deleteRequest: NSFetchRequest<Footstep> {
        let request: NSFetchRequest<Footstep> = Footstep.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Footstep.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \Footstep.createdAt, ascending: false)
        ]
        
        // Apply filters
        var predicates: [NSPredicate] = []
        
        // Search filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@", 
                                            searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Trip filter
        if let selectedTrip = selectedTrip {
            let tripPredicate = NSPredicate(format: "trip == %@", selectedTrip)
            predicates.append(tripPredicate)
        }
        
        // Date range filter
        if let dateRange = dateRange {
            let datePredicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", 
                                          dateRange.lowerBound as NSDate, 
                                          dateRange.upperBound as NSDate)
            predicates.append(datePredicate)
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        return request
    }
    
    // MARK: - Initialization
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Debounce search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refreshTimeline()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Aktualisiert die Timeline (Pull-to-Refresh)
    func refreshTimeline() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        hasMoreToLoad = true
        
        // CloudKit Sync simulieren (kann später implementiert werden)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isRefreshing = false
        }
    }
    
    /// Lädt mehr Footsteps (Pagination)
    func loadMoreFootsteps() {
        guard !isLoadingMore && hasMoreToLoad else { return }
        
        isLoadingMore = true
        
        // Simuliere Laden von mehr Daten
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingMore = false
            // Hier würde man prüfen ob noch mehr Daten verfügbar sind
            // self.hasMoreToLoad = false
        }
    }
    
    /// Löscht ein Footstep mit Bestätigung
    func deleteFootstep(_ footstep: Footstep) {
        selectedFootstep = footstep
        showingDeleteAlert = true
    }
    
    /// Führt das Löschen aus
    func confirmDelete() {
        guard let footstep = selectedFootstep else { return }
        
        do {
            // Zugehörige Photos löschen
            if let photos = footstep.photos?.allObjects as? [Photo] {
                for photo in photos {
                    // Lokale Dateien löschen
                    _ = photo.deleteLocalFile()
                    managedObjectContext.delete(photo)
                }
            }
            
            // Footstep löschen
            managedObjectContext.delete(footstep)
            
            // Speichern
            try managedObjectContext.save()
            
            selectedFootstep = nil
            
        } catch {
            errorMessage = "Fehler beim Löschen: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    /// Löscht alle Filter
    func clearFilters() {
        selectedTrip = nil
        dateRange = nil
        searchText = ""
    }
    
    /// Prüft ob Filter aktiv sind
    var hasActiveFilters: Bool {
        return !searchText.isEmpty || selectedTrip != nil || dateRange != nil
    }
    
    /// Anzahl der aktiven Filter
    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if selectedTrip != nil { count += 1 }
        if dateRange != nil { count += 1 }
        return count
    }
    
    // MARK: - Fetch Request für SwiftUI
    var fetchRequest: NSFetchRequest<Footstep> {
        return deleteRequest
    }
}

// MARK: - Statistics Extension
extension TimelineViewModel {
    
    /// Berechnet Timeline-Statistiken
    func calculateStatistics() -> TimelineStats {
        let request: NSFetchRequest<Footstep> = Footstep.fetchRequest()
        
        do {
            let allFootsteps = try managedObjectContext.fetch(request)
            
            let totalCount = allFootsteps.count
            let photosCount = allFootsteps.reduce(0) { $0 + $1.photoCount }
            let tripsCount = Set(allFootsteps.compactMap { $0.trip }).count
            
            let calendar = Calendar.current
            let now = Date()
            let thisWeek = allFootsteps.filter { 
                calendar.isDate($0.timestamp, inSameDayAs: now) ||
                calendar.dateInterval(of: .weekOfYear, for: now)?.contains($0.timestamp) == true
            }.count
            
            return TimelineStats(
                totalMemories: totalCount,
                totalPhotos: photosCount,
                totalTrips: tripsCount,
                memoriesThisWeek: thisWeek
            )
        } catch {
            return TimelineStats()
        }
    }
}

// MARK: - Supporting Types
struct TimelineStats {
    let totalMemories: Int
    let totalPhotos: Int
    let totalTrips: Int
    let memoriesThisWeek: Int
    
    init(totalMemories: Int = 0, totalPhotos: Int = 0, totalTrips: Int = 0, memoriesThisWeek: Int = 0) {
        self.totalMemories = totalMemories
        self.totalPhotos = totalPhotos
        self.totalTrips = totalTrips
        self.memoriesThisWeek = memoriesThisWeek
    }
} 