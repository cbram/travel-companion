import Foundation
import CoreData

/// Zentrale Verwaltung des Core Data Stacks mit Performance-Optimierungen
class CoreDataManager {
    
    // MARK: - Singleton
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    var persistentContainer: NSPersistentContainer {
        return PersistenceController.shared.container
    }
    
    // MARK: - Computed Properties
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Initialization
    private init() {
        print("✅ CoreDataManager: Using PersistenceController.shared")
    }
    
    // MARK: - Core Data Saving Support
    
    @discardableResult
    func save() -> Bool {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ CoreDataManager: Context saved successfully")
                return true
            } catch {
                print("❌ CoreDataManager: Failed to save context: \(error)")
                return false
            }
        }
        return true
    }
    
    func saveContext(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
                print("✅ CoreDataManager: Background context saved successfully")
            } catch {
                print("❌ CoreDataManager: Failed to save background context: \(error)")
            }
        }
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - User Management
    
    @discardableResult
    func createUser(email: String, displayName: String) -> User {
        let user = User(context: viewContext)
        user.id = UUID()
        user.email = email
        user.displayName = displayName
        user.createdAt = Date()
        user.isActive = true
        return user
    }
    
    func fetchAllUsers() -> [User] {
        let request = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.displayName, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching users: \(error)")
            return []
        }
    }
    
    // MARK: - Trip Management
    
    @discardableResult
    func createTrip(title: String, description: String?, startDate: Date, owner: User) -> Trip {
        let trip = Trip(context: viewContext)
        trip.id = UUID()
        trip.title = title
        trip.tripDescription = description
        trip.startDate = startDate
        trip.isActive = false
        trip.createdAt = Date()
        trip.owner = owner
        return trip
    }
    
    func fetchTrips(for user: User) -> [Trip] {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@ OR ANY participants == %@", user, user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching trips: \(error)")
            return []
        }
    }
    
    func setTripActive(_ trip: Trip, isActive: Bool) {
        trip.isActive = isActive
    }
    
    // MARK: - Memory Management (Footsteps)
    
    @discardableResult
    func createMemory(title: String, content: String?, latitude: Double, longitude: Double, author: User, trip: Trip) -> Memory {
        // Performance-optimierte Erstellung im Main Context
        let memory = Memory(context: viewContext)
        memory.id = UUID()
        memory.title = title
        memory.content = content
        memory.latitude = latitude
        memory.longitude = longitude
        memory.timestamp = Date()
        memory.createdAt = Date()
        memory.author = author
        memory.trip = trip
        
        // Sofortige Validierung der Relationships
        if memory.author == nil || memory.trip == nil {
            print("⚠️ CoreDataManager: Memory-Relationships nicht korrekt gesetzt")
        }
        
        return memory
    }
    
    /// Optimierte Background Memory-Erstellung - FIXED für Context-Kompatibilität
    func createMemoryInBackground(title: String, content: String?, latitude: Double, longitude: Double, authorID: UUID, tripID: UUID, completion: @escaping (Bool) -> Void) {
        // WICHTIG: Verwende performBackgroundTask für bessere Context-Isolation
        performBackgroundTask { [weak self] context in
            guard self != nil else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Batch-Fetch für bessere Performance
            let authorRequest = User.fetchRequest()
            authorRequest.predicate = NSPredicate(format: "id == %@", authorID as CVarArg)
            authorRequest.fetchLimit = 1
            authorRequest.returnsObjectsAsFaults = false // Eager Loading für bessere Performance
            
            let tripRequest = Trip.fetchRequest()
            tripRequest.predicate = NSPredicate(format: "id == %@", tripID as CVarArg)
            tripRequest.fetchLimit = 1
            tripRequest.returnsObjectsAsFaults = false // Eager Loading für bessere Performance
            
            do {
                // Optimierte synchrone Fetches für bessere Performance
                let authorResults = try context.fetch(authorRequest)
                let tripResults = try context.fetch(tripRequest)
                
                guard let author = authorResults.first,
                      let trip = tripResults.first else {
                    print("❌ CoreDataManager: Author oder Trip nicht im Background Context gefunden")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                // Memory erstellen mit optimierten Eigenschaften
                let memory = Memory(context: context)
                memory.id = UUID()
                memory.title = title.trimmingCharacters(in: .whitespacesAndNewlines) // Trim whitespace
                memory.content = content?.trimmingCharacters(in: .whitespacesAndNewlines)
                memory.latitude = latitude
                memory.longitude = longitude
                memory.timestamp = Date()
                memory.createdAt = Date()
                memory.author = author
                memory.trip = trip
                
                // Batch-Save für bessere Performance
                try context.save()
                
                print("✅ CoreDataManager: Memory im Background erstellt (optimiert)")
                DispatchQueue.main.async { completion(true) }
                
            } catch {
                print("❌ CoreDataManager: Background Memory creation failed: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // Alias methods for consistency with Footstep naming
    @discardableResult
    func createFootstep(title: String, content: String?, latitude: Double, longitude: Double, author: User, trip: Trip) -> Memory {
        return createMemory(title: title, content: content, latitude: latitude, longitude: longitude, author: author, trip: trip)
    }
    
    func fetchFootsteps(for trip: Trip) -> [Memory] {
        return fetchMemories(for: trip)
    }
    
    func fetchFootsteps(for user: User) -> [Memory] {
        return fetchMemories(for: user)
    }
    
    func fetchFootsteps(for user: User, from startDate: Date, to endDate: Date) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "author == %@ AND timestamp >= %@ AND timestamp <= %@", user, startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching footsteps for date range: \(error)")
            return []
        }
    }
    
    func fetchFootsteps(near latitude: Double, longitude: Double, radius: Double) -> [Memory] {
        // Vereinfachte Implementierung ohne Core Location Framework
        // In Production würde hier eine geografische Suche implementiert
        let request = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            let allMemories = try viewContext.fetch(request)
            return allMemories.filter { memory in
                let distance = distanceBetween(
                    lat1: latitude, lon1: longitude,
                    lat2: memory.latitude, lon2: memory.longitude
                )
                return distance <= radius
            }
        } catch {
            print("❌ CoreDataManager: Error fetching nearby footsteps: \(error)")
            return []
        }
    }
    
    // MARK: - Photo Management
    
    @discardableResult
    func createPhoto(filename: String, localURL: String?, memory: Memory) -> Photo {
        let photo = Photo(context: viewContext)
        photo.id = UUID()
        photo.filename = filename
        photo.localURL = localURL
        photo.createdAt = Date()
        photo.memory = memory
        return photo
    }
    
    // Overloaded method for Footstep compatibility
    @discardableResult
    func createPhoto(filename: String, localURL: String?, footstep: Memory) -> Photo {
        return createPhoto(filename: filename, localURL: localURL, memory: footstep)
    }
    
    // MARK: - Fetch Helpers
    
    func fetchActiveTrip(for user: User) -> Trip? {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@ AND isActive == YES", user)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("❌ CoreDataManager: Error fetching active trip: \(error)")
            return nil
        }
    }
    
    func fetchAllTrips() -> [Trip] {
        let request = Trip.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching trips: \(error)")
            return []
        }
    }
    
    func fetchMemories(for trip: Trip) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching memories: \(error)")
            return []
        }
    }
    
    func fetchMemories(for user: User) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "author == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching memories for user: \(error)")
            return []
        }
    }
    
    // MARK: - Data Management
    
    func deleteObject(_ object: NSManagedObject) {
        viewContext.delete(object)
    }
    
    func clearAllData() {
        let entities = ["Photo", "Memory", "Trip", "User", "Item"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try viewContext.execute(deleteRequest)
                print("✅ CoreDataManager: \(entityName) data cleared")
            } catch {
                print("❌ CoreDataManager: Error clearing \(entityName): \(error)")
            }
        }
        
        save()
    }
    
    // MARK: - Helper Methods
    
    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        // Haversine formula for distance calculation
        let earthRadius: Double = 6371000 // meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
} 