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
    @Published var selectedMemory: Memory?
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
    private var deleteRequest: NSFetchRequest<Memory> {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \Memory.createdAt, ascending: false)
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
    
    /// Lädt mehr Memories (Pagination)
    func loadMoreMemories() {
        guard !isLoadingMore && hasMoreToLoad else { return }
        
        isLoadingMore = true
        
        // Simuliere Laden von mehr Daten
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingMore = false
            // Hier würde man prüfen ob noch mehr Daten verfügbar sind
            // self.hasMoreToLoad = false
        }
    }
    
    /// Löscht ein Memory mit Bestätigung
    func deleteMemory(_ memory: Memory) {
        selectedMemory = memory
        showingDeleteAlert = true
    }
    
    /// Führt das Löschen aus
    func confirmDelete() {
        guard let memory = selectedMemory else { return }
        
        do {
            // Zugehörige Photos löschen
            if let photos = memory.photos?.allObjects as? [Photo] {
                for photo in photos {
                    // Lokale Dateien löschen (wird später implementiert)
                    // _ = photo.deleteLocalFile()
                    managedObjectContext.delete(photo)
                }
            }
            
            // Memory löschen
            managedObjectContext.delete(memory)
            
            // Speichern
            try managedObjectContext.save()
            
            selectedMemory = nil
            
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
    var fetchRequest: NSFetchRequest<Memory> {
        return deleteRequest
    }
}

// MARK: - Statistics Extension
extension TimelineViewModel {
    
    /// Berechnet Timeline-Statistiken
    func calculateStatistics() -> TimelineStats {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        
        do {
            let allMemories = try managedObjectContext.fetch(request)
            
            let totalCount = allMemories.count
            let photosCount = allMemories.reduce(0) { $0 + $1.photoCount }
            let tripsCount = Set(allMemories.compactMap { $0.trip }).count
            
            let calendar = Calendar.current
            let now = Date()
            let thisWeek = allMemories.filter { memory in
                guard let timestamp = memory.timestamp else { return false }
                return calendar.isDate(timestamp, inSameDayAs: now) ||
                       calendar.dateInterval(of: .weekOfYear, for: now)?.contains(timestamp) == true
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