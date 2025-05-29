import Foundation
import CoreData

/// Zentrale Verwaltung des Core Data Stacks mit Performance-Optimierungen
class CoreDataManager {
    
    // MARK: - Singleton
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TravelCompanion")
        
        // Performance-Optimierungen
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as? NSError {
                fatalError("❌ CoreDataManager: Failed to load store: \(error)")
            } else {
                print("✅ CoreDataManager: Persistent store loaded successfully")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Computed Properties
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Core Data Saving Support
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ CoreDataManager: Context saved successfully")
            } catch {
                print("❌ CoreDataManager: Failed to save context: \(error)")
            }
        }
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
        user.email = email
        user.displayName = displayName
        user.createdAt = Date()
        user.isActive = true
        return user
    }
    
    func fetchAllUsers() -> [User] {
        let request: NSFetchRequest<User> = User.fetchRequest()
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
        trip.title = title
        trip.tripDescription = description
        trip.startDate = startDate
        trip.isActive = false
        trip.createdAt = Date()
        trip.owner = owner
        return trip
    }
    
    func fetchTrips(for user: User) -> [Trip] {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@ OR participants == %@", user, user)
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
    
    // MARK: - Memory Management
    
    @discardableResult
    func createMemory(title: String, content: String?, latitude: Double, longitude: Double, author: User, trip: Trip) -> Memory {
        let memory = Memory(context: viewContext)
        memory.title = title
        memory.content = content
        memory.latitude = latitude
        memory.longitude = longitude
        memory.timestamp = Date()
        memory.createdAt = Date()
        memory.author = author
        memory.trip = trip
        return memory
    }
    
    // MARK: - Photo Management
    
    @discardableResult
    func createPhoto(filename: String, localURL: String?, memory: Memory) -> Photo {
        let photo = Photo(context: viewContext)
        photo.filename = filename
        photo.localURL = localURL
        photo.createdAt = Date()
        photo.memory = memory
        return photo
    }
    
    // MARK: - Fetch Helpers
    
    func fetchActiveTrip(for user: User) -> Trip? {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
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
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("❌ CoreDataManager: Error fetching trips: \(error)")
            return []
        }
    }
    
    func fetchMemories(for trip: Trip) -> [Memory] {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
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
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
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
} 