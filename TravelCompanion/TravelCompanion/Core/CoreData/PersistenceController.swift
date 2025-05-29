import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Sample Data für Previews erstellen
        let sampleUser = User(context: viewContext)
        sampleUser.id = UUID()
        sampleUser.email = "max@example.com"
        sampleUser.displayName = "Max Mustermann"
        sampleUser.createdAt = Date()
        sampleUser.isActive = true
        
        let sampleUser2 = User(context: viewContext)
        sampleUser2.id = UUID()
        sampleUser2.email = "anna@example.com"
        sampleUser2.displayName = "Anna Schmidt"
        sampleUser2.createdAt = Date()
        sampleUser2.isActive = true
        
        let sampleTrip = Trip(context: viewContext)
        sampleTrip.id = UUID()
        sampleTrip.title = "Reise nach Italien"
        sampleTrip.tripDescription = "Wunderschöne Reise durch die Toskana"
        sampleTrip.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        sampleTrip.endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        sampleTrip.isActive = true
        sampleTrip.createdAt = Date()
        sampleTrip.owner = sampleUser
        sampleTrip.addToParticipants(sampleUser2)
        
        let sampleMemory = Memory(context: viewContext)
        sampleMemory.id = UUID()
        sampleMemory.title = "Kolosseum besucht"
        sampleMemory.content = "Beeindruckende Architektur und Geschichte"
        sampleMemory.latitude = 41.8902
        sampleMemory.longitude = 12.4922
        sampleMemory.timestamp = Date()
        sampleMemory.createdAt = Date()
        sampleMemory.author = sampleUser
        sampleMemory.trip = sampleTrip
        
        let samplePhoto = Photo(context: viewContext)
        samplePhoto.id = UUID()
        samplePhoto.filename = "kolosseum_01.jpg"
        samplePhoto.localURL = "/local/photos/kolosseum_01.jpg"
        samplePhoto.cloudURL = "https://cloud.example.com/photos/kolosseum_01.jpg"
        samplePhoto.createdAt = Date()
        samplePhoto.memory = sampleMemory
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TravelCompanion")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
} 