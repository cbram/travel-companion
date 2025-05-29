import Foundation
import CoreData

struct SampleDataCreator {
    static func createSampleData(in context: NSManagedObjectContext) {
        // Erstelle Sample Users
        let user1 = createUser1(in: context)
        let user2 = createUser2(in: context)
        let user3 = createUser3(in: context)
        
        // Erstelle Sample Trips
        let trip1 = createTrip1(with: user1, in: context)
        let trip2 = createTrip2(with: user2, in: context)
        let trip3 = createTrip3(with: user3, in: context)
        
        // Füge Participants zu Trips hinzu
        // Note: Die participants relationship ist Many-to-Many und erwartet NSSet
        trip1.addToParticipants(user2)
        trip2.addToParticipants(user1)
        trip3.addToParticipants(user2)
        
        // Erstelle Sample Memories für jeden Trip
        createMemoriesForTrip1(trip1, users: [user1, user2], in: context)
        createMemoriesForTrip2(trip2, users: [user2, user1], in: context)
        createMemoriesForTrip3(trip3, users: [user3, user2], in: context)
        
        // Speichere den Context
        do {
            try context.save()
            print("✅ SampleDataCreator: Sample-Daten erfolgreich erstellt")
        } catch {
            print("❌ SampleDataCreator: Fehler beim Speichern: \(error)")
        }
    }
    
    // MARK: - User Creation
    private static func createUser1(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.email = "alice@travelcompanion.app"
        user.displayName = "Alice Müller"
        user.createdAt = Date()
        user.isActive = true
        user.avatarURL = "https://example.com/avatars/alice.jpg"
        return user
    }
    
    private static func createUser2(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.email = "bob@travelcompanion.app"
        user.displayName = "Bob Schmidt"
        user.createdAt = Date()
        user.isActive = true
        user.avatarURL = "https://example.com/avatars/bob.jpg"
        return user
    }
    
    private static func createUser3(in context: NSManagedObjectContext) -> User {
        let user = User(context: context)
        user.email = "charlie@travelcompanion.app"
        user.displayName = "Charlie Weber"
        user.createdAt = Date()
        user.isActive = false
        user.avatarURL = "https://example.com/avatars/charlie.jpg"
        return user
    }
    
    // MARK: - Trip Creation
    private static func createTrip1(with owner: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.title = "Sommerurlaub Italien"
        trip.tripDescription = "Entspannter Familienurlaub an der Amalfiküste"
        trip.startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        trip.endDate = Calendar.current.date(byAdding: .day, value: -23, to: Date())!
        trip.createdAt = Calendar.current.date(byAdding: .day, value: -35, to: Date())!
        trip.isActive = false
        trip.owner = owner
        return trip
    }
    
    private static func createTrip2(with owner: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.title = "Wochenendtrip Berlin"
        trip.tripDescription = "Städtetrip mit Freunden"
        trip.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        trip.endDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        trip.createdAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        trip.isActive = false
        trip.owner = owner
        return trip
    }
    
    private static func createTrip3(with owner: User, in context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        trip.title = "Aktuelle Reise München"
        trip.tripDescription = "Geschäftsreise nach München"
        trip.startDate = Date()
        trip.endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        trip.createdAt = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        trip.isActive = true
        trip.owner = owner
        return trip
    }
    
    // MARK: - Memory Creation
    private static func createMemoriesForTrip1(_ trip: Trip, users: [User], in context: NSManagedObjectContext) {
        // Memory 1 mit Photo
        let memory1 = Memory(context: context)
        memory1.title = "Ankunft am Strand"
        memory1.content = "Endlich angekommen! Der Strand ist wunderschön."
        memory1.latitude = 40.6318
        memory1.longitude = 14.6026
        memory1.timestamp = Calendar.current.date(byAdding: .hour, value: -720, to: Date())!
        memory1.createdAt = Calendar.current.date(byAdding: .hour, value: -720, to: Date())!
        memory1.author = users[0]
        memory1.trip = trip
        
        // Photo für Memory 1
        let photo1 = Photo(context: context)
        photo1.filename = "beach_arrival.jpg"
        photo1.localURL = "/Documents/Photos/beach_arrival.jpg"
        photo1.cloudURL = "https://cloud.example.com/photos/beach_arrival.jpg"
        photo1.createdAt = Calendar.current.date(byAdding: .hour, value: -720, to: Date())!
        photo1.memory = memory1
        
        // Memory 2
        let memory2 = Memory(context: context)
        memory2.title = "Pizza am Hafen"
        memory2.content = "Beste Pizza meines Lebens! 🍕"
        memory2.latitude = 40.6328
        memory2.longitude = 14.6030
        memory2.timestamp = Calendar.current.date(byAdding: .hour, value: -700, to: Date())!
        memory2.createdAt = Calendar.current.date(byAdding: .hour, value: -700, to: Date())!
        memory2.author = users[1]
        memory2.trip = trip
        
        // Memory 3
        let memory3 = Memory(context: context)
        memory3.title = "Sonnenuntergang"
        memory3.content = "Magischer Sonnenuntergang über dem Meer"
        memory3.latitude = 40.6315
        memory3.longitude = 14.6020
        memory3.timestamp = Calendar.current.date(byAdding: .hour, value: -680, to: Date())!
        memory3.createdAt = Calendar.current.date(byAdding: .hour, value: -680, to: Date())!
        memory3.author = users[0]
        memory3.trip = trip
    }
    
    private static func createMemoriesForTrip2(_ trip: Trip, users: [User], in context: NSManagedObjectContext) {
        // Memory 1
        let memory1 = Memory(context: context)
        memory1.title = "Brandenburger Tor"
        memory1.content = "Klassisches Berlin-Foto geschossen!"
        memory1.latitude = 52.5163
        memory1.longitude = 13.3777
        memory1.timestamp = Calendar.current.date(byAdding: .hour, value: -168, to: Date())!
        memory1.createdAt = Calendar.current.date(byAdding: .hour, value: -168, to: Date())!
        memory1.author = users[0]
        memory1.trip = trip
        
        // Memory 2
        let memory2 = Memory(context: context)
        memory2.title = "Museumsinsel"
        memory2.content = "So viel Geschichte an einem Ort"
        memory2.latitude = 52.5218
        memory2.longitude = 13.3988
        memory2.timestamp = Calendar.current.date(byAdding: .hour, value: -150, to: Date())!
        memory2.createdAt = Calendar.current.date(byAdding: .hour, value: -150, to: Date())!
        memory2.author = users[1]
        memory2.trip = trip
    }
    
    private static func createMemoriesForTrip3(_ trip: Trip, users: [User], in context: NSManagedObjectContext) {
        // Memory 1
        let memory1 = Memory(context: context)
        memory1.title = "München Hauptbahnhof"
        memory1.content = "Angekommen in München! Zeit für Weißwurst 🥨"
        memory1.latitude = 48.1401
        memory1.longitude = 11.5581
        memory1.timestamp = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        memory1.createdAt = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        memory1.author = users[0]
        memory1.trip = trip
    }
    
    // MARK: - Helper Methods
    static func clearAllData(in context: NSManagedObjectContext) {
        // Lösche alle Entities in korrekter Reihenfolge
        let entities = ["Photo", "Memory", "Trip", "User", "Item"]
        
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                print("✅ SampleDataCreator: \(entityName) Daten gelöscht")
            } catch {
                print("❌ SampleDataCreator: Fehler beim Löschen von \(entityName): \(error)")
            }
        }
        
        // Speichere Context
        do {
            try context.save()
            print("✅ SampleDataCreator: Alle Daten erfolgreich gelöscht")
        } catch {
            print("❌ SampleDataCreator: Fehler beim Speichern nach dem Löschen: \(error)")
        }
    }
    
    static func hasExistingData(in context: NSManagedObjectContext) -> Bool {
        let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        
        do {
            let count = try context.count(for: memoryRequest)
            return count > 0
        } catch {
            print("❌ SampleDataCreator: Fehler beim Überprüfen der Memory-Daten: \(error)")
            return false
        }
    }
} 