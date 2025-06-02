import Foundation
import CoreData

/// Utility class for creating sample data for testing and previews
class SampleDataCreator {
    
    // MARK: - Sample Data Creation
    
    /// Creates sample data in the given context
    static func createSampleData(in context: NSManagedObjectContext) {
        // Clear existing data first (for testing purposes)
        clearAllData(in: context)
        
        // Create sample user
        let sampleUser = createSampleUser(in: context)
        
        // Create sample trips
        let activeTrip = createSampleActiveTrip(for: sampleUser, in: context)
        let pastTrip = createSamplePastTrip(for: sampleUser, in: context)
        
        // Create sample memories for trips
        createSampleMemories(for: activeTrip, author: sampleUser, in: context)
        createSampleMemories(for: pastTrip, author: sampleUser, in: context)
        
        // Save context
        do {
            try context.save()
            print("✅ SampleDataCreator: Sample data created successfully")
        } catch {
            print("❌ SampleDataCreator: Error creating sample data: \(error)")
        }
    }
    
    // MARK: - Sample User Creation
    
    static func createSampleUser(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.email = "test@example.com"
        user.displayName = "Test Benutzer"
        user.createdAt = Date()
        user.isActive = true
        return user
    }
    
    // MARK: - Sample Trip Creation
    
    static func createSampleActiveTrip(for user: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Aktuelle Italien Reise"
        trip.tripDescription = "Eine wunderbare Reise durch die Toskana"
        trip.startDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        trip.isActive = true
        trip.createdAt = Date()
        trip.owner = user
        return trip
    }
    
    static func createSamplePastTrip(for user: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Spanien Urlaub"
        trip.tripDescription = "Barcelona und Madrid Städtereise"
        trip.startDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        trip.isActive = false
        trip.createdAt = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        trip.owner = user
        return trip
    }
    
    // MARK: - Sample Trip Creation for Previews
    
    static func createSampleTrip() -> Trip {
        let context = PersistenceController.preview.container.viewContext
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Italien Rundreise"
        trip.tripDescription = "Eine wunderbare Reise durch die Toskana und nach Rom"
        trip.startDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        trip.isActive = true
        trip.createdAt = Date()
        return trip
    }
    
    // MARK: - Sample Memory Creation
    
    static func createSampleMemories(for trip: Trip, author: User, in context: NSManagedObjectContext) {
        let memoryData = [
            ("Ankunft am Flughafen", "Endlich angekommen! Das Wetter ist perfekt.", 41.9028, 12.4964),
            ("Colosseum Besichtigung", "Beeindruckende antike Architektur", 41.8902, 12.4922),
            ("Trevi Brunnen", "Münze reingeworfen für Glück", 41.9009, 12.4833),
            ("Vatikan Museum", "Unglaubliche Kunstsammlung", 41.9029, 12.4545),
            ("Toskana Weinprobe", "Fantastischer Chianti", 43.7711, 11.2486)
        ]
        
        for (index, data) in memoryData.enumerated() {
            let memory = Memory(context: context)
            memory.id = UUID()
            memory.title = data.0
            memory.content = data.1
            memory.latitude = data.2
            memory.longitude = data.3
            memory.timestamp = Calendar.current.date(byAdding: .hour, value: -index * 6, to: Date()) ?? Date()
            memory.createdAt = Calendar.current.date(byAdding: .hour, value: -index * 6, to: Date()) ?? Date()
            memory.author = author
            memory.trip = trip
        }
    }
    
    // MARK: - Sample Memory for Previews
    
    static func createSampleMemory() -> Memory {
        let context = PersistenceController.preview.container.viewContext
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.title = "Schöner Aussichtspunkt"
        memory.content = "Ein wunderschöner Blick über die Stadt bei Sonnenuntergang"
        memory.latitude = 41.9028
        memory.longitude = 12.4964
        memory.timestamp = Date()
        memory.createdAt = Date()
        return memory
    }
    
    // MARK: - Data Management
    
    static func clearAllData(in context: NSManagedObjectContext) {
        let entities = ["Photo", "Memory", "Trip", "User"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                print("✅ SampleDataCreator: \(entityName) data cleared")
            } catch {
                print("❌ SampleDataCreator: Error clearing \(entityName): \(error)")
            }
        }
    }
    
    // MARK: - Data Summary
    
    static func printDataSummary(using coreDataManager: CoreDataManager) {
        let users = coreDataManager.fetchAllUsers()
        let trips = coreDataManager.fetchAllTrips()
        
        print("\n📊 Data Summary:")
        print("Users: \(users.count)")
        print("Trips: \(trips.count)")
        
        for trip in trips {
            let memories = coreDataManager.fetchMemories(for: trip)
            print("  - \(trip.title ?? "Unnamed Trip"): \(memories.count) memories")
        }
        print("")
    }
} 