import Foundation
import CoreData

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TravelCompanion")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data fehler: \(error), \(error.userInfo)")
            }
        }
        
        // Merge Policy für Konflikte
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Automatisches Speichern aktivieren
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // Background Context für schwere Operationen
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    // MARK: - Core Data Saving Support
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data Speicher-Fehler: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data Speicher-Fehler: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Background Operations
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Entity Creation Helpers
    
    func createUser(email: String, displayName: String, avatarURL: String? = nil) -> User {
        let user = User(context: viewContext)
        user.id = UUID()
        user.email = email
        user.displayName = displayName
        user.avatarURL = avatarURL
        user.createdAt = Date()
        user.isActive = true
        return user
    }
    
    func createTrip(title: String, description: String? = nil, startDate: Date, owner: User) -> Trip {
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
    
    func createFootstep(title: String, content: String? = nil, latitude: Double, longitude: Double, author: User, trip: Trip) -> Footstep {
        let footstep = Footstep(context: viewContext)
        footstep.id = UUID()
        footstep.title = title
        footstep.content = content
        footstep.latitude = latitude
        footstep.longitude = longitude
        footstep.timestamp = Date()
        footstep.createdAt = Date()
        footstep.author = author
        footstep.trip = trip
        return footstep
    }
    
    func createPhoto(filename: String, localURL: String? = nil, cloudURL: String? = nil, footstep: Footstep) -> Photo {
        let photo = Photo(context: viewContext)
        photo.id = UUID()
        photo.filename = filename
        photo.localURL = localURL
        photo.cloudURL = cloudURL
        photo.createdAt = Date()
        photo.footstep = footstep
        return photo
    }
    
    // MARK: - Fetch Helpers
    
    func fetchUsers() -> [User] {
        let request: NSFetchRequest<User> = User.fetchRequest()
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der User: \(error)")
            return []
        }
    }
    
    func fetchActiveTrips() -> [Trip] {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der aktiven Trips: \(error)")
            return []
        }
    }
    
    func fetchTrips(for user: User) -> [Trip] {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@ OR ANY participants == %@", user, user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der User-Trips: \(error)")
            return []
        }
    }
    
    // MARK: - Delete Operations
    
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
    }
    
    func deleteAllData() {
        let entities = ["User", "Trip", "Footstep", "Photo"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try viewContext.execute(deleteRequest)
            } catch {
                print("Fehler beim Löschen von \(entityName): \(error)")
            }
        }
        
        save()
    }
    
    // MARK: - LocationManager Integration
    
    /// Footsteps für einen Trip abrufen (sortiert nach Zeitstempel)
    func fetchFootsteps(for trip: Trip) -> [Footstep] {
        let request: NSFetchRequest<Footstep> = Footstep.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Footstep.timestamp, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Footsteps: \(error)")
            return []
        }
    }
    
    /// Footsteps eines Users für einen bestimmten Zeitraum abrufen
    func fetchFootsteps(for user: User, from startDate: Date, to endDate: Date) -> [Footstep] {
        let request: NSFetchRequest<Footstep> = Footstep.fetchRequest()
        request.predicate = NSPredicate(format: "author == %@ AND timestamp >= %@ AND timestamp <= %@", user, startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Footstep.timestamp, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Footsteps für Zeitraum: \(error)")
            return []
        }
    }
    
    /// Aktive Trips eines Users abrufen (für LocationManager)
    func fetchActiveTrip(for user: User) -> Trip? {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "(owner == %@ OR ANY participants == %@) AND isActive == true", user, user)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            print("Fehler beim Laden des aktiven Trips: \(error)")
            return nil
        }
    }
    
    /// Trip aktivieren/deaktivieren (für GPS-Tracking)
    func setTripActive(_ trip: Trip, isActive: Bool) {
        trip.isActive = isActive
        save()
    }
    
    /// Alle Footsteps in einem Radius um eine Koordinate finden
    func fetchFootsteps(near latitude: Double, longitude: Double, radius: Double) -> [Footstep] {
        let request: NSFetchRequest<Footstep> = Footstep.fetchRequest()
        
        // Vereinfachter Radius-Check (für eine echte App sollte eine präzisere Berechnung verwendet werden)
        let latRange = radius / 111000 // Ungefähr 1 Grad = 111km
        let lonRange = radius / (111000 * cos(latitude * .pi / 180))
        
        request.predicate = NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f",
                                      latitude - latRange, latitude + latRange,
                                      longitude - lonRange, longitude + lonRange)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Footstep.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Footsteps in der Nähe: \(error)")
            return []
        }
    }
} 